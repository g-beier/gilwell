//
//  Project.swift
//  gilwellSCROM
//
//  Project data model.
//  Version 1 project format (fixed fields). Export converts it into sections and blocks.
//

import Foundation

// MARK: - Project

nonisolated struct Project: Codable, Equatable, Sendable {
    /// Version of the .gilwell file format. Increase it when changing the format in an incompatible way.
    var schemaVersion: Int = 1
    /// Template identifier (see `Templates`). Empty = new project that has not gone through the start wizard yet.
    var template: String = "case-study"
    var content: ProjectContent
    var texts: Texts
    var config: Config
    /// Sections and blocks edited freely by the author. `nil` = the structure is generated from the fixed fields above.
    var customSections: [ScormSection]?

    init(content: ProjectContent, texts: Texts = Texts(), config: Config = Config()) {
        self.content = content
        self.texts = texts
        self.config = config
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, template, content, texts, config, customSections
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        template = try c.decodeIfPresent(String.self, forKey: .template) ?? "case-study"
        content = try c.decode(ProjectContent.self, forKey: .content)
        texts = try c.decodeIfPresent(Texts.self, forKey: .texts) ?? Texts()
        config = try c.decodeIfPresent(Config.self, forKey: .config) ?? Config()
        customSections = try c.decodeIfPresent([ScormSection].self, forKey: .customSections)
    }

    /// Sections and blocks as the package will contain them.
    var structure: Structure {
        if let sections = customSections {
            return V1Converter.structure(for: self, sections: sections)
        }
        return V1Converter.convert(self)
    }

    /// New project, with a minimal skeleton for the author to start from.
    static func created(template: String = "case-study") -> Project {
        let theme = Theme(id: "theme-1", title: "First theme", description: "Describe in one line what these variations have in common.")
        let content = ProjectContent(
            label: "Case study with variations",
            title: "Case study title",
            subtitle: "Subtitle or focus of the study",
            objectives: ["First learning objective."],
            baseCase: ["Describe the base case situation here."],
            triggerQuestion: "What are the first actions to take?",
            reflectionNotice: "When you submit, your reflection is recorded on the platform and can be read by the course team. Do not write data that identifies real people.",
            quiz: Quiz(
                prompt: "Select all the correct options.",
                options: [
                    QuizOption(text: "Correct option", correct: true, feedback: "Explain why it is correct."),
                    QuizOption(text: "Incorrect option", correct: false, feedback: "Explain why it is incorrect.")
                ]
            ),
            caseSupport: [ListBlock(title: "Points of attention", items: ["First point."])],
            flow: [Step(title: "First step", items: ["First action."])],
            donts: ["What not to do."],
            themes: [theme],
            variations: [
                Variation(number: 1, theme: theme.id, title: "First variation",
                         whatIf: "What if the case were different?",
                         changes: ["What changes."], staysSame: ["What stays the same."],
                         synthesis: "One-line synthesis.",
                         question: "Reflection question for the learner.")
            ],
            principles: [],
            takeaways: [],
            references: []
        )
        var texts = Texts()
        texts.centralIdea = [Idea(title: "IDEA 1", text: "Short explanation.")]
        var project = Project(content: content, texts: texts)
        project.template = template
        return project
    }
}

// MARK: - Content

nonisolated struct ProjectContent: Codable, Equatable, Sendable {
    var label: String
    var title: String
    var subtitle: String
    var objectives: [String]
    var baseCase: [String]
    var triggerQuestion: String
    var reflectionNotice: String
    var quiz: Quiz
    /// Blocks shown after the learner answers the quiz (e.g. “What does this indicate?”, “Group duties”).
    var caseSupport: [ListBlock]
    var flow: [Step]
    var donts: [String]
    var themes: [Theme]
    var variations: [Variation]
    var principles: [String]
    var takeaways: [String]
    var references: [String]
}

nonisolated struct Quiz: Codable, Equatable, Sendable {
    var prompt: String
    var options: [QuizOption]
}

nonisolated struct QuizOption: Codable, Equatable, Sendable, Identifiable {
    var uid = UUID()
    var text: String
    var correct: Bool
    var feedback: String

    var id: UUID { uid }

    enum CodingKeys: String, CodingKey { case text, correct, feedback }

    init(text: String, correct: Bool, feedback: String) {
        self.text = text
        self.correct = correct
        self.feedback = feedback
    }
}

nonisolated struct ListBlock: Codable, Equatable, Sendable, Identifiable {
    var uid = UUID()
    var title: String
    var items: [String]

    var id: UUID { uid }

    enum CodingKeys: String, CodingKey { case title, items }

    init(title: String, items: [String]) {
        self.title = title
        self.items = items
    }
}

nonisolated struct Step: Codable, Equatable, Sendable, Identifiable {
    var uid = UUID()
    var title: String
    var items: [String]
    /// Step number. Recalculated on export from the position in the list.
    var n: Int?

    var id: UUID { uid }

    enum CodingKeys: String, CodingKey { case title, items, n }

    init(title: String, items: [String], n: Int? = nil) {
        self.title = title
        self.items = items
        self.n = n
    }
}

nonisolated struct Theme: Codable, Equatable, Sendable, Identifiable {
    /// Internal identifier (not editable by the author); variations point to it.
    var id: String
    var title: String
    var description: String
}

nonisolated struct Variation: Codable, Equatable, Sendable, Identifiable {
    var uid = UUID()
    /// Number shown to the learner and used in “Variation N” references (in JavaScript, the key is `id`).
    var number: Int
    /// `id` of the group (theme) the variation belongs to.
    var theme: String
    var title: String
    /// A pergunta “E se...?”.
    var whatIf: String
    var changes: [String]
    var staysSame: [String]
    var extra: [ListBlock] = []
    var synthesis: String
    var question: String

    var id: UUID { uid }

    enum CodingKeys: String, CodingKey {
        case number = "id"
        case theme, title, whatIf, changes, staysSame, extra, synthesis, question
    }

    init(number: Int, theme: String, title: String, whatIf: String,
         changes: [String], staysSame: [String], extra: [ListBlock] = [],
         synthesis: String, question: String) {
        self.number = number
        self.theme = theme
        self.title = title
        self.whatIf = whatIf
        self.changes = changes
        self.staysSame = staysSame
        self.extra = extra
        self.synthesis = synthesis
        self.question = question
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        number = try c.decode(Int.self, forKey: .number)
        theme = try c.decode(String.self, forKey: .theme)
        title = try c.decode(String.self, forKey: .title)
        whatIf = try c.decode(String.self, forKey: .whatIf)
        changes = try c.decode([String].self, forKey: .changes)
        staysSame = try c.decode([String].self, forKey: .staysSame)
        extra = try c.decodeIfPresent([ListBlock].self, forKey: .extra) ?? []
        synthesis = try c.decode(String.self, forKey: .synthesis)
        question = try c.decode(String.self, forKey: .question)
    }
}

// MARK: - Fixed texts of the learner interface

nonisolated struct Idea: Codable, Equatable, Sendable, Identifiable {
    var uid = UUID()
    var title: String
    var text: String

    var id: UUID { uid }

    enum CodingKeys: String, CodingKey { case title, text }

    init(title: String, text: String) {
        self.title = title
        self.text = text
    }
}

nonisolated struct Texts: Codable, Equatable, Sendable {
    var flowTitle = "Basic procedure flow"
    var flowIntro = "Steps that serve as a reference for all the variations. Open each step."
    var dontsTitle = "What NOT to do"
    var synthesisQuestion = "In one sentence: what stayed the same in every variation?"
    var centralIdea: [Idea] = []
    var principlesTitle = "Principles"
    var takeawaysTitle = "Key takeaways"

    init() {}

    enum CodingKeys: String, CodingKey {
        case flowTitle, flowIntro, dontsTitle, synthesisQuestion, centralIdea, principlesTitle, takeawaysTitle
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let standard = Texts.init()
        flowTitle = try c.decodeIfPresent(String.self, forKey: .flowTitle) ?? standard.flowTitle
        flowIntro = try c.decodeIfPresent(String.self, forKey: .flowIntro) ?? standard.flowIntro
        dontsTitle = try c.decodeIfPresent(String.self, forKey: .dontsTitle) ?? standard.dontsTitle
        synthesisQuestion = try c.decodeIfPresent(String.self, forKey: .synthesisQuestion) ?? standard.synthesisQuestion
        centralIdea = try c.decodeIfPresent([Idea].self, forKey: .centralIdea) ?? []
        principlesTitle = try c.decodeIfPresent(String.self, forKey: .principlesTitle) ?? standard.principlesTitle
        takeawaysTitle = try c.decodeIfPresent(String.self, forKey: .takeawaysTitle) ?? standard.takeawaysTitle
    }
}

// MARK: - Completion settings

nonisolated struct Config: Codable, Equatable, Sendable {
    /// How many variations the learner must reveal to complete. 0 = all.
    var requiredVariations = 0
    /// How many reflections must be submitted to complete. 0 = reflection is optional.
    var requiredReflections = 0
    var reflectionMin = 10
    var reflectionMax = 500

    init() {}

    enum CodingKeys: String, CodingKey {
        case requiredVariations, requiredReflections, reflectionMin, reflectionMax
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        requiredVariations = try c.decodeIfPresent(Int.self, forKey: .requiredVariations) ?? 0
        requiredReflections = try c.decodeIfPresent(Int.self, forKey: .requiredReflections) ?? 0
        reflectionMin = try c.decodeIfPresent(Int.self, forKey: .reflectionMin) ?? 10
        reflectionMax = try c.decodeIfPresent(Int.self, forKey: .reflectionMax) ?? 500
    }
}

// MARK: - Equality ignoring the editor-only `uid`
//
// `uid` is regenerated every time a file is read, so it must not take part in comparisons:
// two values are equal when they would be saved identically.

nonisolated private func sameWhenSaved<T: Encodable>(_ a: T, _ b: T) -> Bool {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return (try? encoder.encode(a)) == (try? encoder.encode(b))
}

extension QuizOption { nonisolated static func == (a: QuizOption, b: QuizOption) -> Bool { sameWhenSaved(a, b) } }
extension ListBlock { nonisolated static func == (a: ListBlock, b: ListBlock) -> Bool { sameWhenSaved(a, b) } }
extension Step { nonisolated static func == (a: Step, b: Step) -> Bool { sameWhenSaved(a, b) } }
extension Variation { nonisolated static func == (a: Variation, b: Variation) -> Bool { sameWhenSaved(a, b) } }
extension Idea { nonisolated static func == (a: Idea, b: Idea) -> Bool { sameWhenSaved(a, b) } }
