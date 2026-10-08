//
//  ProjectBuilder.swift
//  gilwellSCROM
//
//  Start wizard rules, without UI: turns the author's answers into a project.
//

import Foundation

nonisolated struct WizardDraft: Equatable, Sendable {
    enum StartingPoint: Sendable { case blank, example }

    var templateID: String?
    var label = ""
    var title = ""
    var subtitle = ""
    var startingPoint: StartingPoint = .blank

    /// Completion: all variations or only some.
    var requireAllVariations = true
    var requiredVariations = 5
    /// Reflections the learner must submit; 0 = reflection is optional.
    var requiredReflections = 0
}

nonisolated enum ProjectBuilder {

    static func create(_ draft: WizardDraft) throws -> Project {
        guard let id = draft.templateID, let template = Templates.find(id) else {
            throw ExportError.unknownTemplate(draft.templateID ?? "")
        }

        var project: Project
        switch draft.startingPoint {
        case .blank:
            project = Project.created(template: template.id)
        case .example:
            guard let path = template.examplePath else { throw ExportError.missingResource(template.name) }
            project = try JSONDecoder().decode(Project.self, from: try RuntimeAssets.data(from: path))
            project.template = template.id
        }

        // Only overwrites what the author actually filled in.
        func filled(_ text: String) -> String? {
            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : cleaned
        }
        if let t = filled(draft.label) { project.content.label = t }
        if let t = filled(draft.title) { project.content.title = t }
        if let t = filled(draft.subtitle) { project.content.subtitle = t }

        project.config.requiredVariations = draft.requireAllVariations ? 0 : max(1, draft.requiredVariations)
        project.config.requiredReflections = max(0, draft.requiredReflections)
        return project
    }
}
