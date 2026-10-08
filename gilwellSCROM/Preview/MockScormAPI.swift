//
//  MockScormAPI.swift
//  gilwellSCROM
//
//  “Simulated Moodle”: a window.API object (SCORM 1.2) injected into the preview page.
//  Stores the values, applies the same limits as SCORM 1.2 and notifies the app on every change.
//

import Foundation

nonisolated enum MockScormAPI {

    /// JavaScript code injected at the start of the page. `initialState` is a JSON object with the values
    /// saved from the previous run (so the preview keeps progress when it reloads).
    static func font(initialState: String) -> String {
        "window.__GW_INIT = " + initialState + ";\n" + body
    }

    private static let body = #"""
    (function () {
      var store = window.__GW_INIT || {};
      if (!store["cmi.core.lesson_status"]) store["cmi.core.lesson_status"] = "not attempted";
      store["cmi.core.student_id"] = "preview";
      store["cmi.core.student_name"] = "Student, Preview";
      var alerts = [];
      var lastError = "0";
      var started = false;

      function notify() {
        try {
          window.webkit.messageHandlers.scorm.postMessage({ store: store, alerts: alerts, started: started });
        } catch (e) {}
      }
      function countInteractions() {
        var max = -1;
        for (var k in store) {
          var m = /^cmi\.interactions\.(\d+)\./.exec(k);
          if (m) max = Math.max(max, parseInt(m[1], 10));
        }
        return max + 1;
      }
      function alert(text) {
        if (alerts.indexOf(text) === -1) alerts.push(text);
      }

      window.API = {
        LMSInitialize: function () { started = true; lastError = "0"; notify(); return "true"; },
        LMSFinish: function () { lastError = "0"; notify(); return "true"; },
        LMSGetValue: function (k) {
          lastError = "0";
          if (k === "cmi.interactions._count") return String(countInteractions());
          return store[k] !== undefined ? String(store[k]) : "";
        },
        LMSSetValue: function (k, v) {
          v = String(v);
          if (k === "cmi.suspend_data" && v.length > 4096) {
            alert("suspend_data exceeded 4096 characters: Moodle may reject or truncate the progress.");
            lastError = "405"; notify(); return "false";
          }
          if (/\.student_response$/.test(k) && v.length > 255) {
            alert("An interaction answer exceeded 255 characters (SCORM 1.2 limit).");
            lastError = "405"; notify(); return "false";
          }
          store[k] = v;
          lastError = "0";
          notify();
          return "true";
        },
        LMSCommit: function () { notify(); return "true"; },
        LMSGetLastError: function () { return lastError; },
        LMSGetErrorString: function () { return lastError === "0" ? "No error" : "Error " + lastError; },
        LMSGetDiagnostic: function () { return ""; }
      };
    })();
    """#
}
