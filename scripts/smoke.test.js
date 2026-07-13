// jsdom smoke test — no framework. Exits non-zero on any failure or console error.
const fs = require("fs");
const path = require("path");
const { JSDOM, VirtualConsole } = require("jsdom");

const html = fs.readFileSync(path.join(__dirname, "..", "index.html"), "utf8");

const consoleErrors = [];
const vc = new VirtualConsole();
vc.on("error", (m) => consoleErrors.push("console.error: " + m));
vc.on("jsdomError", (e) => consoleErrors.push("jsdomError: " + (e && e.message)));

const dom = new JSDOM(html, {
  url: "https://localhost/",
  runScripts: "dangerously",
  pretendToBeVisual: true,
  virtualConsole: vc,
});

const { window } = dom;
const doc = window.document;
const $ = (id) => doc.getElementById(id);

const results = [];
let failed = false;
function check(name, cond, extra) {
  results.push((cond ? "  ✓ " : "  ✗ ") + name + (cond ? "" : "  << " + (extra || "")));
  if (!cond) failed = true;
}

function fire(el, type) {
  const ev = new window.Event(type, { bubbles: true, cancelable: true });
  el.dispatchEvent(ev);
}

function done() {
  console.log("\nSubTrack smoke test\n" + "-".repeat(40));

  // 0. app booted
  check("app initialised (window.SubTrack present)", !!window.SubTrack);

  // 1. open picker
  fire($("addBtn"), "click");
  check("picker sheet opens", $("addSheet").classList.contains("show"));
  const presetCount = doc.querySelectorAll(".preset").length;
  check("preset grid populated (>=18 presets + custom)", presetCount >= 19, "found " + presetCount);

  // 2. choose a preset (Netflix)
  const netflix = doc.querySelector('.preset[data-name="Netflix"]');
  check("Netflix preset exists", !!netflix);
  fire(netflix, "click");
  check("form view shown after preset", $("formView").style.display === "block");
  check("name prefilled from preset", $("f-name").value === "Netflix", "got '" + $("f-name").value + "'");

  // 3. save with price 199
  $("f-price").value = "199";
  fire($("f-save"), "click");

  // 4. row renders
  const rows = doc.querySelectorAll("#list .row");
  check("one active row renders", rows.length === 1, "rows=" + rows.length);
  const rowText = rows[0] ? rows[0].textContent : "";
  check("row shows the name", /Netflix/.test(rowText));
  check("row shows price R199", /R199/.test(rowText), rowText);
  check("row has a fuse bar", !!(rows[0] && rows[0].querySelector(".fuse i")));

  // 5. localStorage written under subtrack-v1
  const raw = window.localStorage.getItem("subtrack-v1");
  check("localStorage 'subtrack-v1' written", !!raw);
  let parsed = [];
  try { parsed = JSON.parse(raw); } catch (e) {}
  check("persisted one subscription", parsed.length === 1, "len=" + parsed.length);
  check("persisted price === 199", parsed[0] && parsed[0].price === 199, JSON.stringify(parsed[0]));
  check("persisted currency ZAR", parsed[0] && parsed[0].currency === "ZAR");

  // 6. open detail + mark cancelled
  fire(rows[0], "click");
  check("detail sheet opens", $("detailSheet").classList.contains("show"));
  fire($("d-cancel"), "click");

  // 7. savings tally shows
  check("active list now empty", doc.querySelectorAll("#list .row").length === 0);
  check("cancelled section visible", $("cancelledWrap").style.display === "block");
  const tally = $("savingsTally").textContent;
  check("savings tally shows R199/mo", /R199\/mo/.test(tally), "tally='" + tally + "'");
  const rawAfter = JSON.parse(window.localStorage.getItem("subtrack-v1"));
  check("persisted sub is cancelled", rawAfter[0] && rawAfter[0].cancelled === true);

  // 8. no console errors
  check("zero console errors", consoleErrors.length === 0, consoleErrors.join(" | "));

  console.log(results.join("\n"));
  console.log("-".repeat(40));
  if (consoleErrors.length) {
    console.log("Console errors:\n" + consoleErrors.map((e) => "  " + e).join("\n"));
  }
  console.log(failed ? "\nRESULT: FAIL\n" : "\nRESULT: PASS\n");
  process.exit(failed ? 1 : 0);
}

// wait for the app's scripts to run (init on DOMContentLoaded), then drive it.
if (window.SubTrack) setTimeout(done, 50);
else window.addEventListener("DOMContentLoaded", () => setTimeout(done, 50));
// hard timeout guard
setTimeout(() => { if (!results.length) done(); }, 3000);
