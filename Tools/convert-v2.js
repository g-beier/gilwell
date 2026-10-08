// Converts a .gilwell project (format 1) into sections and blocks (format 2).
// Same logic as gilwellSCROM/Blocks/V1Converter.swift — keep the two identical.
// Uso: node converter-v2.js projeto.gilwell [saida.json]
const fs = require("fs");


function convert(p) {
  const c = p.content, texts = p.texts || {}, config = p.config || {};
  const T = {
    flowTitle: "Basic procedure flow",
    flowIntro: "Steps that serve as a reference for all the variations. Open each step.",
    dontsTitle: "What NOT to do",
    synthesisQuestion: "In one sentence: what stayed the same in every variation?",
    centralIdea: [], principlesTitle: "Principles", takeawaysTitle: "Key takeaways",
  };
  Object.keys(texts).forEach(k => { if (texts[k] !== undefined && texts[k] !== "") T[k] = texts[k]; });
  const total = c.variations.length;
  const required = config.requiredVariations > 0 ? Math.min(config.requiredVariations, total) : total;
  const reflections = config.requiredReflections > 0 ? Math.min(config.requiredReflections, total) : 0;

  const content = (id, o) => Object.assign({ id, type: "content", title: "", style: "standard", list: true, marker: "plain", items: [] }, o);
  const alert = (id, o) => Object.assign({ id, type: "alert", style: "highlight", title: "", list: true, marker: "plain", items: [] }, o);
  const button = (id, label, destination) => ({ id, type: "button", label, destination });
  const sec = (destination) => "section:" + destination;

  const sections = [];

  // Home
  const home = [];
  if (c.objectives.length) home.push(alert("home-objectives", { style: "highlight", title: "Objectives", marker: "check", items: c.objectives }));
  const rule = reflections > 0 ? " (submitting " + reflections + " reflections is required to complete)." : ", but this is optional.";
  home.push(content("home-como-funciona", { title: "How this case study works", items: [
    "You start with a base case and decide what the group should do before seeing the recommended flow.",
    "Then you explore variations of the same case, in any order you like. For each one, think before revealing the analysis.",
    "In each variation, notice what changes and what stays the same. The central idea emerges when you compare them all.",
    "At the end of each analysis there is a reflective question. You can write and submit your reflection" + rule,
    "The activity is complete once you have revealed the analysis of the " + required + " variations.",
  ] }));
  home.push(button("home-button", "Start with the base case", sec("baseCase")));
  sections.push({ id: "home", title: "Welcome", menuLabel: "Home", intro: c.subtitle, blocks: home });

  // Base case
  const after = (c.caseSupport || []).map((b, i) => content("baseCase-support-" + (i + 1), { title: b.title, marker: i > 0 ? "check" : "plain", items: b.items || [] }));
  after.push(button("baseCase-button", "Go to: " + T.flowTitle, sec("flow")));
  sections.push({ id: "baseCase", title: "Base case", menuLabel: "1. Base case",
    intro: "Read the case carefully. It is the starting point for all the variations.",
    blocks: [
      content("baseCase-text", { style: "highlight", items: c.baseCase }),
      content("baseCase-question", { title: "Trigger question", style: "question", list: false, items: [c.triggerQuestion] }),
      { id: "baseCase-quiz", type: "quiz", title: "Your reasoning", prompt: c.quiz.prompt, options: c.quiz.options,
        verifyLabel: "Check answers",
        successMessage: "Well done: your answer matches the recommended flow.",
        reviewMessage: "Some points deserve another look. See the comments on the options.",
        countsForCompletion: false },
      { id: "baseCase-after", type: "reveal", trigger: "quiz:baseCase-quiz", label: "", blocks: after },
    ] });

  // Flow
  const flow = [{ id: "flow-steps", type: "accordion", title: "", numbered: true,
    items: c.flow.map(e => ({ title: e.title, items: e.items })) }];
  if (c.donts.length) flow.push(alert("flow-not-do", { style: "error", title: T.dontsTitle, marker: "cross", items: c.donts }));
  flow.push(button("flow-button", "Explore the variations", sec("variations")));
  sections.push({ id: "flow", title: T.flowTitle, menuLabel: "2. Basic flow", intro: T.flowIntro, blocks: flow });

  // Variations
  sections.push({ id: "variations", title: "Variations map", menuLabel: "3. Variations",
    intro: "What if the case were different? Pick a variation, think about what changes and what stays the same, and only then reveal the analysis.",
    blocks: [{ id: "variations-map", type: "map", intro: "", labelOnComplete: "Go to the synthesis", destinationOnComplete: sec("synthesis") }] });

  // Synthesis
  const synthesis = [
    { id: "synthesis-progress", type: "progress", buttonLabel: "Back to the variations", destination: sec("variations") },
    content("synthesis-question", { title: "Before seeing the table", style: "question", list: false, items: [T.synthesisQuestion] }),
    { id: "synthesis-idea", type: "reveal", trigger: "button", label: "Show the central idea", blocks: [
      { id: "synthesis-idea-columns", type: "columns", columns: (T.centralIdea || []).map(i => (
        { title: i.title, list: false, marker: "plain", items: i.text ? [i.text] : [] })) },
    ] },
    { id: "synthesis-table", type: "table", title: "All variations side by side" },
  ];
  if (c.principles.length) synthesis.push(content("synthesis-principles", { title: T.principlesTitle, marker: "check", items: c.principles }));
  if (c.takeaways.length) synthesis.push(alert("synthesis-take", { style: "highlight", title: T.takeawaysTitle, marker: "check", items: c.takeaways }));
  sections.push({ id: "synthesis", title: "Synthesis", menuLabel: "4. Synthesis", intro: "", blocks: synthesis });

  // References
  sections.push({ id: "references", title: "References", menuLabel: "", intro: "", blocks: [
    content("references-list", { items: c.references.length ? c.references : ["No references listed."] }),
  ] });

  // Free-form sections written by the author replace the generated ones.
  const finalSections = Array.isArray(p.customSections) ? p.customSections : sections;
  const flat = bs => bs.flatMap(b => [b].concat(b.type === "reveal" ? flat(b.blocks || []) : []));
  const hasMap = finalSections.some(s => flat(s.blocks || []).some(b => b.type === "map"));

  return {
    schemaVersion: 2,
    template: p.template || "case-study",
    label: c.label, title: c.title, subtitle: c.subtitle,
    sections: finalSections,
    variations: {
      reflectionNotice: c.reflectionNotice,
      reflectionMinimum: config.reflectionMin > 0 ? config.reflectionMin : 10,
      reflectionMaximum: config.reflectionMax > 0 ? config.reflectionMax : 500,
      themes: c.themes, variations: c.variations,
    },
    completion: {
      requireAllSections: false,
      requireVariations: c.variations.length > 0 && hasMap,
      requiredVariations: config.requiredVariations || 0,
      requireQuizzes: false,
      requiredReflections: config.requiredReflections || 0,
    },
  };
}

// Consistency check (mirrors Structure's consistency problems).
function problems(e) {
  const out = [];
  const flatten = (bs) => bs.flatMap(b => b.type === "reveal" ? [b].concat(flatten(b.blocks)) : [b]);
  const ids = e.sections.map(s => s.id);
  if (new Set(ids).size !== ids.length) out.push("sections with duplicate id");
  const blocks = e.sections.flatMap(s => flatten(s.blocks));
  const idsB = blocks.map(b => b.id);
  if (new Set(idsB).size !== idsB.length) out.push("blocks with duplicate id");
  const quizzes = new Set(blocks.filter(b => b.type === "quiz").map(b => b.id));
  const target = (d, location) => { if (d.startsWith("section:") && !ids.includes(d.slice(8))) out.push(location + " points to a section that does not exist: " + d); };
  blocks.forEach(b => {
    if (b.type === "button") target(b.destination, "button " + b.id);
    if (b.type === "map") target(b.destinationOnComplete, "mapa " + b.id);
    if (b.type === "progress") target(b.destination, "progress " + b.id);
    if (b.type === "reveal" && b.trigger.startsWith("quiz:") && !quizzes.has(b.trigger.slice(5))) out.push("revelar " + b.id + " espera quiz inexistente");
    if ((b.type === "map" || b.type === "table") && !e.variations.variations.length) out.push(b.type + " without variations");
  });
  return out;
}

module.exports = { convert, problems };

if (require.main === module) {
  const [, , entry, output] = process.argv;
  const e = convert(JSON.parse(fs.readFileSync(entry, "utf8")));
  const ps = problems(e);
  if (ps.length) { console.error("Problemas:\n- " + ps.join("\n- ")); process.exit(1); }
  const json = JSON.stringify(e, null, 2) + "\n";
  if (output) fs.writeFileSync(output, json); else process.stdout.write(json);
  console.error("ok:", e.sections.length, "sections,", e.sections.reduce((n, s) => n + s.blocks.length, 0), "top-level blocks");
}
