//
//  Block.swift
//  gilwellSCROM
//
//  The blocks an author stacks inside a section. Each type has its own data struct
//  (`…Data`); `Block` pairs a stable identifier with the data of one type.
//
//  In the file, a block is stored "flattened": { "id": "...", "type": "alert", ...properties }.
//  The JavaScript runtime reads exactly this format.
//

import Foundation

// MARK: - Tipos e valores auxiliares

nonisolated enum BlockType: String, Codable, CaseIterable, Sendable {
    case content, alert, accordion, columns, highlight, button, quiz, reveal, reflection, map, table, progress

    var name: String {
        switch self {
        case .content: return "Content"
        case .alert: return "Alert"
        case .accordion: return "Accordion"
        case .columns: return "Columns"
        case .highlight: return "Highlight"
        case .button: return "Button"
        case .quiz: return "Quiz"
        case .reveal: return "Reveal"
        case .reflection: return "Reflection"
        case .map: return "Variations map"
        case .table: return "Variations table"
        case .progress: return "Progress"
        }
    }

    var summary: String {
        switch self {
        case .content: return "Heading with text or a list."
        case .alert: return "Callout box for highlights, warnings or errors."
        case .accordion: return "List of items that open and close."
        case .columns: return "Two or three columns side by side."
        case .highlight: return "A featured sentence."
        case .button: return "Button that goes to another section."
        case .quiz: return "Multiple choice with checking."
        case .reveal: return "Hides blocks until a button or a quiz."
        case .reflection: return "Open question recorded in Moodle."
        case .map: return "Variation cards, grouped by theme."
        case .table: return "All variations side by side."
        case .progress: return "How much the learner has explored."
        }
    }

    /// SF Symbols symbol.
    var icon: String {
        switch self {
        case .content: return "text.alignleft"
        case .alert: return "exclamationmark.triangle"
        case .accordion: return "list.bullet.indent"
        case .columns: return "rectangle.split.3x1"
        case .highlight: return "quote.opening"
        case .button: return "arrow.right.circle"
        case .quiz: return "checklist"
        case .reveal: return "eye"
        case .reflection: return "text.bubble"
        case .map: return "square.grid.2x2"
        case .table: return "tablecells"
        case .progress: return "chart.bar"
        }
    }

    /// Only makes sense in projects that have variations.
    var requiresVariations: Bool { self == .map || self == .table }
}

nonisolated enum Marker: String, Codable, CaseIterable, Sendable {
    case plain, check, cross
}

nonisolated enum ContentStyle: String, Codable, CaseIterable, Sendable {
    case standard, highlight, question
}

nonisolated enum AlertStyle: String, Codable, CaseIterable, Sendable {
    case highlight, warning, error
}

/// Where a button leads.
nonisolated enum ButtonDestination: Codable, Equatable, Sendable {
    case next
    case section(String)

    init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        if text.hasPrefix("section:") {
            self = .section(String(text.dropFirst("section:".count)))
        } else {
            self = .next
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .next: try c.encode("next")
        case .section(let id): try c.encode("section:" + id)
        }
    }
}

/// What makes a “Reveal” block appear.
nonisolated enum RevealTrigger: Codable, Equatable, Sendable {
    /// The learner clicks a button.
    case button
    /// The learner answers (checks) the quiz with this identifier.
    case quiz(String)

    init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        if text.hasPrefix("quiz:") {
            self = .quiz(String(text.dropFirst("quiz:".count)))
        } else {
            self = .button
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .button: try c.encode("button")
        case .quiz(let id): try c.encode("quiz:" + id)
        }
    }
}

// MARK: - Data for each type

nonisolated struct ContentData: Codable, Equatable, Sendable {
    var title: String = ""
    var style: ContentStyle = .standard
    /// true = bulleted list; false = paragraphs.
    var list: Bool = true
    var marker: Marker = .plain
    var items: [String] = []
}

nonisolated struct AlertData: Codable, Equatable, Sendable {
    var style: AlertStyle = .highlight
    var title: String = ""
    var list: Bool = true
    var marker: Marker = .plain
    var items: [String] = []
}

nonisolated struct AccordionItem: Codable, Equatable, Sendable {
    var title: String = ""
    var items: [String] = []
}

nonisolated struct AccordionData: Codable, Equatable, Sendable {
    var title: String = ""
    var numbered: Bool = true
    var items: [AccordionItem] = []
}

nonisolated struct ContentColumn: Codable, Equatable, Sendable {
    var title: String = ""
    var list: Bool = true
    var marker: Marker = .plain
    var items: [String] = []
}

nonisolated struct ColumnsData: Codable, Equatable, Sendable {
    var columns: [ContentColumn] = []
}

nonisolated struct HighlightData: Codable, Equatable, Sendable {
    var text: String = ""
}

nonisolated struct ButtonData: Codable, Equatable, Sendable {
    var label: String = "Continue"
    var destination: ButtonDestination = .next
}

nonisolated struct QuizData: Codable, Equatable, Sendable {
    var title: String = ""
    var prompt: String = ""
    var options: [QuizOption] = []
    var verifyLabel: String = "Check answers"
    var successMessage: String = "Well done: your answer matches what was expected."
    var reviewMessage: String = "Some points deserve another look. See the comments on the options."
    /// If true, the learner must get this quiz right to complete (when the criterion is turned on).
    var countsForCompletion: Bool = false
}

nonisolated struct RevealData: Codable, Equatable, Sendable {
    var trigger: RevealTrigger = .button
    /// Button text (only when the trigger is a button).
    var label: String = "Show"
    var blocks: [Block] = []
}

nonisolated struct ReflectionData: Codable, Equatable, Sendable {
    var question: String = ""
    var notice: String = ""
    var minimum: Int = 10
    var maximum: Int = 500
    var countsForCompletion: Bool = false
}

nonisolated struct MapData: Codable, Equatable, Sendable {
    var intro: String = ""
    /// Button that appears once all variations have been explored.
    var labelOnComplete: String = "Continue"
    var destinationOnComplete: ButtonDestination = .next
}

nonisolated struct TableData: Codable, Equatable, Sendable {
    var title: String = "All variations side by side"
}

nonisolated struct ProgressData: Codable, Equatable, Sendable {
    var buttonLabel: String = "Back to the variations"
    var destination: ButtonDestination = .next
}

// MARK: - Bloco

nonisolated enum BlockData: Equatable, Sendable {
    case content(ContentData)
    case alert(AlertData)
    case accordion(AccordionData)
    case columns(ColumnsData)
    case highlight(HighlightData)
    case button(ButtonData)
    case quiz(QuizData)
    case reveal(RevealData)
    case reflection(ReflectionData)
    case map(MapData)
    case table(TableData)
    case progress(ProgressData)

    var type: BlockType {
        switch self {
        case .content: return .content
        case .alert: return .alert
        case .accordion: return .accordion
        case .columns: return .columns
        case .highlight: return .highlight
        case .button: return .button
        case .quiz: return .quiz
        case .reveal: return .reveal
        case .reflection: return .reflection
        case .map: return .map
        case .table: return .table
        case .progress: return .progress
        }
    }

    /// Blank data for a type (used when dragging a new block from the palette).
    static func empty(_ type: BlockType) -> BlockData {
        switch type {
        case .content: return .content(ContentData(title: "Title", items: ["First item."]))
        case .alert: return .alert(AlertData(style: .warning, title: "Warning", items: ["Alert text."]))
        case .accordion: return .accordion(AccordionData(items: [AccordionItem(title: "First item", items: ["Content."])]))
        case .columns: return .columns(ColumnsData(columns: [
            ContentColumn(title: "Column 1", items: ["Text."]),
            ContentColumn(title: "Column 2", items: ["Text."])
        ]))
        case .highlight: return .highlight(HighlightData(text: "Featured sentence."))
        case .button: return .button(ButtonData())
        case .quiz: return .quiz(QuizData(
            prompt: "Select all the correct options.",
            options: [
                QuizOption(text: "Correct option", correct: true, feedback: "Why it is correct."),
                QuizOption(text: "Incorrect option", correct: false, feedback: "Why it is incorrect.")
            ]))
        case .reveal: return .reveal(RevealData())
        case .reflection: return .reflection(ReflectionData(question: "What is your reflection?"))
        case .map: return .map(MapData())
        case .table: return .table(TableData())
        case .progress: return .progress(ProgressData())
        }
    }
}

nonisolated struct Block: Codable, Equatable, Sendable, Identifiable {
    /// Stable: used in the learner's saved state, in Moodle interactions and in triggers between blocks.
    var id: String
    var data: BlockData

    var type: BlockType { data.type }

    init(id: String = Block.newID(), data: BlockData) {
        self.id = id
        self.data = data
    }

    static func newID() -> String {
        "b-" + String(UUID().uuidString.lowercased().prefix(8))
    }

    enum CodingKeys: String, CodingKey { case id, type }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        switch try c.decode(BlockType.self, forKey: .type) {
        case .content: data = .content(try ContentData(from: decoder))
        case .alert: data = .alert(try AlertData(from: decoder))
        case .accordion: data = .accordion(try AccordionData(from: decoder))
        case .columns: data = .columns(try ColumnsData(from: decoder))
        case .highlight: data = .highlight(try HighlightData(from: decoder))
        case .button: data = .button(try ButtonData(from: decoder))
        case .quiz: data = .quiz(try QuizData(from: decoder))
        case .reveal: data = .reveal(try RevealData(from: decoder))
        case .reflection: data = .reflection(try ReflectionData(from: decoder))
        case .map: data = .map(try MapData(from: decoder))
        case .table: data = .table(try TableData(from: decoder))
        case .progress: data = .progress(try ProgressData(from: decoder))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(data.type, forKey: .type)
        switch data {
        case .content(let d): try d.encode(to: encoder)
        case .alert(let d): try d.encode(to: encoder)
        case .accordion(let d): try d.encode(to: encoder)
        case .columns(let d): try d.encode(to: encoder)
        case .highlight(let d): try d.encode(to: encoder)
        case .button(let d): try d.encode(to: encoder)
        case .quiz(let d): try d.encode(to: encoder)
        case .reveal(let d): try d.encode(to: encoder)
        case .reflection(let d): try d.encode(to: encoder)
        case .map(let d): try d.encode(to: encoder)
        case .table(let d): try d.encode(to: encoder)
        case .progress(let d): try d.encode(to: encoder)
        }
    }
}
