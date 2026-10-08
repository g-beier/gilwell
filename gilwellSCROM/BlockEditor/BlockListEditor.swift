//
//  BlockListEditor.swift
//  gilwellSCROM
//
//  The stack of blocks inside a section (or inside a “Reveal” block): each block is a card that can be
//  expanded, moved, duplicated and deleted, and new blocks are added from a menu.
//

import Foundation
import SwiftUI

struct BlockListEditor: View {
    @Binding var blocks: [Block]
    @Environment(\.editorContext) private var context

    @State private var expanded: Set<String> = []
    @State private var pendingDeletion: String?

    private let placeholder = Block(id: "placeholder", data: .empty(.highlight))

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if blocks.isEmpty {
                Text("No blocks yet. Add the first one below.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(blocks) { block in
                card(for: block.id)
            }
            Menu {
                ForEach(BlockType.allCases, id: \.self) { type in
                    Button {
                        add(type)
                    } label: {
                        Label("\(type.name) — \(type.summary)", systemImage: type.icon)
                    }
                    .disabled(type.requiresVariations && !context.hasVariations)
                }
            } label: {
                Label("Add block", systemImage: "plus.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .confirmationDialog(
            "Delete this block?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })
        ) {
            Button("Delete", role: .destructive) {
                if let id = pendingDeletion { blocks.removeAll { $0.id == id } }
                pendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("Buttons or reveals that depend on it will be flagged in the checks.")
        }
    }

    // MARK: - One block

    @ViewBuilder
    private func card(for id: String) -> some View {
        let binding = blockBinding(id)
        let block = binding.wrappedValue
        let index = blocks.firstIndex(where: { $0.id == id }) ?? 0
        GroupBox {
            DisclosureGroup(isExpanded: Binding(
                get: { expanded.contains(id) },
                set: { if $0 { expanded.insert(id) } else { expanded.remove(id) } }
            )) {
                VStack(alignment: .leading, spacing: 10) {
                    BlockForm(data: binding.data)
                    Text("Block ID: \(block.id)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
                .padding(.top, 8)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: block.type.icon)
                        .frame(width: 20)
                    Text(block.type.name)
                        .fontWeight(.semibold)
                    Text(block.summaryLine)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    OrderButtons(
                        canMoveUp: index > 0,
                        canMoveDown: index < blocks.count - 1,
                        moveUp: { blocks.swapAt(index, index - 1) },
                        moveDown: { blocks.swapAt(index, index + 1) },
                        delete: { pendingDeletion = id }
                    )
                    Button {
                        duplicate(id)
                    } label: {
                        Image(systemName: "plus.square.on.square")
                    }
                    .buttonStyle(.borderless)
                    .help("Duplicate this block")
                }
            }
            .padding(4)
        }
    }

    /// Binding by identifier, so it stays valid while neighbours are moved or deleted.
    private func blockBinding(_ id: String) -> Binding<Block> {
        Binding<Block>(
            get: { blocks.first(where: { $0.id == id }) ?? placeholder },
            set: { updated in
                if let i = blocks.firstIndex(where: { $0.id == id }) { blocks[i] = updated }
            }
        )
    }

    // MARK: - Actions

    private func add(_ type: BlockType) {
        let block = Block(data: .empty(type))
        blocks.append(block)
        expanded.insert(block.id)
    }

    private func duplicate(_ id: String) {
        guard let i = blocks.firstIndex(where: { $0.id == id }) else { return }
        let copy = blocks[i].duplicated()
        blocks.insert(copy, at: i + 1)
        expanded.insert(copy.id)
    }
}
