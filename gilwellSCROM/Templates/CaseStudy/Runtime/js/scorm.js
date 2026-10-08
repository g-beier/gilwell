/* Minimal SCORM 1.2 wrapper, with a localStorage fallback for testing outside an LMS. */
var Scorm = (function () {
  var api = null;
  var connected = false;
  var finished = false;
  var LS_KEY = "scorm_case_study_protection";
  var fallback = {};
  var home = new Date();
  var countInteractions = 0;   // used when the LMS does not report cmi.interactions._count

  function two(n) { return (n < 10 ? "0" : "") + n; }

  /* This session's time in SCORM 1.2 format (HHHH:MM:SS). */
  function sessionTime() {
    var s = Math.max(0, Math.round((new Date() - home) / 1000));
    var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
    var h4 = (h < 10 ? "000" : h < 100 ? "00" : h < 1000 ? "0" : "") + h;
    return h4 + ":" + two(m) + ":" + two(s % 60);
  }

  function findAPI(win) {
    var tries = 0;
    while (win && !win.API && win.parent && win.parent !== win && tries < 20) {
      tries++;
      win = win.parent;
    }
    return win && win.API ? win.API : null;
  }

  function locateAPI() {
    var found = findAPI(window);
    if (!found && window.opener) {
      try { found = findAPI(window.opener); } catch (e) { found = null; }
    }
    return found;
  }

  function init() {
    api = locateAPI();
    if (api) {
      try {
        connected = String(api.LMSInitialize("")) === "true";
      } catch (e) {
        connected = false;
      }
    }
    if (!connected) {
      try {
        fallback = JSON.parse(localStorage.getItem(LS_KEY) || "{}");
      } catch (e) {
        fallback = {};
      }
    }
    return connected;
  }

  function get(key) {
    if (connected) {
      try { return String(api.LMSGetValue(key)); } catch (e) { return ""; }
    }
    return fallback[key] || "";
  }

  function set(key, value) {
    if (connected) {
      try { return String(api.LMSSetValue(key, String(value))) === "true"; } catch (e) { return false; }
    }
    fallback[key] = String(value);
    try { localStorage.setItem(LS_KEY, JSON.stringify(fallback)); } catch (e) {}
    return true;
  }

  function commit() {
    if (connected) {
      try { return String(api.LMSCommit("")) === "true"; } catch (e) { return false; }
    }
    return true;
  }

  /* Saves free text as a “fill-in” interaction (shown in Moodle's Interactions report).
     SCORM 1.2 limits each response to 255 characters: longer texts are split into parts. */
  function recordAnswer(id, text) {
    var cleaned = String(text).replace(/\s*[\r\n]+\s*/g, " / ").replace(/\s+/g, " ").replace(/^\s+|\s+$/g, "");
    if (!cleaned) return false;
    var parts = [];
    for (var i = 0; i < cleaned.length; i += 250) parts.push(cleaned.substring(i, i + 250));

    var n = parseInt(get("cmi.interactions._count"), 10);
    if (isNaN(n)) n = countInteractions;
    var now = new Date();
    var time = two(now.getHours()) + ":" + two(now.getMinutes()) + ":" + two(now.getSeconds());
    var ok = true;
    for (var p = 0; p < parts.length; p++) {
      var base = "cmi.interactions." + (n + p) + ".";
      ok = set(base + "id", parts.length > 1 ? id + "_p" + (p + 1) : id) && ok;
      ok = set(base + "type", "fill-in") && ok;
      ok = set(base + "student_response", parts[p]) && ok;
      ok = set(base + "result", "neutral") && ok;
      set(base + "time", time);
    }
    countInteractions = n + parts.length;
    commit();
    return ok;
  }

  function finish() {
    if (finished) return;
    finished = true;
    if (connected) {
      try {
        api.LMSSetValue("cmi.core.session_time", sessionTime());
        var st = String(api.LMSGetValue("cmi.core.lesson_status"));
        // “suspend” lets the learner resume where they left off; on completion, exit normally.
        api.LMSSetValue("cmi.core.exit", (st === "completed" || st === "passed") ? "" : "suspend");
      } catch (e) {}
      try {
        api.LMSCommit("");
        api.LMSFinish("");
      } catch (e) {}
    }
  }

  return {
    init: init,
    get: get,
    set: set,
    commit: commit,
    recordAnswer: recordAnswer,
    finish: finish,
    isConnected: function () { return connected; }
  };
})();
