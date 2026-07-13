// Builds manifest.webmanifest with embedded PNG icon data URIs, and writes
// the standalone icon-192.png / icon-512.png files. Run after gen-icons.js.
const fs = require("fs");
const path = require("path");
const root = path.join(__dirname, "..");
const icons = JSON.parse(fs.readFileSync(path.join(__dirname, "icons.json"), "utf8"));

const manifest = {
  name: "SubTrack — Subscription Tracker",
  short_name: "SubTrack",
  description: "Track your subscriptions and never miss a cancellation window.",
  start_url: "./index.html",
  scope: "./",
  display: "standalone",
  orientation: "portrait",
  background_color: "#14161F",
  theme_color: "#14161F",
  categories: ["finance", "productivity", "utilities"],
  icons: [
    { src: icons["192"], sizes: "192x192", type: "image/png", purpose: "any" },
    { src: icons["512"], sizes: "512x512", type: "image/png", purpose: "any" },
    { src: icons["512"], sizes: "512x512", type: "image/png", purpose: "maskable" }
  ]
};

fs.writeFileSync(path.join(root, "manifest.webmanifest"), JSON.stringify(manifest, null, 2));
fs.writeFileSync(path.join(root, "icon-192.png"), Buffer.from(icons["192"].split(",")[1], "base64"));
fs.writeFileSync(path.join(root, "icon-512.png"), Buffer.from(icons["512"].split(",")[1], "base64"));
console.log("Wrote manifest.webmanifest, icon-192.png, icon-512.png");
