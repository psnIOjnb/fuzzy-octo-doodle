const { chromium } = require("playwright");
const path = require("path");
(async () => {
  const browser = await chromium.launch({ executablePath: "/opt/pw-browsers/chromium-1194/chrome-linux/chrome" }).catch(async () => {
    return await chromium.launch();
  });
  const ctx = await browser.newContext({ viewport: { width: 412, height: 900 }, deviceScaleFactor: 2 });
  const page = await ctx.newPage();
  const errors = [];
  page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
  page.on("pageerror", (e) => errors.push(String(e)));
  const url = "file://" + path.join(__dirname, "..", "index.html");
  await page.goto(url, { waitUntil: "networkidle" });

  // seed a few subs via the real UI-backed store, then reload to render
  await page.evaluate(() => {
    const today = new Date();
    const iso = (d) => d.toISOString().slice(0, 10);
    const plus = (n) => { const d = new Date(); d.setDate(d.getDate() + n); return iso(d); };
    const data = [
      { id: "a", name: "Netflix", price: 199, currency: "ZAR", cycle: "monthly", nextDate: plus(2), cancelUrl: "https://www.netflix.com/cancelplan", color: "#E50914", cancelled: false },
      { id: "b", name: "Spotify", price: 59.99, currency: "ZAR", cycle: "monthly", nextDate: plus(9), cancelUrl: "", color: "#1DB954", cancelled: false },
      { id: "c", name: "Claude", price: 20, currency: "USD", cycle: "monthly", nextDate: plus(18), cancelUrl: "", color: "#D97757", cancelled: false },
      { id: "d", name: "Adobe", price: 599, currency: "ZAR", cycle: "yearly", nextDate: plus(140), cancelUrl: "", color: "#FA0F00", cancelled: false },
      { id: "e", name: "DStv", price: 449, currency: "ZAR", cycle: "monthly", nextDate: plus(60), cancelUrl: "", color: "#0077C8", cancelled: true }
    ];
    localStorage.setItem("subtrack-v1", JSON.stringify(data));
  });
  await page.reload({ waitUntil: "networkidle" });
  await page.waitForTimeout(200);
  await page.screenshot({ path: path.join(__dirname, "home.png"), fullPage: true });

  // open the add picker
  await page.click("#addBtn");
  await page.waitForTimeout(350);
  await page.screenshot({ path: path.join(__dirname, "picker.png") });

  console.log("console/page errors:", errors.length ? errors.join(" | ") : "none");
  await browser.close();
})().catch((e) => { console.error("shot failed:", e); process.exit(1); });
