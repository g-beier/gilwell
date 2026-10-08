/* Package runtime: renders the sections and blocks described in STRUCTURE (js/data.js),
   saves the learner's progress in SCORM and computes completion. */
(function () {
  "use strict";

  var E = STRUCTURE;
  var SECTIONS = E.sections || [];
  var DV = E.variations || {};
  var VARIATIONS = DV.variations || [];
  var THEMES = DV.themes || [];
  var TOTAL = VARIATIONS.length;
  var CR = E.completion || {};
  var MIN_REFLECTION = DV.reflectionMinimum > 0 ? DV.reflectionMinimum : 10;
  var MAX_REFLECTION = DV.reflectionMaximum > 0 ? DV.reflectionMaximum : 500;   // split into 250-character parts when saved (SCORM 1.2 limit)

  /* ---------- blocks and sections ---------- */
  function flatten(blocks) {
    var out = [];
    (blocks || []).forEach(function (b) {
      out.push(b);
      if (b.type === "reveal") out = out.concat(flatten(b.blocks));
    });
    return out;
  }
  var ALL_BLOCKS = [];
  SECTIONS.forEach(function (s) { ALL_BLOCKS = ALL_BLOCKS.concat(flatten(s.blocks)); });
  var QUIZZES = ALL_BLOCKS.filter(function (b) { return b.type === "quiz"; });
  var REFLECTIONS = ALL_BLOCKS.filter(function (b) { return b.type === "reflection"; });

  function sectionByID(id) {
    for (var i = 0; i < SECTIONS.length; i++) if (SECTIONS[i].id === id) return SECTIONS[i];
    return null;
  }
  function indexSection(id) {
    for (var i = 0; i < SECTIONS.length; i++) if (SECTIONS[i].id === id) return i;
    return -1;
  }
  function hasMap(sec) {
    return (sec.blocks || []).some(function (b) { return b.type === "map"; });
  }
  function sectionMap() {
    for (var i = 0; i < SECTIONS.length; i++) if (hasMap(SECTIONS[i])) return SECTIONS[i];
    return null;
  }
  /* "next" = the section after the current one; "section:ID" = that section. Returns the id or null. */
  function resolveDestination(destination, currentID) {
    if (typeof destination === "string" && destination.indexOf("section:") === 0) {
      var id = destination.slice(8);
      return sectionByID(id) ? id : null;
    }
    var i = indexSection(currentID);
    return (i >= 0 && i < SECTIONS.length - 1) ? SECTIONS[i + 1].id : null;
  }

  /* ---------- completion rules ---------- */
  var REQ_VARIATIONS = (CR.requireVariations && TOTAL > 0)
    ? (CR.requiredVariations > 0 ? Math.min(CR.requiredVariations, TOTAL) : TOTAL) : 0;
  var VARIATIONS_WITH_REFLECTION = VARIATIONS.filter(function (v) { return v.question; }).length;
  var REQ_REFLECTIONS = CR.requiredReflections > 0 ? Math.min(CR.requiredReflections, VARIATIONS_WITH_REFLECTION + REFLECTIONS.length) : 0;
  var REQ_QUIZZES = CR.requireQuizzes
    ? QUIZZES.filter(function (b) { return b.countsForCompletion; }).map(function (b) { return b.id; }) : [];
  var REQ_SECTIONS = !!CR.requireAllSections || (!REQ_VARIATIONS && !REQ_REFLECTIONS && !REQ_QUIZZES.length);

  var state = {
    seen: [],       // ids of the sections already opened
    visited: [],      // ids of the variations already revealed
    refl: [],         // ids of the variations whose reflection was already sent
    reflB: [],        // ids of the reflection blocks already sent
    quiz: {},         // quiz id → 1 (checked with errors) or 2 (checked, all correct)
    ok: [],           // ids of the quizzes already answered correctly
    rev: [],          // ids of the “Reveal” blocks (button-triggered) already open
    view: SECTIONS.length ? SECTIONS[0].id : "",
    openVar: null,    // id of the open variation (or null = map)
    cameFrom: null,     // id of the variation from which the learner followed a “Variation N” link
    completed: false
  };

  /* ---------- utilities ---------- */
  function esc(s) {
    return String(s === undefined || s === null ? "" : s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }
  function $(id) { return document.getElementById(id); }
  function has(arr, x) { return arr.indexOf(x) !== -1; }
  function add(arr, x) { if (!has(arr, x)) arr.push(x); }
  function variationByID(id) {
    for (var i = 0; i < VARIATIONS.length; i++) if (VARIATIONS[i].id === id) return VARIATIONS[i];
    return null;
  }
  function hasSeen(id) { return has(state.visited, id); }
  function hasSent(id) { return has(state.refl, id); }
  /* Turns mentions such as “Variation 1” into links to that variation. */
  function link(html) {
    return html.replace(/Variation (\d+)/g, function (m, n) {
      return variationByID(parseInt(n, 10))
        ? '<a href="#variation-' + n + '" class="ref-variation" data-ref="' + n + '">' + m + "</a>"
        : m;
    });
  }
  function list(items, cls) {
    return '<ul class="list ' + (cls || "") + '">' +
      (items || []).map(function (t) { return "<li>" + link(esc(t)) + "</li>"; }).join("") + "</ul>";
  }
  function paragraphs(items, cls) {
    return (items || []).map(function (t) {
      return '<p' + (cls ? ' class="' + cls + '"' : "") + ">" + link(esc(t)) + "</p>";
    }).join("");
  }
  function markerCls(m) { return m === "check" ? "check" : (m === "cross" ? "cross" : ""); }
  function body(b, clsParagraph) {
    return b.list ? list(b.items, markerCls(b.marker)) : paragraphs(b.items, clsParagraph);
  }
  function makeElement(html, cssClass) {
    var d = document.createElement("div");
    d.className = "block" + (cssClass ? " " + cssClass : "");
    d.innerHTML = html;
    return d;
  }

  /* ---------- SCORM ---------- */
  function filterIds(arr, valid) {
    return (arr instanceof Array) ? arr.filter(valid) : [];
  }
  function save() {
    var data = JSON.stringify({
      s: state.seen, v: state.visited, r: state.refl, b: state.reflB,
      q: state.quiz, k: state.ok, e: state.rev, w: state.view
    });
    Scorm.set("cmi.core.lesson_location", state.view);
    Scorm.set("cmi.suspend_data", data);
    Scorm.commit();
  }

  function load() {
    var raw = Scorm.get("cmi.suspend_data");
    if (raw) {
      try {
        var d = JSON.parse(raw);
        var blockIDs = ALL_BLOCKS.map(function (b) { return b.id; });
        var quizIDs = QUIZZES.map(function (b) { return b.id; });
        var reflectionIDs = REFLECTIONS.map(function (b) { return b.id; });
        state.seen = filterIds(d.s, function (id) { return !!sectionByID(id); });
        state.visited = filterIds(d.v, function (id) { return !!variationByID(id); });
        state.refl = filterIds(d.r, function (id) { return !!variationByID(id); });
        state.reflB = filterIds(d.b, function (id) { return has(reflectionIDs, id); });
        state.ok = filterIds(d.k, function (id) { return has(quizIDs, id); });
        state.rev = filterIds(d.e, function (id) { return has(blockIDs, id); });
        if (d.q && typeof d.q === "object") {
          quizIDs.forEach(function (id) { if (d.q[id] === 1 || d.q[id] === 2) state.quiz[id] = d.q[id]; });
        }
        if (d.w && sectionByID(d.w)) state.view = d.w;
      } catch (e) { /* ignore corrupted data */ }
    }
    var status = Scorm.get("cmi.core.lesson_status");
    state.completed = (status === "completed" || status === "passed");
    if (!status || status === "not attempted") {
      Scorm.set("cmi.core.lesson_status", "incomplete");
    }
  }

  function criteriaMet() {
    if (REQ_VARIATIONS && state.visited.length < REQ_VARIATIONS) return false;
    if (REQ_REFLECTIONS && (state.refl.length + state.reflB.length) < REQ_REFLECTIONS) return false;
    for (var i = 0; i < REQ_QUIZZES.length; i++) if (!has(state.ok, REQ_QUIZZES[i])) return false;
    if (REQ_SECTIONS && state.seen.length < SECTIONS.length) return false;
    return true;
  }

  function checkCompletion() {
    if (!state.completed && criteriaMet()) {
      state.completed = true;
      Scorm.set("cmi.core.lesson_status", "completed");
    }
  }

  /* ---------- progress ---------- */
  function updateProgress() {
    var byVariations = REQ_VARIATIONS > 0;
    var n = byVariations ? state.visited.length : state.seen.length;
    var total = byVariations ? TOTAL : SECTIONS.length;
    $("prog-num").textContent = n;
    $("prog-total").textContent = total;
    $("prog-label").textContent = byVariations ? "variations explored" : "sections visited";
    var pct = total ? Math.min(100, Math.round((n / total) * 100)) : 0;
    $("prog-fill").style.width = pct + "%";
    $("prog-bar").setAttribute("aria-valuenow", pct);
    $("menu-num").textContent = n;
    $("menu-total").textContent = total;
    $("mini-fill").style.width = pct + "%";
  }

  /* ---------- navigation ---------- */
  function buildMenu() {
    var ul = $("menu-list");
    ul.innerHTML = "";
    SECTIONS.forEach(function (s) {
      var li = document.createElement("li");
      var b = document.createElement("button");
      b.type = "button";
      b.textContent = s.menuLabel || s.title;
      b.setAttribute("data-view", s.id);
      b.addEventListener("click", function () { goTo(s.id); });
      li.appendChild(b);
      ul.appendChild(li);
    });
  }

  /* Opens a section from a button or the menu. Arriving at a section with the map shows the map, not a variation. */
  function goTo(id) {
    var sec = sectionByID(id);
    if (!sec) return;
    state.cameFrom = null;
    if (hasMap(sec)) state.openVar = null;
    show(id);
  }

  function show(id, withoutFocus) {
    state.view = id;
    add(state.seen, id);
    SECTIONS.forEach(function (s) { $("v-" + s.id).hidden = (s.id !== id); });
    var buttons = document.querySelectorAll("#menu-list button");
    for (var i = 0; i < buttons.length; i++) {
      if (buttons[i].getAttribute("data-view") === id) {
        buttons[i].setAttribute("aria-current", "page");
        // On narrow windows the menu scrolls horizontally: center the current step (without touching the page scroll).
        var ul = buttons[i].parentNode.parentNode;
        ul.scrollLeft = buttons[i].parentNode.offsetLeft - (ul.clientWidth - buttons[i].offsetWidth) / 2;
      } else {
        buttons[i].removeAttribute("aria-current");
      }
    }
    renderSection(sectionByID(id));
    checkCompletion();
    updateProgress();
    if (!withoutFocus) {
      scrollToTop();
      $("content").focus({ preventScroll: true });
    }
    save();
  }

  function renderSection(sec) {
    var root = $("v-" + sec.id);
    root.innerHTML = "";
    if (state.openVar !== null && hasMap(sec)) {
      renderDetail(sec, root, state.openVar);
      return;
    }
    var h = document.createElement("h2");
    h.textContent = sec.title;
    root.appendChild(h);
    if (sec.intro) {
      var p = document.createElement("p");
      p.className = "lead";
      p.innerHTML = link(esc(sec.intro));
      root.appendChild(p);
    }
    renderBlocks(sec.blocks, root, sec);
  }

  function reopenCurrentSection() {
    renderSection(sectionByID(state.view));
  }

  function openVariation(id, cameFrom) {
    state.cameFrom = cameFrom === undefined ? null : cameFrom;
    state.openVar = id;
    var sec = sectionMap();
    if (!sec) return;
    if (state.view === sec.id) {
      renderSection(sec);
      scrollToTop();
      $("content").focus({ preventScroll: true });
    } else {
      show(sec.id);
    }
  }

  /* ---------- blocks ---------- */
  function renderBlocks(blocks, parent, sec) {
    (blocks || []).forEach(function (b) {
      var fn = RENDER[b.type];
      if (!fn) return;
      parent.appendChild(fn(b, sec));
    });
  }

  var RENDER = {};

  RENDER.content = function (b) {
    var cls = "card" + (b.style === "highlight" ? " highlight" : (b.style === "question" ? " question" : ""));
    return makeElement('<div class="' + cls + '">' +
      (b.title ? "<h3>" + esc(b.title) + "</h3>" : "") +
      body(b, b.style === "question" ? "question-text" : "") + "</div>");
  };

  RENDER.alert = function (b) {
    var cls = "card " + (b.style === "error" ? "alert" : (b.style === "warning" ? "warning" : "highlight"));
    return makeElement('<div class="' + cls + '">' +
      (b.title ? "<h3>" + esc(b.title) + "</h3>" : "") + body(b) + "</div>");
  };

  RENDER.accordion = function (b) {
    var html = b.title ? "<h3>" + esc(b.title) + "</h3>" : "";
    (b.items || []).forEach(function (it, i) {
      html += '<details class="step' + (b.numbered ? "" : " unnumbered") + '"><summary>' +
        (b.numbered ? '<span class="num">' + (i + 1) + "</span>" : "") + esc(it.title) + "</summary>" +
        '<div class="body">' + list(it.items) + "</div></details>";
    });
    return makeElement(html);
  };

  RENDER.columns = function (b) {
    var cols = b.columns || [];
    var html = '<div class="columns n' + cols.length + '">' + cols.map(function (c) {
      return '<div class="card">' + (c.title ? "<h3>" + esc(c.title) + "</h3>" : "") + body(c) + "</div>";
    }).join("") + "</div>";
    return makeElement(html);
  };

  RENDER.highlight = function (b) {
    return makeElement('<div class="synthesis-line">' + link(esc(b.text)) + "</div>");
  };

  RENDER.button = function (b, sec) {
    var target = resolveDestination(b.destination, sec.id);
    var el = makeElement('<div class="actions"><button class="btn" type="button">' + esc(b.label) + "</button></div>");
    var btn = el.querySelector("button");
    if (target) btn.setAttribute("data-go-to", target); else btn.disabled = true;
    return el;
  };

  RENDER.reveal = function (b, sec) {
    var el = makeElement("", "reveal");
    var content = document.createElement("div");
    content.className = "reveal-content";
    var isOpen = false;
    function open() {
      if (isOpen) return;
      isOpen = true;
      renderBlocks(b.blocks, content, sec);
      el.appendChild(content);
    }
    var trigger = b.trigger || "button";
    if (trigger.indexOf("quiz:") === 0) {
      var quizId = trigger.slice(5);
      el.setAttribute("data-reveal-quiz", quizId);
      el._open = open;
      if (state.quiz[quizId]) open();
    } else if (has(state.rev, b.id)) {
      open();
    } else {
      var actions = document.createElement("div");
      actions.className = "actions";
      actions.innerHTML = '<button class="btn" type="button">' + esc(b.label || "Show") + "</button>";
      el.appendChild(actions);
      actions.querySelector("button").addEventListener("click", function () {
        actions.parentNode.removeChild(actions);
        open();
        add(state.rev, b.id);
        save();
      });
    }
    return el;
  };

  RENDER.quiz = function (b) {
    var el = makeElement(
      '<div class="card">' +
      (b.title ? "<h3>" + esc(b.title) + "</h3>" : "") +
      (b.prompt ? "<p>" + link(esc(b.prompt)) + "</p>" : "") +
      '<div class="quiz-options"></div>' +
      '<div class="quiz-result" aria-live="polite"></div>' +
      '<div class="actions"><button class="btn quiz-check" type="button">' + esc(b.verifyLabel || "Check answers") + "</button>" +
      '<button class="btn sec quiz-retry" type="button" hidden>Try again</button></div></div>', "quiz");
    var box = el.querySelector(".quiz-options");
    var result = el.querySelector(".quiz-result");
    var check = el.querySelector(".quiz-check");
    var retry = el.querySelector(".quiz-retry");
    (b.options || []).forEach(function (o, i) {
      var lab = document.createElement("label");
      lab.className = "option";
      lab.innerHTML = '<input type="checkbox" data-i="' + i + '"> ' + esc(o.text) + '<span class="feedback" hidden></span>';
      box.appendChild(lab);
    });

    function message(correct) {
      return correct
        ? '<div class="result good">' + esc(b.successMessage) + "</div>"
        : '<div class="result partial">' + esc(b.reviewMessage) + "</div>";
    }

    // Quiz already checked on another visit: show the result and enable “Try again”.
    if (state.quiz[b.id]) {
      var legacyInputs = box.querySelectorAll("input");
      for (var k = 0; k < legacyInputs.length; k++) legacyInputs[k].disabled = true;
      result.innerHTML = message(state.quiz[b.id] === 2);
      check.hidden = true;
      retry.hidden = false;
    }

    check.addEventListener("click", function () {
      var inputs = box.querySelectorAll("input");
      var allCorrect = true;
      var anyChecked = false;
      for (var i = 0; i < inputs.length; i++) {
        var o = b.options[i];
        var checked = inputs[i].checked;
        if (checked) anyChecked = true;
        var lab = inputs[i].parentNode;
        var feedback = lab.querySelector(".feedback");
        lab.classList.remove("ok", "error");
        feedback.hidden = true;
        inputs[i].disabled = true;
        if (checked === o.correct) {
          if (o.correct) { lab.classList.add("ok"); feedback.textContent = o.feedback; feedback.hidden = false; }
        } else {
          allCorrect = false;
          lab.classList.add("error");
          feedback.textContent = (o.correct ? "You should have selected this one. " : "This one should not have been selected. ") + o.feedback;
          feedback.hidden = false;
        }
      }
      if (!anyChecked) {
        for (var j = 0; j < inputs.length; j++) {
          inputs[j].disabled = false;
          inputs[j].parentNode.classList.remove("error");
          inputs[j].parentNode.querySelector(".feedback").hidden = true;
        }
        result.innerHTML = '<div class="result partial">Select at least one option before checking.</div>';
        return;
      }
      state.quiz[b.id] = allCorrect ? 2 : 1;
      if (allCorrect) add(state.ok, b.id);
      check.hidden = true;
      retry.hidden = false;
      result.innerHTML = message(allCorrect);
      unlockReveals(b.id);
      checkCompletion();
      updateProgress();
      save();
    });

    retry.addEventListener("click", function () {
      delete state.quiz[b.id];
      save();
      reopenCurrentSection();
    });
    return el;
  };

  /* Opens the “Reveal” blocks that were waiting for this quiz. */
  function unlockReveals(quizId) {
    var els = document.querySelectorAll("[data-reveal-quiz]");
    for (var i = 0; i < els.length; i++) {
      if (els[i].getAttribute("data-reveal-quiz") === quizId && els[i]._open) els[i]._open();
    }
  }

  /* Reflection field. On submit, saves to Moodle (Interactions report) and locks the field.
     o: { ids, titulo, pergunta, aviso, obrigatoria, enviada, interacao, aoEnviar } */
  function buildReflection(o) {
    var html =
      '<div class="card question"><h3>' + esc(o.title) + "</h3>" +
      '<p style="font-weight:600">' + link(esc(o.question)) + "</p>";
    if (o.sent) {
      html += '<p class="sent">✓ Reflection sent. Thank you for sharing.</p>';
    } else {
      html +=
        '<label class="note" style="display:block;margin-bottom:6px"' + (o.ids ? ' for="reflection"' : "") + ">Write your reflection" +
        (o.required ? "" : " (optional)") + ".</label>" +
        '<textarea class="reflection-text"' + (o.ids ? ' id="reflection"' : "") + ' maxlength="' + MAX_REFLECTION + '" rows="4"></textarea>' +
        '<p class="note reflection-count" aria-live="polite">0/' + MAX_REFLECTION + "</p>" +
        (o.notice ? '<p class="note reflection-notice">' + esc(o.notice) + "</p>" : "") +
        '<div class="actions"><button class="btn reflection-submit" type="button"' + (o.ids ? ' id="btn-send-reflection"' : "") + ' disabled>Send reflection</button></div>' +
        '<div class="reflection-status" role="status" aria-live="polite"' + (o.ids ? ' id="reflection-status"' : "") + "></div>";
    }
    html += "</div>";
    var el = makeElement(html, "reflection");
    if (o.sent) return el;

    var ta = el.querySelector("textarea");
    var btn = el.querySelector(".reflection-submit");
    var status = el.querySelector(".reflection-status");
    ta.addEventListener("input", function () {
      el.querySelector(".reflection-count").textContent = ta.value.length + "/" + MAX_REFLECTION;
      btn.disabled = ta.value.replace(/\s+/g, " ").replace(/^ | $/g, "").length < MIN_REFLECTION;
    });
    btn.addEventListener("click", function () {
      var ok = Scorm.recordAnswer(o.interaction, ta.value);
      if (!ok) {
        status.innerHTML = '<div class="result partial">Could not send right now. Your text is still on screen: please try again.</div>';
        return;
      }
      o.onSubmit();
      checkCompletion();
      updateProgress();
      save();
      ta.readOnly = true;
      btn.hidden = true;
      status.innerHTML = '<p class="sent">✓ Reflection sent. Thank you for sharing.</p>';
    });
    return el;
  }

  RENDER.reflection = function (b) {
    return buildReflection({
      ids: false,
      title: "Reflection",
      question: b.question,
      notice: b.notice,
      required: REQ_REFLECTIONS > 0,
      sent: has(state.reflB, b.id),
      interaction: "reflection_" + b.id.replace(/[^A-Za-z0-9_-]/g, "_"),
      onSubmit: function () { add(state.reflB, b.id); }
    });
  };

  RENDER.progress = function (b, sec) {
    var target = resolveDestination(b.destination, sec.id);
    var html;
    if (state.completed) {
      html = '<div class="completion"><strong>Activity completed.</strong> You have met the completion criteria.</div>';
    } else {
      var parts = [];
      if (REQ_VARIATIONS) parts.push("explored " + state.visited.length + " of " + REQ_VARIATIONS + " required variations");
      if (REQ_REFLECTIONS) parts.push("sent " + (state.refl.length + state.reflB.length) + " of " + REQ_REFLECTIONS + " reflections");
      if (REQ_QUIZZES.length) {
        var correct = REQ_QUIZZES.filter(function (id) { return has(state.ok, id); }).length;
        parts.push("answered " + correct + " of " + REQ_QUIZZES.length + " quizzes correctly");
      }
      if (REQ_SECTIONS && !parts.length) parts.push("visited " + state.seen.length + " of " + SECTIONS.length + " sections");
      html = '<div class="card"><p style="margin:0">You ' + parts.join(", ") + "." +
        (target ? ' <button class="btn sec" type="button" data-go-to="' + esc(target) + '" style="margin-left:6px">' + esc(b.buttonLabel) + "</button>" : "") +
        "</p></div>";
    }
    return makeElement(html);
  };

  RENDER.table = function (b) {
    var html = (b.title ? "<h3>" + esc(b.title) + "</h3>" : "") +
      "<table><thead><tr><th>#</th><th>Variation</th><th>What it teaches</th></tr></thead><tbody>";
    VARIATIONS.forEach(function (v) {
      html += '<tr><td class="n">' + v.id + "</td><td><strong>" + esc(v.title) + "</strong><br><span style=\"color:var(--ink-soft)\">" +
        esc(v.whatIf) + '</span></td><td data-label="What it teaches">' + esc(v.synthesis) + "</td></tr>";
    });
    return makeElement(html + "</tbody></table>");
  };

  RENDER.map = function (b, sec) {
    var target = resolveDestination(b.destinationOnComplete, sec.id);
    var html = (b.intro ? '<p class="lead">' + link(esc(b.intro)) + "</p>" : "") +
      '<p class="note map-progress">You have explored ' + state.visited.length + " of " + TOTAL + ".</p>";
    THEMES.forEach(function (g) {
      html += '<h3 class="theme-title">' + esc(g.title) + '</h3><p class="theme-description">' + esc(g.description) + '</p><div class="grid">';
      VARIATIONS.filter(function (v) { return v.theme === g.id; }).forEach(function (v) {
        html += '<button type="button" class="variation-card' + (hasSeen(v.id) ? " seen" : "") + '" data-variation="' + v.id + '">' +
          '<span class="tag">Variation ' + v.id + '</span><span class="title">' + esc(v.title) + "</span>" +
          '<span class="whatIf">' + esc(v.whatIf) + "</span></button>";
      });
      html += "</div>";
    });
    if (target && state.visited.length >= (REQ_VARIATIONS || TOTAL)) {
      html += '<div class="completion" style="margin-top:22px">You explored the required variations.' +
        ' <button class="btn" type="button" data-go-to="' + esc(target) + '" style="margin-left:8px">' + esc(b.labelOnComplete) + "</button></div>";
    }
    var el = makeElement(html);
    var variationCards = el.querySelectorAll("[data-variation]");
    for (var i = 0; i < variationCards.length; i++) {
      variationCards[i].addEventListener("click", function (e) {
        openVariation(parseInt(e.currentTarget.getAttribute("data-variation"), 10), null);
      });
    }
    return el;
  };

  /* ---------- open variation ---------- */
  function analysisBlock(v) {
    var html =
      '<div class="two">' +
      '<div class="card col-changes"><h3><span class="icon">↻</span>What changes</h3>' + list(v.changes) + "</div>" +
      '<div class="card col-stays"><h3><span class="icon">⚓</span>What stays the same</h3>' + list(v.staysSame, "check") + "</div>" +
      "</div>";
    if (v.extra) {
      v.extra.forEach(function (m) {
        html += '<div class="card" style="margin-top:16px"><h3>' + esc(m.title) + "</h3>" + list(m.items) + "</div>";
      });
    }
    html += '<div class="synthesis-line">' + esc(v.synthesis) + "</div>";
    return html;
  }

  function attachVariationReflection(v) {
    if (!v.question) return;
    $("analysis").appendChild(buildReflection({
      ids: true,
      title: "Reflective question",
      question: v.question,
      notice: DV.reflectionNotice || "",
      required: REQ_REFLECTIONS > 0,
      sent: hasSent(v.id),
      interaction: "variation_" + (v.id < 10 ? "0" : "") + v.id + "_reflection",
      onSubmit: function () { add(state.refl, v.id); }
    }));
  }

  function renderDetail(sec, s, id) {
    var v = variationByID(id);
    if (!v) { state.openVar = null; renderSection(sec); return; }
    // Previous/next follow the map order: only within the same theme, not by numbering.
    var themeVariations = VARIATIONS.filter(function (x) { return x.theme === v.theme; });
    var idx = themeVariations.indexOf(v);
    var prev = idx > 0 ? themeVariations[idx - 1] : null;
    var next = idx < themeVariations.length - 1 ? themeVariations[idx + 1] : null;
    var theme = "";
    THEMES.forEach(function (g) { if (g.id === v.theme) theme = g.title; });
    var revealed = hasSeen(id);

    function navButton(target, arrow) {
      var rot = arrow === "prev" ? "← Previous" : "Next →";
      return '<button class="btn sec" type="button" data-go="' + target.id + '"><span class="nv-label">' + rot +
        ' · Variation ' + target.id + '</span><span class="nv-title">' + esc(target.title) + "</span></button>";
    }

    s.innerHTML =
      '<div class="actions back">' +
      (state.cameFrom && state.cameFrom !== id
        ? '<button class="btn" type="button" data-back="' + state.cameFrom + '">← Back to Variation ' + state.cameFrom + "</button>" : "") +
      '<button class="btn sec" type="button" id="btn-map">← Back to the map</button></div>' +
      '<div class="detail-header"><span class="tag">Variation ' + v.id + " · " + esc(v.title) + "</span>" +
      '<p class="note" style="margin:8px 0 0">Theme: ' + esc(theme) + " · " + (idx + 1) + " of " + themeVariations.length + "</p>" +
      '<p class="whatif-large">' + esc(v.whatIf) + "</p></div>" +
      '<div class="card"><p style="margin:0"><strong>Starting point:</strong> the base case, with this single change.</p></div>' +
      '<div id="think" class="think"' + (revealed ? " hidden" : "") + ">" +
      "<h3>Think before seeing the analysis</h3>" +
      list([
        "What changes in this scenario?",
        "What must the group still do, exactly as in the base case?"
      ]) +
      '<div class="actions"><button class="btn" type="button" id="btn-reveal">Reveal the analysis</button></div></div>' +
      '<div id="analysis"' + (revealed ? "" : " hidden") + ">" + (revealed ? analysisBlock(v) : "") + "</div>" +
      '<div class="nav-variation">' +
      (prev ? navButton(prev, "prev") : "<span></span>") +
      (next ? navButton(next, "next")
            : '<button class="btn" type="button" id="btn-map-end"><span class="nv-label">End of this theme</span><span class="nv-title">Back to the Variations map</span></button>') +
      "</div>";

    function toMap() { state.cameFrom = null; state.openVar = null; renderSection(sec); scrollToTop(); }
    var back = s.querySelector("[data-back]");
    if (back) back.addEventListener("click", function (e) {
      state.openVar = parseInt(e.currentTarget.getAttribute("data-back"), 10);
      state.cameFrom = null;
      renderSection(sec);
      scrollToTop();
      $("content").focus({ preventScroll: true });
    });
    $("btn-map").addEventListener("click", toMap);
    var end = $("btn-map-end");
    if (end) end.addEventListener("click", toMap);
    var rev = $("btn-reveal");
    if (rev) rev.addEventListener("click", function () { reveal(v); });
    if (revealed) attachVariationReflection(v);
    var go = s.querySelectorAll("[data-go]");
    for (var i = 0; i < go.length; i++) {
      go[i].addEventListener("click", function (e) {
        state.cameFrom = null;
        state.openVar = parseInt(e.currentTarget.getAttribute("data-go"), 10);
        renderSection(sec);
        scrollToTop();
        $("content").focus({ preventScroll: true });
      });
    }
  }

  function reveal(v) {
    $("think").hidden = true;
    var a = $("analysis");
    a.innerHTML = analysisBlock(v);
    a.hidden = false;
    attachVariationReflection(v);
    if (!hasSeen(v.id)) {
      state.visited.push(v.id);
      checkCompletion();
      updateProgress();
      save();
    }
    // With the iframe at full height, scrolling belongs to the Moodle page; scrollIntoView scrolls both levels.
    a.scrollIntoView({ behavior: "smooth", block: "start" });
  }

  /* ---------- Automatic height inside the Moodle player ---------- */
  var frameAuto = null;   // player iframe, when accessible (same origin)

  function navbarParentHeight() {
    try {
      var doc = frameAuto.ownerDocument;
      var nav = doc.querySelector(".navbar.fixed-top, nav.fixed-top, .navbar-fixed-top");
      return nav ? nav.offsetHeight : 0;
    } catch (e) { return 0; }
  }

  function scrollToTop() {
    if (frameAuto) {
      try {
        var parent = frameAuto.ownerDocument.defaultView;
        var top = frameAuto.getBoundingClientRect().top - navbarParentHeight();
        if (top < 0) parent.scrollBy(0, top - 8);   // only scroll if the top of the content went off screen
        return;
      } catch (e) { /* falls through to the default below */ }
    }
    window.scrollTo(0, 0);
  }

  /* The Moodle theme sets #scorm_object to width: 98%, leaving an empty strip beside it.
     Since the package runs on the same origin, it fixes this to 100% itself (and reapplies if Moodle changes it). */
  function fixFrameWidth(frame) {
    function apply() {
      if (frame.style.getPropertyValue("width") !== "100%" || frame.style.getPropertyPriority("width") !== "important") {
        frame.style.setProperty("width", "100%", "important");
      }
    }
    try {
      apply();
      if (typeof MutationObserver !== "undefined") {
        new MutationObserver(apply).observe(frame, { attributes: true, attributeFilter: ["style", "width"] });
      }
    } catch (e) { /* no access to the iframe: the adjustment is left to Moodle's CSS */ }
  }

  function autoAdjustHeight() {
    var frame = null;
    try { frame = window.frameElement; } catch (e) { frame = null; }
    if (!frame) return false;
    var parent;
    try {
      parent = frame.ownerDocument.defaultView;
      void parent.document.body;        // throws if cross-origin
    } catch (e) { return false; }

    fixFrameWidth(frame);

    /* In a pop-up (window opened by Moodle, without the theme bar) the iframe already fills the window:
       internal scrolling is correct and automatic height could cut off the content. */
    var hasMoodleBar = !!frame.ownerDocument.querySelector("nav.navbar, .navbar");
    var openedByOtherWindow = false;
    try { openedByOtherWindow = !!(parent.top && parent.top.opener); } catch (e) {}
    if (!hasMoodleBar || openedByOtherWindow) return false;

    frameAuto = frame;
    document.documentElement.className += " auto-height";

    var last = 0;
    var applying = false;

    function measure() {
      return Math.ceil(document.body.getBoundingClientRect().height) + 2;
    }

    function unlockAncestors(h) {
      var p = frame.parentElement;
      var n = 0;
      while (p && p !== frame.ownerDocument.body && n < 8) {
        try {
          var cs = parent.getComputedStyle(p);
          var fixed = parseFloat(cs.height) || 0;
          var clip = cs.overflowY === "hidden" || cs.overflowY === "auto" || cs.overflowY === "scroll";
          if (clip || (fixed > 0 && fixed < h)) {
            p.style.setProperty("height", "auto", "important");
            p.style.setProperty("max-height", "none", "important");
            p.style.setProperty("overflow", "visible", "important");
          }
        } catch (e) {}
        p = p.parentElement;
        n++;
      }
    }

    function apply() {
      if (applying) return;
      applying = true;
      try {
        var h = measure();
        last = h;
        frame.style.setProperty("height", h + "px", "important");
        frame.style.setProperty("min-height", h + "px", "important");
        frame.setAttribute("height", h);
        unlockAncestors(h);
      } catch (e) {}
      applying = false;
    }

    apply();
    if (typeof ResizeObserver !== "undefined") {
      new ResizeObserver(function () { apply(); }).observe(document.body);
    } else {
      setInterval(apply, 500);
    }
    window.addEventListener("resize", apply);
    window.addEventListener("load", apply);

    // If Moodle reapplies its own height (when the window is resized), restore ours.
    if (typeof MutationObserver !== "undefined") {
      new MutationObserver(function () {
        if (!applying && frame.style.height !== last + "px") apply();
      }).observe(frame, { attributes: true, attributeFilter: ["style", "height"] });
    }
    return true;
  }

  /* ---------- start ---------- */
  function start() {
    Scorm.init();
    load();
    autoAdjustHeight();
    $("btn-top").addEventListener("click", scrollToTop);

    // One (initially hidden) section per project section.
    var main = $("content");
    SECTIONS.forEach(function (s) {
      var el = document.createElement("section");
      el.id = "v-" + s.id;
      el.className = "view";
      el.hidden = true;
      main.appendChild(el);
    });

    // Buttons with data-go-to (in any block, including ones that appear later) lead to the given section.
    document.addEventListener("click", function (e) {
      var el = e.target;
      while (el && el !== document && !(el.getAttribute && el.getAttribute("data-go-to"))) el = el.parentNode;
      if (!el || el === document) return;
      goTo(el.getAttribute("data-go-to"));
    });

    // “Variation N” links inside texts (valid in any section).
    document.addEventListener("click", function (e) {
      var el = e.target;
      while (el && el !== document && !(el.classList && el.classList.contains("ref-variation"))) el = el.parentNode;
      if (!el || el === document) return;
      e.preventDefault();
      var map = sectionMap();
      var origin = (map && state.view === map.id) ? state.openVar : null;
      openVariation(parseInt(el.getAttribute("data-ref"), 10), origin);
    });

    $("course-title").textContent = E.title;
    if (E.label) $("course-label").textContent = E.label;
    document.title = E.title;
    buildMenu();
    updateProgress();
    if (SECTIONS.length) show(sectionByID(state.view) ? state.view : SECTIONS[0].id, true);
    Scorm.commit();
  }

  window.addEventListener("beforeunload", function () { Scorm.finish(); });
  window.addEventListener("unload", function () { Scorm.finish(); });
  window.addEventListener("pagehide", function () { Scorm.finish(); });

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
  else start();
})();
