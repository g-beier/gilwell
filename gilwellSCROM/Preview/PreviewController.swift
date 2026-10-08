//
//  PreviewController.swift
//  gilwellSCROM
//
//  Controls the preview's WKWebView: writes the package to a temporary folder, injects the simulated
//  Moodle and translates what the package records (status, progress, reflections) for the app's panel.
//

import SwiftUI
import WebKit
public import Combine

struct RecordedInteraction: Identifiable, Hashable {
    let id: Int
    let name: String
    let answer: String
}

/// Receives the page's messages without creating a retain cycle with the controller.
private final class MessageBridge: NSObject, WKScriptMessageHandler {
    weak var target: PreviewController?

    init(target: PreviewController) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.receive(message.body)
    }
}

final class PreviewController: NSObject, ObservableObject {
    @Published var status = "not attempted"
    @Published var variationsSeen = 0
    @Published var reflectionsSent = 0
    @Published var interactions: [RecordedInteraction] = []
    @Published var alerts: [String] = []
    @Published var error: String?
    @Published var sessionTime = ""

    let webView: WKWebView
    private var stored: [String: String] = [:]
    private var temporaryFolder: URL?

    override init() {
        let settings = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: settings)
        super.init()
        webView.isInspectable = true   // Safari > Develop > (this app) to debug the page
        settings.userContentController.add(MessageBridge(target: self), name: "scorm")
    }

    deinit {
        if let folder = temporaryFolder { try? FileManager.default.removeItem(at: folder) }
    }

    // MARK: - Loading

    /// Rebuilds the package with the current project and reloads the page, keeping the “learner's” progress.
    func load(_ project: Project) {
        do {
            let manager = FileManager.default
            if let legacy = temporaryFolder { try? manager.removeItem(at: legacy) }
            let folder = manager.temporaryDirectory
                .appendingPathComponent("gilwell-preview-\(UUID().uuidString)", isDirectory: true)
            try ScormBuilder.writeFolder(project, in: folder)
            temporaryFolder = folder

            let controller = webView.configuration.userContentController
            controller.removeAllUserScripts()
            let script = WKUserScript(source: MockScormAPI.font(initialState: stateJSON()),
                                      injectionTime: .atDocumentStart,
                                      forMainFrameOnly: true)
            controller.addUserScript(script)

            error = nil
            webView.loadFileURL(folder.appendingPathComponent("index.html"), allowingReadAccessTo: folder)
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Resets the simulated learner's progress and reloads.
    func reset(_ project: Project) {
        stored = [:]
        updateSummary()
        load(project)
    }

    private func stateJSON() -> String {
        guard
            let data = try? JSONSerialization.data(withJSONObject: stored, options: [.sortedKeys]),
            let text = String(data: data, encoding: .utf8)
        else { return "{}" }
        return text
    }

    // MARK: - Simulated Moodle messages

    func receive(_ body: Any) {
        guard let dictionary = body as? [String: Any] else { return }
        if let values = dictionary["store"] as? [String: Any] {
            var created: [String: String] = [:]
            for (key, value) in values { created[key] = "\(value)" }
            stored = created
        }
        alerts = dictionary["alerts"] as? [String] ?? []
        updateSummary()
    }

    private func updateSummary() {
        status = stored["cmi.core.lesson_status"] ?? "not attempted"
        sessionTime = stored["cmi.core.session_time"] ?? ""

        var seen = 0
        var sent = 0
        if
            let text = stored["cmi.suspend_data"],
            let data = text.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            seen = (obj["v"] as? [Any])?.count ?? 0
            sent = (obj["r"] as? [Any])?.count ?? 0
        }
        variationsSeen = seen
        reflectionsSent = sent

        // cmi.interactions.N.id / .student_response
        var answers: [Int: (name: String, answer: String)] = [:]
        for (key, value) in stored where key.hasPrefix("cmi.interactions.") {
            let parts = key.split(separator: ".")
            guard parts.count == 4, let index = Int(parts[2]) else { continue }
            var current = answers[index] ?? (name: "", answer: "")
            if parts[3] == "id" { current.name = value }
            if parts[3] == "student_response" { current.answer = value }
            answers[index] = current
        }
        interactions = answers.keys.sorted().map { RecordedInteraction(id: $0, name: answers[$0]!.name, answer: answers[$0]!.answer) }
    }

    /// Readable text for the SCORM status.
    var readableStatus: String {
        switch status {
        case "completed": return "Completed"
        case "passed": return "Passed"
        case "incomplete": return "In progress"
        case "failed": return "Failed"
        case "browsed": return "Navigated"
        default: return "Not started"
        }
    }
}

/// Bridge for using the controller's WKWebView inside SwiftUI.
struct WebViewContainer: NSViewRepresentable {
    let controller: PreviewController

    func makeNSView(context: Context) -> WKWebView {
        controller.webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
