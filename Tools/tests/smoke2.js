const { JSDOM } = require("jsdom");
const fs = require("fs"), path = require("path");
const root = process.argv[2];
// "Moodle": outer page with a fixed 500px iframe inside a wrapper with overflow
const MODE = process.argv[3] || "normal";
const outer = new JSDOM('<body>' + (MODE === "popup" ? "" : '<nav class="navbar fixed-top"></nav>') + '<div id="w" style="height:500px;overflow:auto"><iframe id="scorm_object" style="height:500px;width:98%"></iframe></div></body>', { pretendToBeVisual: true });
const frame = outer.window.document.getElementById("scorm_object");
let html = fs.readFileSync(path.join(root, "index.html"), "utf8");
html = html.replace(/<script src="([^"]+)"><\/script>/g, (m, s) => "<script>" + fs.readFileSync(path.join(root, s), "utf8") + "</script>");
const store = {};
const API = { LMSInitialize: () => "true", LMSGetValue: k => store[k] || "", LMSSetValue: (k, v) => { store[k] = v; return "true"; }, LMSCommit: () => "true", LMSFinish: () => "true" };
const dom = new JSDOM(html, { runScripts: "dangerously", pretendToBeVisual: true, beforeParse(win) {
  win.API = API; win.scrollTo = () => {}; win.HTMLElement.prototype.scrollIntoView = () => {};
  Object.defineProperty(win, "frameElement", { value: frame, configurable: true });
  win.Element.prototype.getBoundingClientRect = function () { return { height: this === win.document.body ? 1234 : 0, top: 0, width: 0, left: 0, right: 0, bottom: 0 }; };
}});
let fail = 0; const ok = (c, m) => { console.log(c ? "ok:" : "FAIL:", m); if (!c) fail = 1; };
dom.window.addEventListener("load", () => {
  setTimeout(() => {
    if (MODE === "popup") {
      ok(!/auto-height/.test(dom.window.document.documentElement.className), "pop-up: no automatic height");
      ok(frame.style.width === "100%", "pop-up: width fixed from 98% to " + frame.style.width);
      frame.style.setProperty("width", "98%");
      setTimeout(() => {}, 0);
      ok(frame.style.height === "500px", "pop-up: iframe untouched (" + frame.style.height + ")");
      ok(dom.window.document.querySelectorAll("#menu-list button").length === 6, "pop-up: menu built");
      dom.window.document.querySelector("#menu-list button:nth-child(1)").click();
      ok(dom.window.document.getElementById("menu-num").textContent === "0", "menu counter");
      process.exit(fail);
    }
    ok(/auto-height/.test(dom.window.document.documentElement.className), "auto-height class applied");
    ok(frame.style.height === "1236px", "iframe adjusted to " + frame.style.height);
    ok(frame.style.width === "100%", "normal: width fixed from 98% to " + frame.style.width);
    const w = outer.window.document.getElementById("w");
    ok(w.style.overflow === "visible" || w.style.height === "auto", "wrapper with overflow released");
    frame.style.setProperty("height", "500px");
    setTimeout(() => {
      ok(frame.style.height === "1236px", "height restored after Moodle overwrote it: " + frame.style.height);
      dom.window.document.getElementById("btn-top").click();
      ok(true, "top button without error");
      process.exit(fail);
    }, 20);
  }, 20);
});
