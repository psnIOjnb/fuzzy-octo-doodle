#!/usr/bin/env python3
"""
OTC Pulse daily feed generator.

Aggregates official regulator RSS/Atom feeds (feedgen/sources.json), keeps
items published inside the snapshot window, scores their impact, extracts
deadlines, and writes a daily.json matching the app's DailyFeedDTO wire
format exactly.

Design notes
------------
* Window: nominally the last 24 hours. The effective window is widened to
  cover the gap since the previous run (recorded in the state file), so a
  late or skipped cron never drops publications silently. The app
  deduplicates by id/url, so any overlap is invisible on device.
* Undated feeds: several regulators (ESMA among them) publish RSS with no
  date on each item. Those are dated by *first sighting* using the state
  file, so each such publication enters the feed exactly once, on the day
  it appears.
* IDs are UUIDv5 of the item URL and therefore stable across runs.

Usage:
    python feedgen/generate_feed.py --hours 24 --out daily.json \
        --state feed-state.json
"""

import argparse
import json
import re
import sys
import time
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

import feedparser
from dateutil import parser as dateparser

USER_AGENT = "OTCPulseFeedBot/1.0 (+https://github.com/psnIOjnb/fuzzy-octo-doodle)"

# How long a first-seen record is retained in the state file.
SEEN_RETENTION_DAYS = 180
# Safety cap so a stuck state file can't trigger a year-long backfill.
MAX_WINDOW_HOURS = 24 * 45

# ---------------------------------------------------------------------------
# Relevance: these terms don't gate ingestion, they boost ranking. Items that
# match are treated as OTC-derivatives intelligence; everything else a
# regulator publishes is still kept, one step lower in the ranking.
# ---------------------------------------------------------------------------
RELEVANCE_TERMS = [
    "swap", "derivative", "otc ", " otc", "margin", "clearing", "cleared",
    "uncleared", "central counterparty", "ccp", "trade repository",
    "trade reporting", "transaction reporting", "emir", "dodd-frank",
    "position limit", "netting", "swap execution facility", "sef ",
    "security-based swap", "benchmark", "libor", "sa-ccr",
    "counterparty credit risk", "initial margin", "variation margin",
    "commodity futures", "futures commission merchant", "isda",
    "futures", "commodity", "clearinghouse", "clearing house",
    "derivatives clearing organization", "designated contract market",
    "swap dealer", "large trader", "mifid", "mifir",
    "market infrastructure", "financial market infrastructure",
    "collateral", "repo", "securities financing", "short selling",
]

# Items matching these are dropped regardless of source (digests, reposts,
# sanctions-list housekeeping, vacancies).
EXCLUDE_TERMS = [
    "e-mail alert", "email alert", "icymi", "sanktionsmeldung",
    "vacancy", "vacancies", "call for papers", "job opening",
]

# topic tag -> trigger terms (matching topics become the item's tags)
TOPIC_RULES = [
    ("Margin", ["margin", "collateral"]),
    ("CCP Risk", ["central counterparty", "ccp", "default fund", "recovery and resolution"]),
    ("Clearing Obligation", ["clearing obligation", "mandatory clearing", "clearing requirement", "cleared", "clearing"]),
    ("Trade Reporting", ["trade repository", "reporting", "upi", "uti", "data quality"]),
    ("Trading Venues", ["trading venue", "swap execution facility", "sef ", "trading obligation", "exchange"]),
    ("Capital Requirements", ["capital", "sa-ccr", "basel", "output floor", "leverage ratio"]),
    ("Cross-border", ["cross-border", "equivalence", "third-country", "deference", "comparability"]),
    ("Benchmarks", ["benchmark", "libor", "risk-free rate", "fallback"]),
    ("Crypto Derivatives", ["crypto", "digital asset", "tokenis", "tokeniz", "stablecoin"]),
    ("Position Limits", ["position limit"]),
    ("Market Conduct", ["enforcement", "penalty", "fine", "charges", "manipulation", "fraud", "settle", "bans"]),
    ("Netting", ["netting", "close-out"]),
]

# document type inference from the title (first match wins)
DOCTYPE_RULES = [
    ("Final Rule", ["final rule", "adopts final", "adopts amendments", "approves final",
                    "finalises", "finalizes", "final report on"]),
    ("Consultation Paper", ["consultation", "consults", "discussion paper", "call for evidence",
                            "comment period", "invites comments", "seeks public comment",
                            "seeks comment", "requests comment", "request for comment"]),
    ("Proposed Rule", ["proposed rule", "proposes", "propose ", "proposal", "draft rule"]),
    ("Enforcement Action", ["enforcement action", "imposes monetary penalty", "imposes penalty",
                            "monetary penalty", "settlement order", "adjudication order",
                            "fines", "penalises", "penalizes", "prohibits", "debars"]),
    ("Guidance", ["guidance", "guidelines", "q&a", "faqs", "supervisory expectations",
                  "circular", "directions under"]),
    ("Speech", ["speech by", "remarks by", "keynote address", "keynote speech",
                "opening remarks", "closing remarks", "welcome address"]),
    ("Report", ["report", "review", "study", "findings", "statistics", "bulletin"]),
    ("Statement", ["statement", "announces", "announcement", "declares"]),
]

DOCTYPE_SCORE = {
    "Final Rule": 3.0,
    "Proposed Rule": 2.2,
    "Consultation Paper": 2.0,
    "Guidance": 1.5,
    "Report": 1.0,
    "Enforcement Action": 1.0,
    "Statement": 0.5,
    "Speech": -1.0,
    "Publication": 0.5,
}

# strong-signal terms nudging the impact score upward
IMPACT_BOOST_TERMS = {
    "margin": 0.8,
    "clearing obligation": 1.0,
    "central counterparty": 0.8,
    "ccp": 0.6,
    "capital": 0.6,
    "sa-ccr": 0.8,
    "swap": 0.5,
    "derivative": 0.5,
    "emir": 0.6,
    "dodd-frank": 0.6,
    "trade repository": 0.5,
    "clearing": 0.6,
    "uncleared": 0.9,
    "bilateral margin": 0.9,
    "otc": 0.7,
    "position limit": 0.5,
    "effective date": 0.4,
    "compliance date": 0.5,
}

INTERNATIONAL_BONUS = 0.5  # FSB/BCBS/IOSCO output tends to move every jurisdiction
NON_DERIVATIVES_PENALTY = 1.5  # general financial-regulation items rank lower

MONTH = r"(?:January|February|March|April|May|June|July|August|September|October|November|December)"
DATE_PATTERN = rf"({MONTH}\s+\d{{1,2}},?\s+\d{{4}}|\d{{1,2}}\s+{MONTH}\s+\d{{4}})"

DEADLINE_RULES = [
    ("Comments due", rf"(?:comments?\s+(?:are\s+)?due|comment period\s+(?:ends|closes)|responses?\s+(?:are\s+)?(?:due|requested)\s+by|feedback\s+by|submissions?\s+by)\s*(?:on\s+)?{DATE_PATTERN}"),
    ("Consultation closes", rf"consultation\s+(?:closes|ends|period\s+ends)\s*(?:on\s+)?{DATE_PATTERN}"),
    ("Effective date", rf"(?:effective|enters?\s+into\s+force|takes?\s+effect)\s*(?:on|from|as\s+of)?\s*{DATE_PATTERN}"),
    ("Compliance deadline", rf"(?:compliance\s+(?:date|deadline)|must\s+comply\s+by)\s*(?:of|is|by)?\s*{DATE_PATTERN}"),
]

TAG_STRIP = re.compile(r"<[^>]+>")
WS = re.compile(r"\s+")
# "Thursday, September 10, 2026 - 15:04" -> parseable by dateutil once the
# dash between date and time is removed.
DASH_BEFORE_TIME = re.compile(r"\s+-\s+(?=\d{1,2}:\d{2})")


def clean_html(text: str) -> str:
    """Strip tags/entities and collapse whitespace."""
    text = TAG_STRIP.sub(" ", text or "")
    for entity, char in [("&amp;", "&"), ("&nbsp;", " "), ("&#39;", "'"),
                         ("&quot;", '"'), ("&lt;", "<"), ("&gt;", ">"),
                         ("&rsquo;", "'"), ("&ldquo;", '"'), ("&rdquo;", '"')]:
        text = text.replace(entity, char)
    return WS.sub(" ", text).strip()


def is_relevant(text: str) -> bool:
    lower = text.lower()
    return any(term in lower for term in RELEVANCE_TERMS)


def is_excluded(text: str) -> bool:
    lower = text.lower()
    return any(term in lower for term in EXCLUDE_TERMS)


def infer_doctype(title: str) -> str:
    lower = title.lower()
    for doctype, terms in DOCTYPE_RULES:
        if any(term in lower for term in terms):
            return doctype
    return "Publication"


def infer_tags(text: str) -> list[str]:
    lower = text.lower()
    tags = [topic for topic, terms in TOPIC_RULES if any(t in lower for t in terms)]
    return tags[:4] or ["General"]


def score_impact(text: str, doctype: str, region: str, relevant: bool) -> float:
    score = 4.0 + DOCTYPE_SCORE.get(doctype, 0.5)
    lower = text.lower()
    boost = sum(v for term, v in IMPACT_BOOST_TERMS.items() if term in lower)
    score += min(boost, 2.5)
    if region == "International Bodies":
        score += INTERNATIONAL_BONUS
    if not relevant:
        score -= NON_DERIVATIVES_PENALTY
    return round(max(0.0, min(10.0, score)), 1)


def extract_deadline(text: str, published: datetime):
    """Return {'date': iso, 'label': str} for the first future date found."""
    for label, pattern in DEADLINE_RULES:
        match = re.search(pattern, text, flags=re.IGNORECASE)
        if not match:
            continue
        try:
            parsed = dateparser.parse(match.group(1)).replace(tzinfo=timezone.utc)
        except (ValueError, OverflowError, TypeError):
            continue
        if parsed > published:  # ignore dates in the past relative to publication
            return {"date": parsed.strftime("%Y-%m-%dT%H:%M:%SZ"), "label": label}
    return None


def entry_datetime(entry) -> datetime | None:
    """Best-effort publication timestamp for a feed entry.

    feedparser only fills *_parsed for formats it recognises; several
    regulators (the FCA among them) publish human-readable stamps such as
    "Thursday, September 10, 2026 - 15:04", so fall back to dateutil on the
    raw strings before giving up.
    """
    for attr in ("published_parsed", "updated_parsed", "created_parsed"):
        value = getattr(entry, attr, None)
        if value:
            return datetime.fromtimestamp(time.mktime(value), tz=timezone.utc)

    for attr in ("published", "updated", "created", "dc_date", "date"):
        raw = entry.get(attr) if hasattr(entry, "get") else None
        if not raw:
            continue
        try:
            parsed = dateparser.parse(DASH_BEFORE_TIME.sub(" ", str(raw)))
        except (ValueError, OverflowError, TypeError):
            continue
        if parsed is None:
            continue
        return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)

    return None


# ---------------------------------------------------------------------------
# State: last run timestamp + first-seen index for undated feeds
# ---------------------------------------------------------------------------

def load_state(path: Path) -> dict:
    if not path or not path.exists():
        return {"lastRun": None, "seen": {}}
    try:
        state = json.loads(path.read_text())
    except (ValueError, OSError):
        return {"lastRun": None, "seen": {}}
    state.setdefault("lastRun", None)
    state.setdefault("seen", {})
    return state


def save_state(path: Path, state: dict) -> None:
    if not path:
        return
    cutoff = datetime.now(timezone.utc) - timedelta(days=SEEN_RETENTION_DAYS)
    pruned = {}
    for url, stamp in state.get("seen", {}).items():
        try:
            when = dateparser.parse(stamp)
        except (ValueError, TypeError):
            continue
        if when and when.replace(tzinfo=when.tzinfo or timezone.utc) >= cutoff:
            pruned[url] = stamp
    state["seen"] = pruned
    path.write_text(json.dumps(state, indent=2, sort_keys=True))


def effective_window(requested_hours: int, state: dict) -> int:
    """Widen the window to cover any gap since the last successful run.

    GitHub's scheduler drifts (observed up to ~75 minutes), so consecutive
    runs can be more than 24 hours apart. Without this, publications landing
    in the drift gap would never appear in any snapshot.
    """
    last_run = state.get("lastRun")
    if not last_run:
        return requested_hours
    try:
        previous = dateparser.parse(last_run)
    except (ValueError, TypeError):
        return requested_hours
    if previous is None:
        return requested_hours
    if not previous.tzinfo:
        previous = previous.replace(tzinfo=timezone.utc)
    gap_hours = (datetime.now(timezone.utc) - previous).total_seconds() / 3600.0
    # +1h of slack so an item published moments before the last run's cutoff
    # is not lost to rounding.
    return int(min(MAX_WINDOW_HOURS, max(requested_hours, gap_hours + 1)))


def collect(sources: list[dict], window_hours: int, state: dict) -> list[dict]:
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(hours=window_hours)
    seen: dict = state.setdefault("seen", {})
    publications, seen_urls = [], set()
    undated_sources = set()

    for source in sources:
        for feed_url in source["feeds"]:
            try:
                parsed = feedparser.parse(feed_url, agent=USER_AGENT)
            except Exception as error:  # one bad source must not kill the run
                print(f"WARN {source['code']}: {feed_url} failed: {error}", file=sys.stderr)
                continue
            if parsed.bozo and not parsed.entries:
                print(f"WARN {source['code']}: {feed_url} unparseable", file=sys.stderr)
                continue
            if not parsed.entries:
                print(f"WARN {source['code']}: {feed_url} returned no entries", file=sys.stderr)
                continue

            for entry in parsed.entries:
                link = (getattr(entry, "link", "") or "").strip()
                title = clean_html(getattr(entry, "title", ""))
                if not title or not link or link in seen_urls:
                    continue

                published = entry_datetime(entry)
                if published is None:
                    # Undated feed: date the item by first sighting so it
                    # enters exactly one daily snapshot.
                    undated_sources.add(source["code"])
                    recorded = seen.get(link)
                    if recorded:
                        try:
                            published = dateparser.parse(recorded)
                        except (ValueError, TypeError):
                            published = None
                    if published is None:
                        published = now
                        seen[link] = now.strftime("%Y-%m-%dT%H:%M:%SZ")
                    elif not published.tzinfo:
                        published = published.replace(tzinfo=timezone.utc)

                if published < cutoff or published > now + timedelta(days=1):
                    continue

                summary = clean_html(getattr(entry, "summary", "") or getattr(entry, "description", ""))
                haystack = f"{title} {summary}"
                if is_excluded(haystack):
                    continue

                # Wide-net policy: everything a regulator publishes is kept
                # (default "all"); OTC-derivatives relevance boosts ranking
                # instead of gating. Set "relevance": "keyword" on a source
                # to restrict it to OTC-matching items only.
                relevant = is_relevant(haystack)
                if source.get("relevance", "all") == "keyword" and not relevant:
                    continue
                seen_urls.add(link)

                doctype = infer_doctype(title)
                publications.append({
                    "id": str(uuid.uuid5(uuid.NAMESPACE_URL, link)).upper(),
                    "title": title[:300],
                    "summary": summary[:900] or f"{source['name']} published: {title}",
                    "regulatorCode": source["code"],
                    "regulatorName": source["name"],
                    "region": source["region"],
                    "publicationDate": published.strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "documentType": doctype,
                    "impactScore": score_impact(haystack, doctype, source["region"], relevant),
                    "url": link,
                    "tags": infer_tags(haystack),
                    "fullText": None,
                    "deadline": extract_deadline(haystack, published),
                })

    if undated_sources:
        print(f"NOTE undated feeds dated by first sighting: {', '.join(sorted(undated_sources))}",
              file=sys.stderr)

    publications.sort(key=lambda p: p["publicationDate"], reverse=True)
    return publications


def main() -> int:
    arg_parser = argparse.ArgumentParser(description=__doc__)
    arg_parser.add_argument("--hours", type=int, default=24,
                            help="snapshot window in hours (default 24; widened "
                                 "automatically to cover any gap since the last run)")
    arg_parser.add_argument("--out", default="daily.json")
    arg_parser.add_argument("--state", default=None,
                            help="path to the persistent state file (last run + "
                                 "first-seen index for undated feeds)")
    arg_parser.add_argument("--sources", default=str(Path(__file__).parent / "sources.json"))
    args = arg_parser.parse_args()

    state_path = Path(args.state) if args.state else None
    state = load_state(state_path)
    window = effective_window(args.hours, state)
    if window != args.hours:
        print(f"NOTE window widened {args.hours}h -> {window}h to cover the gap "
              f"since the last run", file=sys.stderr)

    sources = json.loads(Path(args.sources).read_text())["sources"]
    publications = collect(sources, window, state)

    now = datetime.now(timezone.utc)
    feed = {
        "date": now.strftime("%Y-%m-%d"),
        "generatedAt": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "publications": publications,
    }
    Path(args.out).write_text(json.dumps(feed, indent=2, ensure_ascii=False))

    state["lastRun"] = now.strftime("%Y-%m-%dT%H:%M:%SZ")
    save_state(state_path, state)

    high = sum(1 for p in publications if p["impactScore"] >= 7.5)
    regions = {p["region"] for p in publications}
    print(f"Wrote {args.out}: {len(publications)} publications ({high} high-impact) "
          f"from {len(sources)} sources across {len(regions)} regions, window {window}h")
    return 0


if __name__ == "__main__":
    sys.exit(main())
