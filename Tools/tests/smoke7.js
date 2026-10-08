// Free structure (no variations): hand-made sections, "next" button, quiz that unlocks "Reveal",
// reflection block, completion by quiz + reflection, state resume.
const { JSDOM } = require("jsdom");
const fs = require("fs"), path = require("path");
const root = process.argv[2];
const block = (id, type, o) => Object.assign({ id, type }, o);
const structure = {
  schemaVersion: 2, template: "case-study", label: "Course X", title: "My SCORM", subtitle: "",
  sections: [
    { id: "a", title: "First", menuLabel: "", intro: "Opening of the first.", blocks: [
      block("a1", "content", { title: "Text", style: "standard", list: false, marker: "plain", items: ["Hello."] }),
      block("a2", "button", { label: "Continue", destination: "next" }),
    ] },
    { id: "b", title: "Second", menuLabel: "2. Quiz", intro: "", blocks: [
      block("q1", "quiz", { title: "Test", prompt: "Tick the right one.", verifyLabel: "Check",
        successMessage: "Correct!", reviewMessage: "Review.", countsForCompletion: true,
        options: [{ text: "A", correct: true, feedback: "ok A" }, { text: "B", correct: false, feedback: "ok B" }] }),
      block("r1", "reveal", { trigger: "quiz:q1", label: "", blocks: [
        block("r1a", "alert", { style: "error", title: "Do not do this", list: true, marker: "cross", items: ["x"] }),
        block("r1b", "button", { label: "Go to the end", destination: "section:c" }) ] }),
      block("f1", "reflection", { question: "What do you think?", notice: "Finding.", minimum: 10, maximum: 500, countsForCompletion: true }),
    ] },
    { id: "c", title: "Third", menuLabel: "", intro: "", blocks: [
      block("c1", "reveal", { trigger: "button", label: "Show more", blocks: [block("c1a", "highlight", { text: "Surprise" })] }),
    ] },
  ],
  variations: { reflectionNotice: "", reflectionMinimum: 10, reflectionMaximum: 500, themes: [], variations: [] },
  completion: { requireAllSections: false, requireVariations: false, requiredVariations: 0, requireQuizzes: true, requiredReflections: 1 },
};
let html = fs.readFileSync(path.join(root, "index.html"), "utf8");
html = html.replace(/<script src="([^"]+)"><\/script>/g, (m, s) =>
  "<script>" + (s === "js/data.js" ? "var STRUCTURE = " + JSON.stringify(structure) + ";" : fs.readFileSync(path.join(root, s), "utf8")) + "</script>");
const store = { "cmi.core.lesson_status": "not attempted", "cmi.suspend_data": "" };
let count = 0;
const API = {
  LMSInitialize: () => "true",
  LMSGetValue: k => k === "cmi.interactions._count" ? String(count) : (store[k] || ""),
  LMSSetValue: (k, v) => { store[k] = v; const m = k.match(/^cmi\.interactions\.(\d+)\.id$/); if (m) count = Math.max(count, +m[1] + 1); return "true"; },
  LMSCommit: () => "true", LMSFinish: () => "true",
};
const mk = () => new JSDOM(html, { runScripts: "dangerously", pretendToBeVisual: true, beforeParse(w) { w.API = API; w.scrollTo = () => {}; w.HTMLElement.prototype.scrollIntoView = () => {}; } });
let fail = 0; const ok = (c, m) => { console.log(c ? "ok:" : "FAIL:", m); if (!c) fail = 1; };
const click = (w, el) => el.dispatchEvent(new w.MouseEvent("click", { bubbles: true, cancelable: true }));
const visible = (d, id) => !d.getElementById("v-" + id).hidden;
const errors = [];

const d1 = mk();
d1.window.addEventListener("error", e => errors.push(e.message));
d1.window.addEventListener("load", () => {
  const d = d1.window.document, w = d1.window;
  const menu = [...d.querySelectorAll("#menu-list button")].map(b => b.textContent);
  ok(JSON.stringify(menu) === JSON.stringify(["First", "2. Quiz", "Third"]), "sections menu: " + menu.join("|"));
  ok(d.getElementById("prog-label").textContent === "sections visited", "progress by sections (no variations)");
  ok(d.querySelector("#v-a .lead").textContent === "Opening of the first.", "section opening");
  ok(store["cmi.core.lesson_status"] === "incomplete", "starts incomplete");

  click(w, d.querySelector("#v-a [data-go-to]"));
  ok(visible(d, "b") && !visible(d, "a"), "'next' button led to the second section");
  ok(!d.querySelector("#v-b .reveal-content"), "reveal waits for the quiz");

  const inputs = d.querySelectorAll("#v-b .quiz-options input");
  inputs[1].checked = true;
  click(w, d.querySelector("#v-b .quiz-check"));
  ok(/Review/.test(d.querySelector("#v-b .quiz-result").textContent), "wrong quiz: review message");
  ok(!!d.querySelector("#v-b .reveal-content .card.alert"), "checked quiz unlocks the content (error alert)");
  ok(store["cmi.core.lesson_status"] === "incomplete", "getting it wrong does not complete");

  click(w, d.querySelector("#v-b .quiz-retry"));
  ok(!d.querySelector("#v-b .reveal-content"), "try again hides the content again");
  const in2 = d.querySelectorAll("#v-b .quiz-options input");
  in2[0].checked = true;
  click(w, d.querySelector("#v-b .quiz-check"));
  ok(/Correct/.test(d.querySelector("#v-b .quiz-result").textContent), "right quiz: success message");
  ok(store["cmi.core.lesson_status"] === "incomplete", "reflection is missing and the third section does not matter");

  const ta = d.querySelector("#v-b textarea");
  ta.value = "My complete reflection."; ta.dispatchEvent(new w.Event("input"));
  click(w, d.querySelector("#v-b .reflection-submit"));
  ok(store["cmi.interactions.0.id"] === "reflection_f1", "interaction saved: " + store["cmi.interactions.0.id"]);
  ok(store["cmi.core.lesson_status"] === "completed", "quiz passed + 1 reflection = completed");
  const saved = JSON.parse(store["cmi.suspend_data"]);
  ok(saved.k.indexOf("q1") !== -1 && saved.b.indexOf("f1") !== -1, "suspend_data stores quiz and reflection");

  click(w, d.querySelector("#v-b .reveal-content [data-go-to]"));
  ok(visible(d, "c"), "button inside the reveal led to section c");
  click(w, d.querySelector("#v-c .reveal button"));
  ok(/Surprise/.test(d.querySelector("#v-c").textContent), "button reveal shows the highlight");
  ok(errors.length === 0, "no script errors " + errors.join("|"));

  // resume
  const d2 = mk();
  d2.window.addEventListener("load", () => {
    const e = d2.window.document;
    ok(visible(e, "c"), "resumes at the last section seen");
    ok(/Surprise/.test(e.querySelector("#v-c").textContent), "open reveal stays open");
    click(d2.window, e.querySelectorAll("#menu-list button")[1]);
    ok(!!e.querySelector("#v-b .reveal-content"), "checked quiz: content unlocked on resume");
    ok(/sent/.test(e.querySelector("#v-b .reflection").textContent) && !e.querySelector("#v-b textarea"), "reflection appears as sent");
    process.exit(fail);
  });
});
