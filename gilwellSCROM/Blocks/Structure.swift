//
//  Estrutura.swift
//  gilwellSCROM
//
//  The project seen as sections and blocks (format version 2). A section is a page of the learner's package;
//  blocks are what the author stacks inside it.
//

import Foundation

nonisolated struct ScormSection: Codable, Equatable, Sendable, Identifiable {
    /// Stable: button destination and key of the saved state. Does not change when the author renames the section.
    var id: String
    /// Page title.
    var title: String
    /// How the section appears in the learner's menu; empty = uses the title.
    var menuLabel: String = ""
    /// Opening sentence, below the title.
    var intro: String = ""
    var blocks: [Block] = []

    var effectiveLabel: String { menuLabel.isEmpty ? title : menuLabel }

    static func newID() -> String {
        "s-" + String(UUID().uuidString.lowercased().prefix(8))
    }
}

/// Themes and variations of the case study (the Map and Table blocks read from here).
nonisolated struct VariationData: Codable, Equatable, Sendable {
    var reflectionNotice: String = ""
    var reflectionMinimum: Int = 10
    var reflectionMaximum: Int = 500
    var themes: [Theme] = []
    var variations: [Variation] = []
}

/// Combinable criteria: the SCORM becomes “completed” when all enabled ones are met.
nonisolated struct CompletionCriteria: Codable, Equatable, Sendable {
    var requireAllSections: Bool = false
    var requireVariations: Bool = false
    /// How many variations to explore; 0 = all.
    var requiredVariations: Int = 0
    var requireQuizzes: Bool = false
    /// Reflections to submit; 0 = none.
    var requiredReflections: Int = 0
}

nonisolated struct Structure: Codable, Equatable, Sendable {
    var schemaVersion: Int = 2
    var template: String = "case-study"
    var label: String = ""
    var title: String = ""
    var subtitle: String = ""
    var sections: [ScormSection] = []
    var variations: VariationData = VariationData()
    var completion: CompletionCriteria = CompletionCriteria()

    /// All blocks, including those inside “Reveal”, in reading order.
    var allBlocks: [Block] {
        func flatten(_ blocks: [Block]) -> [Block] {
            blocks.flatMap { b -> [Block] in
                if case .reveal(let r) = b.data { return [b] + flatten(r.blocks) }
                return [b]
            }
        }
        return sections.flatMap { flatten($0.blocks) }
    }

    var hasVariations: Bool { !variations.variations.isEmpty }
}

// MARK: - Structure checks

extension Structure {

    /// Consistency problems (used by the validator and the tests).
    nonisolated func consistencyProblems() -> [String] {
        var problems: [String] = []
        let sectionIDs = sections.map(\.id)
        if Set(sectionIDs).count != sectionIDs.count { problems.append("Some sections share the same identifier.") }

        let blocks = allBlocks
        let blockIDs = blocks.map(\.id)
        if Set(blockIDs).count != blockIDs.count { problems.append("Some blocks share the same identifier.") }

        let quizIDs = Set(blocks.compactMap { b -> String? in
            if case .quiz = b.data { return b.id } else { return nil }
        })
        let sectionSet = Set(sectionIDs)

        func verify(_ destination: ButtonDestination, _ location: String) {
            if case .section(let id) = destination, !sectionSet.contains(id) {
                problems.append("\(location) points to a section that does not exist (\(id)).")
            }
        }
        for b in blocks {
            switch b.data {
            case .button(let d): verify(d.destination, "The button “\(d.label)”")
            case .map(let d): verify(d.destinationOnComplete, "The variations map")
            case .progress(let d): verify(d.destination, "The Progress block")
            case .reveal(let d):
                if case .quiz(let id) = d.trigger, !quizIDs.contains(id) {
                    problems.append("A “Reveal” block is waiting for quiz \(id), which does not exist.")
                }
            default: break
            }
            if b.type.requiresVariations && !hasVariations {
                problems.append("The “\(b.type.name)” block needs at least one variation.")
            }
        }
        return problems
    }
}
