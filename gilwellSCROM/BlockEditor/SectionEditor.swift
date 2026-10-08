//
//  SectionEditor.swift
//  gilwellSCROM
//
//  Editor of one section (one page of the package): its titles and the blocks inside it.
//

import Foundation
import SwiftUI

struct SectionEditor: View {
    @Binding var section: ScormSection
    let position: Int
    let total: Int
    let hasVariations: Bool
    let allSections: [ScormSection]
    var moveUp: () -> Void
    var moveDown: () -> Void
    var delete: () -> Void

    @State private var confirmingDeletion = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                EditorHeader(
                    title: section.title.isEmpty ? "Untitled section" : section.title,
                    explanation: "A section is one page of the package, with its own item in the learner's menu. Stack blocks inside it."
                )

                GroupBox("Section") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledField(label: "Page title") {
                            TextField("Title", text: $section.title)
                                .textFieldStyle(.roundedBorder)
                        }
                        LabeledField(label: "Menu label (empty = uses the title)") {
                            TextField("Menu label", text: $section.menuLabel)
                                .textFieldStyle(.roundedBorder)
                        }
                        LabeledField(label: "Opening sentence (optional)") {
                            TextField("Introduction", text: $section.intro, axis: .vertical)
                                .lineLimit(1...4)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            Button { moveUp() } label: { Label("Move up", systemImage: "chevron.up") }
                                .disabled(position == 0)
                            Button { moveDown() } label: { Label("Move down", systemImage: "chevron.down") }
                                .disabled(position >= total - 1)
                            Spacer()
                            Button(role: .destructive) { confirmingDeletion = true } label: {
                                Label("Delete section", systemImage: "trash")
                            }
                        }
                    }
                    .padding(4)
                }

                Text("Blocks")
                    .font(.headline)
                BlockListEditor(blocks: $section.blocks)
            }
            .padding(20)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .environment(\.editorContext, EditorContext(sections: allSections, hasVariations: hasVariations))
        .confirmationDialog("Delete this section?", isPresented: $confirmingDeletion) {
            Button("Delete", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The section and all its blocks are removed. Buttons that pointed to it will be flagged in the checks.")
        }
    }
}
