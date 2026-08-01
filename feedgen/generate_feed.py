#!/usr/bin/env python3
"""
OTC Pulse daily feed generator.

Aggregates official regulator RSS/Atom feeds (feedgen/sources.json), keeps
items relevant to OTC derivatives regulation from the last N hours, scores
their impact, extracts deadlines, and writes a daily.json matching the app's
DailyFeedDTO wire format exactly.

The app deduplicates by id/url on ingest, so overlapping windows across runs
are harmless; ids are UUIDv5 of the item URL and therefore stable.

Usage:
    python feedgen/generate_feed.py --hours 48 --out daily.json
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

# ---------------------------------------------------------------------------
# Relevance: an item is kept if any of these terms appears in title+summary.
# ---------------------------------------------------------------------------
RELEVANCE_TERMS = [
    "swap", "derivative", "otc ", " otc", "margin", "clearing", "cleared",
    "uncleared", "central counterparty", "ccp", "trade repository",
    "trade reporting", "transaction reporting", "emir", "dodd-frank",
    "position limit", "netting", "swap execution facility", "sef ",
    "security-based swap", "benchmark", "libor", "sa-ccr",
    "counterparty credit risk", "initial margin", "variation margin",
    "commodity futures", "futures commission merchant", "isda",
    # market-infrastructure / CFTC-style vocabulary (often title-only feeds)
    "futures", "commodity", "clearinghouse", "clearing house",
    "derivatives clearing organization", "designated contract market",
    "swap dealer", "large trader", "mifid", "mifir",
    "market infrastructure", "financial market infrastructure",
]

# Items matching these are dropped regardless of source (digests, reposts).
EXCLUDE_TERMS = ["e-mail alert", "email alert", "icymi"]

# topic tag -> trigger terms (first matching topics become the item's tags)
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
    ("Market Conduct", ["enforcement", "penalty", "fine", "charges", "manipulation", "fraud", "settle"]),
    ("Netting", ["netting", "close-out"]),
]

# document type inference from the title (first match wins)
DOCTYPE_RULES = [
    ("Final Rule", ["final rule", "adopts", "adopted", "finalises", "finalizes", "final report on"]),
    ("Proposed Rule", ["proposed rule", "proposes", "proposal"]),
    ("Consultation Paper", ["consultation", "consults", "discussion paper", "call for evidence", "comment period"]),
    ("Guidance", ["guidance", "guidelines", "q&a", "faqs", "supervisory expectations"]),
    ("Enforcement Action", ["enforcement", "charges", "fines", "penalty", "orders", "settles", "sanction"]),
    ("Speech", ["speech", "remarks", "keynote"]),
    ("Report", ["report", "review", "study", "findings", "statistics"]),
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
    "effective date": 0.4,
    "compliance date": 0.5,
}

INTERNATIONAL_BONUS = 0.5  # FSB/BCBS output tends to move every jurisdiction

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


def score_impact(text: str, doctype: str, region: str) -> float:
    score = 4.0 + DOCTYPE_SCORE.get(doctype, 0.5)
    lower = text.lower()
    boost = sum(v for term, v in IMPACT_BOOST_TERMS.items() if term in lower)
    score += min(boost, 2.5)
    if region == "International Bodies":
        score += INTERNATIONAL_BONUS
    return round(max(0.0, min(10.0, score)), 1)


def extract_deadline(text: str, published: datetime):
    """Return {'date': iso, 'label': str} for the first future date found."""
    for label, pattern in DEADLINE_RULES:
        match = re.search(pattern, text, flags=re.IGNORECASE)
        if not match:
            continue
        try:
            parsed = dateparser.parse(match.group(1)).replace(tzinfo=timezone.utc)
        except (ValueError, OverflowError):
            continue
        if parsed > published:  # ignore dates in the past relative to publication
            return {"date": parsed.strftime("%Y-%m-%dT%H:%M:%SZ"), "label": label}
    return None


def entry_datetime(entry) -> datetime | None:
    for attr in ("published_parsed", "updated_parsed"):
        value = getattr(entry, attr, None)
        if value:
            return datetime.fromtimestamp(time.mktime(value), tz=timezone.utc)
    return None


def collect(sources: list[dict], window_hours: int) -> list[dict]:
    cutoff = datetime.now(timezone.utc) - timedelta(hours=window_hours)
    publications, seen_urls = [], set()

    for source in sources:
        for feed_url in source["feeds"]:
            try:
                parsed = feedparser.parse(feed_url, agent=USER_AGENT)
            except Exception as error:  # network hiccup on one source shouldn't kill the run
                print(f"WARN {source['code']}: {feed_url} failed: {error}", file=sys.stderr)
                continue
            if parsed.bozo and not parsed.entries:
                print(f"WARN {source['code']}: {feed_url} unparseable", file=sys.stderr)
                continue

            for entry in parsed.entries:
                published = entry_datetime(entry)
                if published is None or published < cutoff:
                    continue

                link = (getattr(entry, "link", "") or "").strip()
                title = clean_html(getattr(entry, "title", ""))
                summary = clean_html(getattr(entry, "summary", "") or getattr(entry, "description", ""))
                if not title or not link or link in seen_urls:
                    continue

                haystack = f"{title} {summary}"
                if is_excluded(haystack):
                    continue
                # Sources whose entire output is derivatives regulation
                # (relevance: "all", e.g. CFTC) skip the keyword gate —
                # their feeds often carry title-only entries.
                if source.get("relevance", "keyword") != "all" and not is_relevant(haystack):
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
                    "impactScore": score_impact(haystack, doctype, source["region"]),
                    "url": link,
                    "tags": infer_tags(haystack),
                    "fullText": None,
                    "deadline": extract_deadline(haystack, published),
                })

    publications.sort(key=lambda p: p["publicationDate"], reverse=True)
    return publications


def main() -> int:
    arg_parser = argparse.ArgumentParser(description=__doc__)
    arg_parser.add_argument("--hours", type=int, default=48,
                            help="lookback window; overlap is fine (app dedupes)")
    arg_parser.add_argument("--out", default="daily.json")
    arg_parser.add_argument("--sources", default=str(Path(__file__).parent / "sources.json"))
    args = arg_parser.parse_args()

    sources = json.loads(Path(args.sources).read_text())["sources"]
    publications = collect(sources, args.hours)

    now = datetime.now(timezone.utc)
    feed = {
        "date": now.strftime("%Y-%m-%d"),
        "generatedAt": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "publications": publications,
    }
    Path(args.out).write_text(json.dumps(feed, indent=2, ensure_ascii=False))
    print(f"Wrote {args.out}: {len(publications)} publications "
          f"({sum(1 for p in publications if p['impactScore'] >= 7.5)} high-impact) "
          f"from {len(sources)} sources, window {args.hours}h")
    return 0


if __name__ == "__main__":
    sys.exit(main())
