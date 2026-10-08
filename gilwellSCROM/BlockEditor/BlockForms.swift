//
//  BlockForms.swift
//  gilwellSCROM
//
//  One form per block type. `BlockForm` picks the right one for the block's data.
//

import Foundation
import SwiftUI

// MARK: - Small shared pieces

/// A caption above a control.
struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content
        }
    }
}

extension Marker {
    var displayName: String {
        switch self {
        case .plain: return "Plain bullets"
        case .check: return "Check marks"
        case .cross: return "Crosses"
        }
    }
}

extension ContentStyle {
    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .highlight: return "Highlighted"
        case .question: return "Question"
        }
    }
}

extension AlertStyle {
    var displayName: String {
        switch self {
        case .highlight: return "Highlight"
        case .warning: return "Warning"
        case .error: return "Error (what not to do)"
        }
    }
}

/// Picks where a button leads: the next section or a specific one.
struct DestinationPicker: View {
    let label: String
    @Binding var destination: ButtonDestination
    @Environment(\.editorContext) private var context

    private var choice: Binding<String> {
        Binding<String>(
            get: {
                if case .section(let id) = destination { return id }
                return ""
            },
            set: { destination = $0.isEmpty ? .next : .section($0) }
        )
    }

    private var missingID: String? {
        if case .section(let id) = destination, !context.sections.contains(where: { $0.id == id }) { return id }
        return nil
    }

    var body: some View {
        Picker(label, selection: choice) {
            Text("Next section").tag("")
            ForEach(context.sections) { section in
                Text(section.title).tag(section.id)
            }
            if let missing = missingID {
                Text("(missing section)").tag(missing)
            }
        }
    }
}

/// Title (optional), list/paragraph switch, marker and items: shared by content, alert and column forms.
struct TextBlockFields: View {
    var title: Binding<String>?
    var titleLabel = "Title"
    @Binding var list: Bool
    @Binding var marker: Marker
    @Binding var items: [String]

    var body: some View {
        if let title {
            LabeledField(label: titleLabel) {
                TextField(titleLabel, text: title)
                    .textFieldStyle(.roundedBorder)
            }
        }
        Toggle("Show as a bulleted list", isOn: $list)
        if list {
            Picker("Marker", selection: $marker) {
                ForEach(Marker.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
        }
        TextLines(items: $items, addLabel: list ? "Add item" : "Add paragraph", hint: list ? "Item text" : "Paragraph text")
    }
}

// MARK: - Dispatcher

struct BlockForm: View {
    @Binding var data: BlockData

    var body: some View {
        switch data {
        case .content(let d): ContentForm(data: bind(d, { $0.asContent }, { .content($0) }))
        case .alert(let d): AlertForm(data: bind(d, { $0.asAlert }, { .alert($0) }))
        case .accordion(let d): AccordionForm(data: bind(d, { $0.asAccordion }, { .accordion($0) }))
        case .columns(let d): ColumnsForm(data: bind(d, { $0.asColumns }, { .columns($0) }))
        case .highlight(let d): HighlightForm(data: bind(d, { $0.asHighlight }, { .highlight($0) }))
        case .button(let d): ButtonForm(data: bind(d, { $0.asButton }, { .button($0) }))
        case .quiz(let d): QuizForm(data: bind(d, { $0.asQuiz }, { .quiz($0) }))
        case .reveal(let d): RevealForm(data: bind(d, { $0.asReveal }, { .reveal($0) }))
        case .reflection(let d): ReflectionForm(data: bind(d, { $0.asReflection }, { .reflection($0) }))
        case .map(let d): MapForm(data: bind(d, { $0.asMap }, { .map($0) }))
        case .table(let d): TableForm(data: bind(d, { $0.asTable }, { .table($0) }))
        case .progress(let d): ProgressForm(data: bind(d, { $0.asProgress }, { .progress($0) }))
        }
    }

    /// Binding to the payload of one case; falls back to the last known value if the case changes underneath.
    private func bind<T>(_ initial: T, _ extract: @escaping (BlockData) -> T?, _ wrap: @escaping (T) -> BlockData) -> Binding<T> {
        Binding<T>(
            get: { extract(data) ?? initial },
            set: { data = wrap($0) }
        )
    }
}

// MARK: - Forms

struct ContentForm: View {
    @Binding var data: ContentData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Style", selection: $data.style) {
                ForEach(ContentStyle.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            TextBlockFields(title: $data.title, list: $data.list, marker: $data.marker, items: $data.items)
        }
    }
}

struct AlertForm: View {
    @Binding var data: AlertData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Style", selection: $data.style) {
                ForEach(AlertStyle.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            TextBlockFields(title: $data.title, list: $data.list, marker: $data.marker, items: $data.items)
        }
    }
}

struct AccordionForm: View {
    @Binding var data: AccordionData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledField(label: "Title (optional)") {
                TextField("Title", text: $data.title)
                    .textFieldStyle(.roundedBorder)
            }
            Toggle("Number the items", isOn: $data.numbered)
            ForEach(Array(data.items.indices), id: \.self) { i in
                let item = $data.items.element(i, standard: AccordionItem())
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Item title", text: item.title)
                                .textFieldStyle(.roundedBorder)
                            OrderButtons(
                                canMoveUp: i > 0,
                                canMoveDown: i < data.items.count - 1,
                                moveUp: { data.items.swapAt(i, i - 1) },
                                moveDown: { data.items.swapAt(i, i + 1) },
                                delete: { data.items.remove(at: i) }
                            )
                        }
                        TextLines(items: item.items, addLabel: "Add line", hint: "Text inside the item")
                    }
                    .padding(4)
                }
            }
            Button {
                data.items.append(AccordionItem(title: "New item", items: [""]))
            } label: {
                Label("Add accordion item", systemImage: "plus.circle")
            }
            .buttonStyle(.borderless)
        }
    }
}

struct ColumnsForm: View {
    @Binding var data: ColumnsData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(data.columns.indices), id: \.self) { i in
                let column = $data.columns.element(i, standard: ContentColumn())
                GroupBox("Column \(i + 1)") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextBlockFields(title: column.title, list: column.list, marker: column.marker, items: column.items)
                        HStack {
                            OrderButtons(
                                canMoveUp: i > 0,
                                canMoveDown: i < data.columns.count - 1,
                                moveUp: { data.columns.swapAt(i, i - 1) },
                                moveDown: { data.columns.swapAt(i, i + 1) },
                                delete: { data.columns.remove(at: i) }
                            )
                            Text("Move or delete this column")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(4)
                }
            }
            if data.columns.count < 3 {
                Button {
                    data.columns.append(ContentColumn(title: "Column \(data.columns.count + 1)", items: [""]))
                } label: {
                    Label("Add column", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

struct HighlightForm: View {
    @Binding var data: HighlightData

    var body: some View {
        LabeledField(label: "Featured sentence") {
            TextField("Sentence", text: $data.text, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
        }
    }
}

struct ButtonForm: View {
    @Binding var data: ButtonData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledField(label: "Button text") {
                TextField("Text", text: $data.label)
                    .textFieldStyle(.roundedBorder)
            }
            DestinationPicker(label: "Goes to", destination: $data.destination)
        }
    }
}

struct QuizForm: View {
    @Binding var data: QuizData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledField(label: "Title (optional)") {
                TextField("Title", text: $data.title)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledField(label: "Prompt") {
                TextField("Prompt", text: $data.prompt, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
            }
            ForEach(Array(data.options.indices), id: \.self) { i in
                let option = $data.options.element(i, standard: QuizOption(text: "", correct: false, feedback: ""))
                GroupBox("Option \(i + 1)") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Option text", text: option.text, axis: .vertical)
                            .lineLimit(1...5)
                            .textFieldStyle(.roundedBorder)
                        Toggle("Correct option", isOn: option.correct)
                        TextField("Comment shown to the learner", text: option.feedback, axis: .vertical)
                            .lineLimit(1...6)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            OrderButtons(
                                canMoveUp: i > 0,
                                canMoveDown: i < data.options.count - 1,
                                moveUp: { data.options.swapAt(i, i - 1) },
                                moveDown: { data.options.swapAt(i, i + 1) },
                                delete: { data.options.remove(at: i) }
                            )
                            Text("Move or delete this option")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(4)
                }
            }
            Button {
                data.options.append(QuizOption(text: "", correct: false, feedback: ""))
            } label: {
                Label("Add option", systemImage: "plus.circle")
            }
            .buttonStyle(.borderless)
            LabeledField(label: "Check button text") {
                TextField("Text", text: $data.verifyLabel)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledField(label: "Message when everything is right") {
                TextField("Message", text: $data.successMessage, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledField(label: "Message when something needs review") {
                TextField("Message", text: $data.reviewMessage, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
            }
            Toggle("Counts for completion (when the quiz criterion is on)", isOn: $data.countsForCompletion)
        }
    }
}

struct RevealForm: View {
    @Binding var data: RevealData
    @Environment(\.editorContext) private var context

    private var triggerChoice: Binding<String> {
        Binding<String>(
            get: {
                if case .quiz(let id) = data.trigger { return id }
                return ""
            },
            set: { data.trigger = $0.isEmpty ? .button : .quiz($0) }
        )
    }

    private var missingQuiz: String? {
        if case .quiz(let id) = data.trigger, !context.quizzes.contains(where: { $0.id == id }) { return id }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Appears when", selection: triggerChoice) {
                Text("The learner clicks a button").tag("")
                ForEach(context.quizzes) { quiz in
                    Text("The learner checks quiz: \(quiz.title)").tag(quiz.id)
                }
                if let missing = missingQuiz {
                    Text("(missing quiz)").tag(missing)
                }
            }
            if case .button = data.trigger {
                LabeledField(label: "Button text") {
                    TextField("Text", text: $data.label)
                        .textFieldStyle(.roundedBorder)
                }
            }
            Text("Hidden blocks")
                .font(.caption)
                .foregroundStyle(.secondary)
            GroupBox {
                BlockListEditor(blocks: $data.blocks)
                    .padding(4)
            }
        }
    }
}

struct ReflectionForm: View {
    @Binding var data: ReflectionData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledField(label: "Question") {
                TextField("Question", text: $data.question, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledField(label: "Notice below the field") {
                TextField("Notice", text: $data.notice, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                TextField("Minimum characters", value: $data.minimum, format: .number.grouping(.never))
                TextField("Maximum characters", value: $data.maximum, format: .number.grouping(.never))
            }
            .textFieldStyle(.roundedBorder)
            Toggle("Counts for completion (when the reflection criterion is on)", isOn: $data.countsForCompletion)
        }
    }
}

struct MapForm: View {
    @Binding var data: MapData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Shows the variation cards grouped by theme. Exploring them is one of the ways to complete the SCORM.")
                .font(.caption)
                .foregroundStyle(.secondary)
            LabeledField(label: "Introduction (optional)") {
                TextField("Introduction", text: $data.intro, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledField(label: "Button shown after all variations are explored") {
                TextField("Text", text: $data.labelOnComplete)
                    .textFieldStyle(.roundedBorder)
            }
            DestinationPicker(label: "That button goes to", destination: $data.destinationOnComplete)
        }
    }
}

struct TableForm: View {
    @Binding var data: TableData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("All variations side by side. Only works in projects that have variations.")
                .font(.caption)
                .foregroundStyle(.secondary)
            LabeledField(label: "Title") {
                TextField("Title", text: $data.title)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}

struct ProgressForm: View {
    @Binding var data: ProgressData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Shows how many variations the learner has explored, with a button back to the map.")
                .font(.caption)
                .foregroundStyle(.secondary)
            LabeledField(label: "Button text") {
                TextField("Text", text: $data.buttonLabel)
                    .textFieldStyle(.roundedBorder)
            }
            DestinationPicker(label: "Button goes to", destination: $data.destination)
        }
    }
}
