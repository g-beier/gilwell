//
//  BlockInfo.swift
//  gilwellSCROM
//
//  Small helpers over blocks used by the structure editor: typed access to a block's data,
//  a one-line summary, duplication with fresh identifiers, and the context (sections, quizzes) the forms need.
//

import Foundation
import SwiftUI

extension BlockData {
    var asContent: ContentData? { if case .content(let d) = self { return d } else { return nil } }
    var asAlert: AlertData? { if case .alert(let d) = self { return d } else { return nil } }
    var asAccordion: AccordionData? { if case .accordion(let d) = self { return d } else { return nil } }
    var asColumns: ColumnsData? { if case .columns(let d) = self { return d } else { return nil } }
    var asHighlight: HighlightData? { if case .highlight(let d) = self { return d } else { return nil } }
    var asButton: ButtonData? { if case .button(let d) = self { return d } else { return nil } }
    var asQuiz: QuizData? { if case .quiz(let d) = self { return d } else { return nil } }
    var asReveal: RevealData? { if case .reveal(let d) = self { return d } else { return nil } }
    var asReflection: ReflectionData? { if case .reflection(let d) = self { return d } else { return nil } }
    var asMap: MapData? { if case .map(let d) = self { return d } else { return nil } }
    var asTable: TableData? { if case .table(let d) = self { return d } else { return nil } }
    var asProgress: ProgressData? { if case .progress(let d) = self { return d } else { return nil } }
}

extension Block {
    /// Short text shown next to the block type in the editor.
    var summaryLine: String {
        func firstFilled(_ list: [String]) -> String {
            list.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? ""
        }
        switch data {
        case .content(let d): return d.title.isEmpty ? firstFilled(d.items) : d.title
        case .alert(let d): return d.title.isEmpty ? firstFilled(d.items) : d.title
        case .accordion(let d): return d.title.isEmpty ? "\(d.items.count) items" : d.title
        case .columns(let d): return "\(d.columns.count) columns"
        case .highlight(let d): return d.text
        case .button(let d): return d.label
        case .quiz(let d): return d.title.isEmpty ? d.prompt : d.title
        case .reveal(let d): return "\(d.blocks.count) hidden blocks"
        case .reflection(let d): return d.question
        case .map(let d): return d.intro
        case .table(let d): return d.title
        case .progress(let d): return d.buttonLabel
        }
    }

    /// A copy with new identifiers (also for blocks hidden inside a “Reveal”).
    func duplicated() -> Block {
        var copy = self
        copy.id = Block.newID()
        if case .reveal(var reveal) = copy.data {
            reveal.blocks = reveal.blocks.map { $0.duplicated() }
            copy.data = .reveal(reveal)
        }
        return copy
    }
}

/// A named reference to a section or a quiz, for pickers.
struct EditorReference: Identifiable, Hashable {
    let id: String
    let title: String
}

/// What the block forms need to know about the rest of the project.
struct EditorContext {
    var sections: [EditorReference] = []
    var quizzes: [EditorReference] = []
    var hasVariations = false

    init() {}

    init(sections: [ScormSection], hasVariations: Bool) {
        self.sections = sections.map { EditorReference(id: $0.id, title: $0.title.isEmpty ? $0.id : $0.title) }
        self.hasVariations = hasVariations
        func quizzes(in blocks: [Block]) -> [EditorReference] {
            blocks.flatMap { block -> [EditorReference] in
                switch block.data {
                case .quiz(let q):
                    return [EditorReference(id: block.id, title: q.title.isEmpty ? (q.prompt.isEmpty ? block.id : q.prompt) : q.title)]
                case .reveal(let r):
                    return quizzes(in: r.blocks)
                default:
                    return []
                }
            }
        }
        self.quizzes = sections.flatMap { quizzes(in: $0.blocks) }
    }
}

private struct EditorContextKey: EnvironmentKey {
    static let defaultValue = EditorContext()
}

extension EnvironmentValues {
    var editorContext: EditorContext {
        get { self[EditorContextKey.self] }
        set { self[EditorContextKey.self] = newValue }
    }
}
