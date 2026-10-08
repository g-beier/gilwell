//
//  Validator.swift
//  gilwellSCROM
//
//  Checks run before exporting. Errors block the export; warnings only notify.
//

import Foundation

nonisolated struct Finding: Identifiable, Hashable, Sendable {
    enum Level: Sendable { case error, notice }
    let id = UUID()
    let level: Level
    let text: String
}

nonisolated enum Validator {

    static func validate(_ project: Project) -> [Finding] {
        var findings: [Finding] = []
        func error(_ t: String) { findings.append(Finding(level: .error, text: t)) }
        func notice(_ t: String) { findings.append(Finding(level: .notice, text: t)) }

        let c = project.content

        if empty(c.title) { error("The case study title is empty (General).") }
        if c.variations.isEmpty { error("The project has no variations.") }
        if c.themes.isEmpty && !c.variations.isEmpty { error("Create at least one theme under “Themes” to group the variations.") }

        // Variations
        let numbers = c.variations.map(\.number)
        let duplicates = Dictionary(grouping: numbers, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
        for n in duplicates { error("Number \(n) is used by more than one variation. Each variation needs a unique number.") }

        let themeIDs = Set(c.themes.map(\.id))
        for v in c.variations {
            let name = "Variation \(v.number)"
            if !themeIDs.contains(v.theme) { error("\(name) points to a theme that does not exist.") }
            if empty(v.title) { error("\(name) has no title.") }
            if empty(v.whatIf) { notice("\(name) is missing the “What if...?” question.") }
            if v.changes.allSatisfy(empty) { notice("\(name) has no items in “What changes”.") }
            if v.staysSame.allSatisfy(empty) { notice("\(name) has no items in “What stays the same”.") }
            if empty(v.synthesis) { notice("\(name) is missing the one-line synthesis.") }
            if empty(v.question) { notice("\(name) is missing the reflection question.") }
        }

        for g in c.themes where !c.variations.contains(where: { $0.theme == g.id }) {
            notice("The theme “\(g.title)” has no variations and does not appear on the map.")
        }

        if let sections = project.customSections {
            // Free-form structure: check the sections and blocks the author built.
            if sections.isEmpty { error("The project has no sections. Add one under “Sections”.") }
            for section in sections where empty(section.title) {
                error("A section has no title (Sections).")
            }
            for problem in project.structure.consistencyProblems() { error(problem) }
            for block in project.structure.allBlocks {
                if case .quiz(let q) = block.data {
                    if q.options.count < 2 { notice("A quiz has fewer than two options.") }
                    if !q.options.contains(where: \.correct) { notice("A quiz has no option marked as correct.") }
                }
            }
        } else {
            // Quiz
            if c.quiz.options.count < 2 { notice("The base case quiz has fewer than two options.") }
            if !c.quiz.options.contains(where: \.correct) { notice("No quiz option is marked as correct.") }
            if c.quiz.options.contains(where: { empty($0.text) }) { notice("Some quiz options have no text.") }

            // Flow, case
            if c.flow.isEmpty { notice("The flow has no steps.") }
            if c.baseCase.allSatisfy(empty) { notice("The base case is empty.") }
        }

        // Completion
        let total = c.variations.count
        if project.config.requiredVariations > total {
            notice("Completion requires \(project.config.requiredVariations) variations, but there are \(total). The app will use \(total).")
        }
        if project.config.requiredReflections > total {
            notice("Completion requires \(project.config.requiredReflections) reflections, but there are only \(total) variations. The app will use \(total).")
        }
        if project.config.reflectionMax < project.config.reflectionMin {
            error("The maximum reflection length is smaller than the minimum (Settings).")
        }

        // “Variation N” references in texts that point to a variation that does not exist.
        let existing = Set(numbers)
        var cited = Set<Int>()
        for text in allTexts(c) {
            cited.formUnion(citedNumbers(in: text))
        }
        for n in cited.sorted() where !existing.contains(n) {
            notice("Some text cites “Variation \(n)”, which does not exist. The link will not be created.")
        }

        return findings
    }

    static func hasErrors(_ findings: [Finding]) -> Bool {
        findings.contains(where: { $0.level == .error })
    }

    // MARK: - Helpers

    private static func empty(_ s: String) -> Bool {
        s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func allTexts(_ c: ProjectContent) -> [String] {
        var t: [String] = []
        t += c.objectives + c.baseCase + c.donts + c.principles + c.takeaways + c.references
        t += c.caseSupport.flatMap(\.items)
        t += c.flow.flatMap(\.items)
        for v in c.variations {
            t += v.changes + v.staysSame + [v.synthesis, v.question, v.whatIf]
            t += v.extra.flatMap(\.items)
        }
        return t
    }

    /// Numbers in mentions such as “Variation 12”.
    static func citedNumbers(in text: String) -> [Int] {
        guard let regex = try? NSRegularExpression(pattern: "Variation (\\d+)") else { return [] }
        let interval = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: interval).compactMap { m in
            guard m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: text) else { return nil }
            return Int(text[r])
        }
    }
}
