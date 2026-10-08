//
//  EditorComponents.swift
//  gilwellSCROM
//
//  Pieces reused by the editors: an editable list of texts and a block with title + items.
//

import Foundation
import SwiftUI

extension Binding {
    /// Binding to an array element that does not crash if the index stops existing in the middle of a
    /// screen update (which happens right after a row is deleted).
    func element<T>(_ i: Int, standard: T) -> Binding<T> where Value == [T] {
        Binding<T>(
            get: {
                let list = self.wrappedValue
                return i < list.count ? list[i] : standard
            },
            set: { created in
                var list = self.wrappedValue
                if i < list.count {
                    list[i] = created
                    self.wrappedValue = list
                }
            }
        )
    }
}

/// Editable rows of a text list, with move up, move down and delete. Use inside a `Section`.
struct TextLines: View {
    @Binding var items: [String]
    var addLabel = "Add item"
    var hint = "Item text"

    var body: some View {
        ForEach(Array(items.indices), id: \.self) { i in
            HStack(alignment: .top, spacing: 8) {
                TextField(hint, text: $items.element(i, standard: ""), axis: .vertical)
                    .lineLimit(1...8)
                    .textFieldStyle(.roundedBorder)
                OrderButtons(
                    canMoveUp: i > 0,
                    canMoveDown: i < items.count - 1,
                    moveUp: { items.swapAt(i, i - 1) },
                    moveDown: { items.swapAt(i, i + 1) },
                    delete: { items.remove(at: i) }
                )
            }
        }
        Button {
            items.append("")
        } label: {
            Label(addLabel, systemImage: "plus.circle")
        }
        .buttonStyle(.borderless)
    }
}

/// Compact reorder buttons used in list rows.
struct OrderButtons: View {
    var canMoveUp: Bool
    var canMoveDown: Bool
    var moveUp: () -> Void
    var moveDown: () -> Void
    var delete: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Button(action: moveUp) { Image(systemName: "chevron.up") }
                .disabled(!canMoveUp)
                .help("Move up")
            Button(action: moveDown) { Image(systemName: "chevron.down") }
                .disabled(!canMoveDown)
                .help("Move down")
            Button(role: .destructive, action: delete) { Image(systemName: "trash") }
                .help("Delete")
        }
        .buttonStyle(.borderless)
        .labelStyle(.iconOnly)
    }
}

/// Section for a list of “title + items” blocks (e.g. the case's supporting points, a variation's extra blocks).
struct BlockSections: View {
    @Binding var blocks: [ListBlock]
    var blockLabel = "Block"
    var addLabel = "Add block"

    var body: some View {
        ForEach(Array(blocks.indices), id: \.self) { i in
            let block = $blocks.element(i, standard: ListBlock(title: "", items: []))
            Section {
                TextField("Block title", text: block.title)
                    .textFieldStyle(.roundedBorder)
                TextLines(items: block.items)
                HStack {
                    OrderButtons(
                        canMoveUp: i > 0,
                        canMoveDown: i < blocks.count - 1,
                        moveUp: { blocks.swapAt(i, i - 1) },
                        moveDown: { blocks.swapAt(i, i + 1) },
                        delete: { blocks.remove(at: i) }
                    )
                    Text("Move or delete this block")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("\(blockLabel) \(i + 1)")
            }
        }
        Section {
            Button {
                blocks.append(ListBlock(title: "", items: [""]))
            } label: {
                Label(addLabel, systemImage: "plus.circle")
            }
            .buttonStyle(.borderless)
        }
    }
}

/// Explanatory header at the top of each editor.
struct EditorHeader: View {
    var title: String
    var explanation: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2.bold())
            Text(explanation)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}
