//
//  Editors.swift
//  gilwellSCROM
//
//  One form for each part of the case study.
//

import Foundation
import SwiftUI

// MARK: - General

struct GeneralEditor: View {
    @Binding var project: Project

    var body: some View {
        Form {
            EditorHeader(
                title: "General",
                explanation: "Title and objectives. They appear in the header and on the start screen of the case study."
            )
            Section("Header") {
                TextField("Line above the title", text: $project.content.label, prompt: Text("e.g. UD 4 - Reading 3"))
                TextField("Title", text: $project.content.title, axis: .vertical)
                    .lineLimit(1...3)
                TextField("Subtitle", text: $project.content.subtitle, axis: .vertical)
                    .lineLimit(1...3)
            }
            if project.customSections == nil {
                Section("Learning objectives") {
                    TextLines(items: $project.content.objectives, addLabel: "Add objective", hint: "Objective")
                }
            }
            Section("Notice below the reflection field") {
                TextField("Notice", text: $project.content.reflectionNotice, axis: .vertical)
                    .lineLimit(2...8)
                Text("Appears below each reflection field. Use it to guide the learner about privacy.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Base case

struct BaseCaseEditor: View {
    @Binding var project: Project

    var body: some View {
        Form {
            EditorHeader(
                title: "Base case",
                explanation: "The starting situation for all the variations, the trigger question and the blocks that appear after the learner answers the quiz."
            )
            Section("Case description") {
                TextLines(items: $project.content.baseCase, addLabel: "Add sentence", hint: "Case sentence")
            }
            Section("Trigger question") {
                TextField("Question", text: $project.content.triggerQuestion, axis: .vertical)
                    .lineLimit(1...4)
            }
            BlockSections(blocks: $project.content.caseSupport, blockLabel: "Support block", addLabel: "Add support block")
        }
        .formStyle(.grouped)
    }
}

// MARK: - Quiz

struct QuizEditor: View {
    @Binding var project: Project

    var body: some View {
        Form {
            EditorHeader(
                title: "Base case quiz",
                explanation: "Multiple-select question. The learner selects the correct options and receives a comment for each one."
            )
            Section("Prompt") {
                TextField("Prompt", text: $project.content.quiz.prompt, axis: .vertical)
                    .lineLimit(1...4)
            }
            ForEach(Array(project.content.quiz.options.indices), id: \.self) { i in
                let option = $project.content.quiz.options.element(i, standard: QuizOption(text: "", correct: false, feedback: ""))
                Section {
                    TextField("Option text", text: option.text, axis: .vertical)
                        .lineLimit(1...5)
                    Toggle("Correct option", isOn: option.correct)
                    TextField("Comment shown to the learner", text: option.feedback, axis: .vertical)
                        .lineLimit(1...6)
                    HStack {
                        OrderButtons(
                            canMoveUp: i > 0,
                            canMoveDown: i < project.content.quiz.options.count - 1,
                            moveUp: { project.content.quiz.options.swapAt(i, i - 1) },
                            moveDown: { project.content.quiz.options.swapAt(i, i + 1) },
                            delete: { project.content.quiz.options.remove(at: i) }
                        )
                        Text("Move or delete this option")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Option \(i + 1)")
                }
            }
            Section {
                Button {
                    project.content.quiz.options.append(QuizOption(text: "", correct: false, feedback: ""))
                } label: {
                    Label("Add option", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
                Text("Options appear in the order shown here. Mix correct and incorrect ones.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Flow

struct FlowEditor: View {
    @Binding var project: Project

    var body: some View {
        Form {
            EditorHeader(
                title: "Flow",
                explanation: "The reference steps, shown as sections that open and close, and the list of what not to do."
            )
            Section("Page texts") {
                TextField("Page title", text: $project.texts.flowTitle)
                TextField("Introduction", text: $project.texts.flowIntro, axis: .vertical)
                    .lineLimit(1...3)
            }
            ForEach(Array(project.content.flow.indices), id: \.self) { i in
                let step = $project.content.flow.element(i, standard: Step(title: "", items: []))
                Section {
                    TextField("Step title", text: step.title)
                    TextLines(items: step.items, addLabel: "Add item", hint: "Step item")
                    HStack {
                        OrderButtons(
                            canMoveUp: i > 0,
                            canMoveDown: i < project.content.flow.count - 1,
                            moveUp: { project.content.flow.swapAt(i, i - 1) },
                            moveDown: { project.content.flow.swapAt(i, i + 1) },
                            delete: { project.content.flow.remove(at: i) }
                        )
                        Text("Move or delete this step")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Step \(i + 1)")
                }
            }
            Section {
                Button {
                    project.content.flow.append(Step(title: "", items: [""]))
                } label: {
                    Label("Add step", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
            }
            Section("What not to do") {
                TextField("Box title", text: $project.texts.dontsTitle)
                TextLines(items: $project.content.donts, addLabel: "Add item", hint: "What not to do")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Themes (groups of variations)

struct ThemesEditor: View {
    @Binding var project: Project

    var body: some View {
        Form {
            EditorHeader(
                title: "Themes",
                explanation: "They group the variations on the map and set the order of “previous” and “next” within each variation. A theme that has variations cannot be deleted."
            )
            ForEach(Array(project.content.themes.indices), id: \.self) { i in
                let theme = $project.content.themes.element(i, standard: Theme(id: "", title: "", description: ""))
                let inUse = project.content.variations.filter { $0.theme == theme.wrappedValue.id }.count
                Section {
                    TextField("Theme title", text: theme.title)
                    TextField("Short description", text: theme.description, axis: .vertical)
                        .lineLimit(1...3)
                    HStack {
                        OrderButtons(
                            canMoveUp: i > 0,
                            canMoveDown: i < project.content.themes.count - 1,
                            moveUp: { project.content.themes.swapAt(i, i - 1) },
                            moveDown: { project.content.themes.swapAt(i, i + 1) },
                            delete: {
                                if inUse == 0 { project.content.themes.remove(at: i) }
                            }
                        )
                        Text(inUse == 0 ? "No variations: can be deleted" : "\(inUse) variation(s) in this theme")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Theme \(i + 1)")
                }
            }
            Section {
                Button {
                    let newId = "theme-" + UUID().uuidString.prefix(8).lowercased()
                    project.content.themes.append(Theme(id: newId, title: "New theme", description: ""))
                } label: {
                    Label("Add theme", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Variation

struct VariationEditor: View {
    @Binding var variation: Variation
    let themes: [Theme]
    var delete: () -> Void

    @State private var confirmingDeletion = false

    var body: some View {
        Form {
            EditorHeader(
                title: "Variation \(variation.number)",
                explanation: "The learner sees the “What if...?” question, thinks, and only then reveals the analysis: what changes, what stays the same, the synthesis and the reflection question."
            )
            Section("Identification") {
                TextField("Number", value: $variation.number, format: .number.grouping(.never))
                Picker("Theme", selection: $variation.theme) {
                    ForEach(themes) { g in
                        Text(g.title.isEmpty ? g.id : g.title).tag(g.id)
                    }
                    if !themes.contains(where: { $0.id == variation.theme }) {
                        Text("(theme removed)").tag(variation.theme)
                    }
                }
                TextField("Short title", text: $variation.title)
                TextField("“What if...?” question", text: $variation.whatIf, axis: .vertical)
                    .lineLimit(1...4)
            }
            Section("What changes") {
                TextLines(items: $variation.changes, addLabel: "Add item", hint: "What changes")
            }
            Section("What stays the same") {
                TextLines(items: $variation.staysSame, addLabel: "Add item", hint: "What stays the same")
            }
            BlockSections(blocks: $variation.extra, blockLabel: "Extra block", addLabel: "Add extra block")
            Section("Closing") {
                TextField("One-line synthesis", text: $variation.synthesis, axis: .vertical)
                    .lineLimit(1...3)
                TextField("Reflection question", text: $variation.question, axis: .vertical)
                    .lineLimit(1...4)
            }
            Section {
                Text("Tip: write “Variation N” in any text to create a link to that variation in the learner's view.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Delete this variation", role: .destructive) {
                    confirmingDeletion = true
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Delete variation \(variation.number)?", isPresented: $confirmingDeletion) {
            Button("Delete", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone after saving.")
        }
    }
}

// MARK: - Synthesis

struct SynthesisEditor: View {
    @Binding var project: Project

    var body: some View {
        Form {
            EditorHeader(
                title: "Synthesis and closing",
                explanation: "The final page: the central idea that repeats across all the variations, the side-by-side table (built automatically), principles and references."
            )
            Section("Central idea") {
                TextField("Question before the table", text: $project.texts.synthesisQuestion, axis: .vertical)
                    .lineLimit(1...3)
            }
            ForEach(Array(project.texts.centralIdea.indices), id: \.self) { i in
                let idea = $project.texts.centralIdea.element(i, standard: Idea(title: "", text: ""))
                Section {
                    TextField("Palavra-key", text: idea.title)
                    TextField("Short explanation", text: idea.text, axis: .vertical)
                        .lineLimit(1...3)
                    HStack {
                        OrderButtons(
                            canMoveUp: i > 0,
                            canMoveDown: i < project.texts.centralIdea.count - 1,
                            moveUp: { project.texts.centralIdea.swapAt(i, i - 1) },
                            moveDown: { project.texts.centralIdea.swapAt(i, i + 1) },
                            delete: { project.texts.centralIdea.remove(at: i) }
                        )
                        Text("Move or delete")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Idea \(i + 1)")
                }
            }
            Section {
                Button {
                    project.texts.centralIdea.append(Idea(title: "", text: ""))
                } label: {
                    Label("Add idea", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
            }
            Section("Principles") {
                TextField("Box title", text: $project.texts.principlesTitle)
                TextLines(items: $project.content.principles, addLabel: "Add principle", hint: "Principle")
            }
            Section("Key takeaways") {
                TextField("Box title", text: $project.texts.takeawaysTitle)
                TextLines(items: $project.content.takeaways, addLabel: "Add item", hint: "Closing message")
            }
            Section("References") {
                TextLines(items: $project.content.references, addLabel: "Add reference", hint: "Reference")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Completion settings

struct SettingsEditor: View {
    @Binding var project: Project
    /// Turns the fixed pages into free-form sections and blocks (the sidebar then lists the sections).
    var convertToSections: () -> Void

    @State private var confirmingConversion = false

    var body: some View {
        Form {
            EditorHeader(
                title: "Settings",
                explanation: "Defines when Moodle marks the activity as completed, how reflections are recorded and how the pages are structured."
            )
            Section("Page structure") {
                if project.customSections == nil {
                    Text("The pages are generated from fixed forms (Base case, Quiz, Basic flow, Synthesis). Unlock them to add, remove, rename and rearrange sections and blocks yourself.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button {
                        confirmingConversion = true
                    } label: {
                        Label("Edit sections and blocks freely…", systemImage: "square.stack.3d.up")
                    }
                } else {
                    Label("Sections and blocks are edited freely.", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                }
            }
            Section("Completion") {
                Stepper(value: $project.config.requiredVariations, in: 0...max(project.content.variations.count, 1)) {
                    Text(project.config.requiredVariations == 0
                         ? "Variations revealed to complete: all (\(project.content.variations.count))"
                         : "Variations revealed to complete: \(project.config.requiredVariations)")
                }
                Stepper(value: $project.config.requiredReflections, in: 0...max(project.content.variations.count, 1)) {
                    Text(project.config.requiredReflections == 0
                         ? "Reflections submitted to complete: none (optional)"
                         : "Reflections submitted to complete: \(project.config.requiredReflections)")
                }
                Text("In Moodle, under “Activity completion”, enable the rule “Require status: Completed”. The package marks “completed” when the conditions above are met.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Learner reflections") {
                Stepper(value: $project.config.reflectionMin, in: 0...200, step: 5) {
                    Text("Minimum characters to submit: \(project.config.reflectionMin)")
                }
                Stepper(value: $project.config.reflectionMax, in: 50...2000, step: 50) {
                    Text("Maximum characters: \(project.config.reflectionMax)")
                }
                Text("Reflections go to the SCORM activity's Interactions report. SCORM 1.2 limits each answer to 255 characters, so long texts are split into parts (_p1, _p2) when saved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Edit sections and blocks freely?", isPresented: $confirmingConversion) {
            Button("Unlock and convert") { convertToSections() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The Base case, Quiz, Basic flow and Synthesis pages become sections made of blocks that you can add, remove and rearrange. Their fixed forms are no longer used. This cannot be undone.")
        }
    }
}

// MARK: - Checks

struct FindingsPanel: View {
    let findings: [Finding]

    var body: some View {
        Form {
            EditorHeader(
                title: "Checks",
                explanation: "Problems found in the project. Errors block the export; warnings do not."
            )
            if findings.isEmpty {
                Section {
                    Label("All good: no problems found.", systemImage: "checkmark.seal")
                        .foregroundStyle(.green)
                }
            } else {
                Section {
                    ForEach(findings) { a in
                        Label {
                            Text(a.text)
                        } icon: {
                            Image(systemName: a.level == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(a.level == .error ? Color.red : Color.orange)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
