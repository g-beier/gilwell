const { JSDOM } = require("jsdom");
const fs = require("fs"), path = require("path");
const root = process.argv[2];
let html = fs.readFileSync(path.join(root, "index.html"), "utf8");
html = html.replace(/<script src="([^"]+)"><\/script>/g, (m, s) => "<script>" + fs.readFileSync(path.join(root, s), "utf8") + "</script>");
const dom = new JSDOM(html, { runScripts: "dangerously", pretendToBeVisual: true, beforeParse(w) { w.scrollTo = () => {}; w.HTMLElement.prototype.scrollIntoView = () => {}; } });
const d = dom.window.document; let fail = 0;
const ok = (c, m) => { console.log(c ? "ok:" : "FAIL:", m); if (!c) fail = 1; };
const click = el => el.dispatchEvent(new dom.window.MouseEvent("click", { bubbles: true }));
dom.window.addEventListener("load", () => {
  click(d.querySelectorAll("#menu-list button")[3]);
  // order of each theme as it appears on the map
  const themes = { youth: [1,4,6,11], families: [2,3,8,9,13], theme: [5,7,10,12] };
  for (const [g, ids] of Object.entries(themes)) {
    // map cards in the expected order?
    const map = [...d.querySelectorAll("#v-variations .variation-card")].map(b => +b.dataset.variation);
    ok(ids.every(i => map.includes(i)), "map contains " + ids.join(","));
    click(d.querySelector('[data-variation="' + ids[0] + '"]'));
    for (let k = 0; k < ids.length; k++) {
      const title = d.querySelector(".detail-header .tag").textContent;
      ok(title.startsWith("Variation " + ids[k] + " "), "opened variation " + ids[k] + " (" + g + ")");
      const nav = [...d.querySelectorAll(".nav-variation [data-go]")].map(b => +b.dataset.go);
      const expected = [];
      if (k > 0) expected.push(ids[k-1]);
      if (k < ids.length - 1) expected.push(ids[k+1]);
      ok(JSON.stringify(nav) === JSON.stringify(expected), "navigation of " + ids[k] + ": " + nav.join("/") + " (expected " + expected.join("/") + ")");
      if (k === ids.length - 1) { ok(!!d.getElementById("btn-map-end"), "'end of theme' button on the last of " + g); click(d.getElementById("btn-map-end")); ok(!!d.querySelector(".variation-card"), "returned to the map"); }
      else click(d.querySelector('.nav-variation [data-go="' + ids[k+1] + '"]'));
    }
  }
  process.exit(fail);
});
