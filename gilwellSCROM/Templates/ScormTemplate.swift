//
//  ModeloDeScorm.swift
//  gilwellSCROM
//
//  A “template” is a kind of SCORM package the app knows how to build (currently: a case study with variations).
//  This is the descriptor of each template and the catalog used by the start wizard and the exporter.
//
//  To create a new template, see “How to add a template” in the README.
//

import Foundation

nonisolated struct ScormTemplate: Identifiable, Hashable, Sendable {
    /// Identifier stored in the .gilwell file (`template` field). Never change it once published.
    let id: String
    let name: String
    let summary: String
    /// Short phrases shown in the wizard (“what the learner finds”).
    let highlights: [String]
    /// Name of an SF Symbols symbol.
    let icon: String
    /// Folder (inside the app) with this template's package HTML/CSS/JS.
    let runtimeFolder: String
    /// Files copied as-is into the .zip, relative to `runtimeFolder`.
    let runtimeFiles: [String]
    /// Path (inside the app) of a complete example project; nil if the template has none.
    let examplePath: String?
    let exampleDescription: String
    /// Suggested file name when the project has no title yet.
    let defaultFileName: String
    /// Title used in the manifest when the project has no title yet.
    let defaultTitle: String
}

nonisolated enum Templates {

    static let caseStudy = ScormTemplate(
        id: "case-study",
        name: "Case study with variations",
        summary: "A base case with a quiz, a procedure flow and “What if…?” variations organized by theme.",
        highlights: [
            "Multiple-choice quiz with feedback",
            "Basic flow and “what not to do”",
            "Variations browsable by theme, with learner reflection",
            "Completion and reflections recorded in Moodle"
        ],
        icon: "text.book.closed",
        runtimeFolder: "CaseStudy/Runtime",
        runtimeFiles: [
            "index.html",
            "css/style.css",
            "js/scorm.js",
            "js/app.js",
            "fonts/poppins-400.woff2",
            "fonts/poppins-500.woff2",
            "fonts/poppins-600.woff2",
            "fonts/poppins-700.woff2",
            "fonts/krona-one-400.woff2",
            "fonts/LICENSE-Poppins-OFL.txt",
            "fonts/LICENSE-KronaOne-OFL.txt"
        ],
        examplePath: "CaseStudy/Example/case-study-ud4.gilwell",
        exampleDescription: "UD 4 case study (child and youth protection), with 13 variations",
        defaultFileName: "case-study",
        defaultTitle: "Case study"
    )

    /// All available templates, in the order they appear in the wizard.
    static let all: [ScormTemplate] = [caseStudy]

    static func find(_ id: String) -> ScormTemplate? {
        all.first(where: { $0.id == id })
    }
}
