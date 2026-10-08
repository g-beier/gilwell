const { JSDOM } = require("jsdom");
const fs = require("fs"), path = require("path");
const root = process.argv[2]; const REQUIRED = process.argv[3] || "0";
let html = fs.readFileSync(path.join(root, "index.html"), "utf8");
html = html.replace(/<script src="([^"]+)"><\/script>/g, (m, s) => {
  let code = fs.readFileSync(path.join(root, s), "utf8");
  if (s === "js/data.js") code = code.replace('"requiredReflections": 0', '"requiredReflections": ' + REQUIRED);
  return "<script>" + code + "</script>";
});
const store = { "cmi.core.lesson_status": "not attempted", "cmi.suspend_data": "" };
let count = 0; const finished = [];
const API = {
  LMSInitialize: () => "true",
  LMSGetValue: k => k === "cmi.interactions._count" ? String(count) : (store[k] || ""),
  LMSSetValue: (k, v) => { store[k] = v; const m = k.match(/^cmi\.interactions\.(\d+)\.id$/); if (m) count = Math.max(count, +m[1] + 1); return "true"; },
  LMSCommit: () => "true", LMSFinish: () => { finished.push(1); return "true"; }
};
const mk = () => new JSDOM(html, { runScripts: "dangerously", pretendToBeVisual: true, beforeParse(w) { w.API = API; w.scrollTo = () => {}; w.HTMLElement.prototype.scrollIntoView = () => {}; } });
let fail = 0; const ok = (c, m) => { console.log(c ? "ok:" : "FAIL:", m); if (!c) fail = 1; };
function run(dom, fn) { return new Promise(r => dom.window.addEventListener("load", () => { fn(dom.window.document, dom.window); r(); })); }
const click = (w, el) => el.dispatchEvent(new w.MouseEvent("click", { bubbles: true, cancelable: true }));
(async () => {
  const dom = mk();
  await run(dom, (d, w) => {
    click(w, d.querySelectorAll("#menu-list button")[3]);
    click(w, d.querySelector('[data-variation="1"]'));
    click(w, d.getElementById("btn-reveal"));
    const ta = d.getElementById("reflection"), btn = d.getElementById("btn-send-reflection");
    ok(!!ta && btn.disabled, "reflection field present, button disabled");
    ta.value = "curto"; ta.dispatchEvent(new w.Event("input"));
    ok(btn.disabled, "short text does not enable sending");
    ta.value = "Line one.\nLine two with accents: café, naïve. " + "x".repeat(520);
    ta.dispatchEvent(new w.Event("input"));
    ok(!btn.disabled, "enough text enables sending");
    click(w, btn);
    ok(ta.readOnly && btn.hidden, "field locked after sending");
    ok(/Reflection sent/.test(d.getElementById("reflection-status").textContent), "sent message");
    const n = count;
    ok(n >= 2, "interactions saved in parts (" + n + ")");
    ok(store["cmi.interactions.0.id"] === "variation_01_reflection_p1", "id of the 1st part: " + store["cmi.interactions.0.id"]);
    ok(store["cmi.interactions.0.type"] === "fill-in", "type fill-in");
    ok(store["cmi.interactions.0.student_response"].length <= 250 && !/\n/.test(store["cmi.interactions.0.student_response"]), "response <=250 and no line breaks");
    ok(/^[\u0021-\u007E]+$/.test(store["cmi.interactions.0.id"]), "id with visible ASCII only");
    ok(JSON.parse(store["cmi.suspend_data"]).r.indexOf(1) !== -1, "suspend_data records reflection 1");
    // second (short) reflection continues the numbering
    click(w, d.getElementById("btn-map"));
    click(w, d.querySelector('[data-variation="4"]'));
    click(w, d.getElementById("btn-reveal"));
    const ta2 = d.getElementById("reflection"); ta2.value = "My short reflection on the case."; ta2.dispatchEvent(new w.Event("input"));
    click(w, d.getElementById("btn-send-reflection"));
    ok(store["cmi." + "interactions." + n + ".id"] === "variation_04_reflection", "2nd reflection without suffix, index " + n);
    // remaining variations to complete
    for (let i of [2,3,5,6,7,8,9,10,11,12,13]) { click(w, d.getElementById("btn-map")); click(w, d.querySelector('[data-variation="' + i + '"]')); click(w, d.getElementById("btn-reveal")); }
    ok(store["cmi.core.lesson_status"] === (REQUIRED === "0" ? "completed" : "incomplete"), "status after 13 reveals with REQUIRED_REFLECTIONS=" + REQUIRED + ": " + store["cmi.core.lesson_status"]);
    if (REQUIRED !== "0") {
      for (let i of [2,3]) { click(w, d.getElementById("btn-map")); click(w, d.querySelector('[data-variation="' + i + '"]')); const t = d.getElementById("reflection"); t.value = "Reflection number " + i + " complete."; t.dispatchEvent(new w.Event("input")); click(w, d.getElementById("btn-send-reflection")); }
      ok(store["cmi.core.lesson_status"] === "completed", "completed after sending " + REQUIRED + " reflections");
    }
    w.dispatchEvent(new w.Event("pagehide"));
    ok(!!store["cmi.core.session_time"] && /^\d{4}:\d\d:\d\d$/.test(store["cmi.core.session_time"]), "session_time " + store["cmi.core.session_time"]);
    ok(store["cmi.core.exit"] === "", "exit empty after completing");
  });
  // resume: new session reads suspend_data and shows the already-sent reflection
  const dom2 = mk();
  await run(dom2, (d, w) => {
    click(w, d.querySelectorAll("#menu-list button")[3]);
    ok(d.querySelectorAll(".variation-card.seen").length === 13, "resume: 13 variations marked as seen");
    click(w, d.querySelector('[data-variation="1"]'));
    ok(/Reflection sent/.test(d.querySelector(".card.question").textContent) && !d.getElementById("reflection"), "resume: reflection 1 shown as sent, no field");
  });
  process.exit(fail);
})();
