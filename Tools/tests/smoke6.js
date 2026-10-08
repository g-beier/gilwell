// Moodle reaplica 98% depois: o pacote deve devolver 100%
const { JSDOM } = require("jsdom"); const fs = require("fs"), path = require("path");
const root = process.argv[2];
const outer = new JSDOM('<body><iframe id="scorm_object" style="width:98%;height:98%"></iframe></body>', { pretendToBeVisual: true });
const frame = outer.window.document.getElementById("scorm_object");
let html = fs.readFileSync(path.join(root, "index.html"), "utf8");
html = html.replace(/<script src="([^"]+)"><\/script>/g, (m, s) => "<script>" + fs.readFileSync(path.join(root, s), "utf8") + "</script>");
const dom = new JSDOM(html, { runScripts: "dangerously", pretendToBeVisual: true, beforeParse(w) { w.scrollTo = () => {}; Object.defineProperty(w, "frameElement", { value: frame, configurable: true }); } });
dom.window.addEventListener("load", () => setTimeout(() => {
  frame.style.setProperty("width", "98%");
  setTimeout(() => { const ok = frame.style.width === "100%"; console.log(ok ? "ok: largura devolvida a 100%" : "FAIL: " + frame.style.width); process.exit(ok ? 0 : 1); }, 20);
}, 20));
