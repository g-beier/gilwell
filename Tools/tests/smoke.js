const { JSDOM } = require("jsdom");
const fs = require("fs");
const path = require("path");
const root = process.argv[2];

const store = { "cmi.core.lesson_status": "not attempted", "cmi.suspend_data": "" };
const log = [];
const API = {
  LMSInitialize: () => { log.push("init"); return "true"; },
  LMSGetValue: (k) => store[k] || "",
  LMSSetValue: (k, v) => { store[k] = v; return "true"; },
  LMSCommit: () => "true",
  LMSFinish: () => { log.push("finish"); return "true"; },
  LMSGetLastError: () => "0"
};

let html = fs.readFileSync(path.join(root, "index.html"), "utf8");
html = html.replace(/<script src="([^"]+)"><\/script>/g, (m, src) =>
  "<script>" + fs.readFileSync(path.join(root, src), "utf8") + "</script>");

const dom = new JSDOM(html, {
  runScripts: "dangerously",
  pretendToBeVisual: true,
  beforeParse(win) {
    win.API = API;
    win.scrollTo = () => {};
    win.HTMLElement.prototype.scrollIntoView = function () {};
  }
});
const d = dom.window.document;
const errors = [];
dom.window.addEventListener("error", (e) => errors.push(e.message));

function click(el) { el.dispatchEvent(new dom.window.MouseEvent("click", { bubbles: true })); }
function assert(c, m) { if (!c) { console.log("FAIL:", m); process.exitCode = 1; } else console.log("ok:", m); }

dom.window.addEventListener("load", () => {
assert(d.querySelectorAll("#menu-list button").length === 6, "menu with 6 buttons");
assert(store["cmi.core.lesson_status"] === "incomplete", "status inicial incomplete");

// base case: tick the 4 correct ones
click(d.querySelectorAll("#menu-list button")[1]);
const inputs = d.querySelectorAll(".quiz-options input");
assert(inputs.length === 8, "quiz with 8 options");
[0, 1, 2, 3].forEach((i) => { inputs[i].checked = true; });
click(d.querySelector(".quiz-check"));
assert(!!d.querySelector(".quiz-result .result.good"), "quiz passed with the answer key");
assert(!!d.querySelector("[data-reveal-quiz] .card"), "post-quiz content shown");

// fluxo
click(d.querySelectorAll("#menu-list button")[2]);
assert(d.querySelectorAll(".step").length === 6, "6 steps in the flow");

// variations: reveal all
click(d.querySelectorAll("#menu-list button")[3]);
assert(d.querySelectorAll(".variation-card").length === 13, "13 cards on the map");
for (let i = 1; i <= 13; i++) {
  click(d.querySelectorAll("#menu-list button")[3]);
  click(d.querySelector('[data-variation="' + i + '"]'));
  click(d.getElementById("btn-reveal"));
  if (i === 7) assert(store["cmi.core.lesson_status"] === "incomplete", "still incomplete at the 7th");
}
assert(store["cmi.core.lesson_status"] === "completed", "completed after all 13");
assert(JSON.parse(store["cmi.suspend_data"]).v.length === 13, "suspend_data with 13 ids");
assert(d.getElementById("prog-num").textContent === "13", "progress 13");

// synthesis
click(d.querySelectorAll("#menu-list button")[4]);
assert(d.querySelectorAll("tbody tr").length === 13, "table with 13 rows");
assert(!d.querySelector("#v-synthesis .reveal-content"), "central idea hidden before the click");
click(d.querySelector("#v-synthesis .reveal button"));
assert(!!d.querySelector("#v-synthesis .reveal-content .columns .card"), "ideia central revelada");

dom.window.dispatchEvent(new dom.window.Event("pagehide"));
assert(log.indexOf("finish") !== -1, "LMSFinish chamado");
assert(errors.length === 0, "no script errors " + errors.join("|"));

});
