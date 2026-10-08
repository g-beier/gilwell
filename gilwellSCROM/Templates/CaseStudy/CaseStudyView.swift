//
//  CaseStudyView.swift
//  gilwellSCROM
//
//  “Case study with variations” template: the sidebar with the parts of the case and the editor for each one.
//  The frame (preview, export) comes from `ProjectWindow`.
//

import Foundation
import SwiftUI

/// Sidebar items of the case study.
enum SidebarItem: Hashable {
    case general, baseCase, quiz, flow, themes, synthesis, settings, verification
    /// A theme in the sublist (opens the themes editor).
    case theme(String)
    case variation(UUID)
    /// A free-form section (when the project uses custom sections).
    case section(String)
}

struct CaseStudyView: View {
    @Binding var document: GilwellDocument

    @State private var selection: SidebarItem? = .general
    @State private var themesExpanded = true
    @State private var sectionsExpanded = true

    private var project: Binding<Project> { $document.project }
    private var findings: [Finding] { Validator.validate(document.project) }

    var body: some View {
        ProjectWindow(
            document: $document,
            findings: findings,
            onBlock: { selection = .verification }
        ) {
            sidebar
        } detail: {
            detail
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            Section("Content") {
                Label("General", systemImage: "doc.text").tag(SidebarItem.general)
                if let sections = document.project.customSections {
                    // Free-form structure: the author's own sections, each with its blocks.
                    DisclosureGroup(isExpanded: $sectionsExpanded) {
                        ForEach(sections, id: \.id) { section in
                            Label(section.effectiveLabel.isEmpty ? "Untitled section" : section.effectiveLabel, systemImage: "doc.richtext")
                                .lineLimit(2)
                                .tag(SidebarItem.section(section.id))
                                .contextMenu {
                                    Button("Delete section", role: .destructive) { deleteSection(section.id) }
                                }
                        }
                    } label: {
                        HStack {
                            Label("Sections", systemImage: "rectangle.stack")
                            Spacer(minLength: 4)
                            Button {
                                addSection()
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                            .buttonStyle(.borderless)
                            .help("New section")
                        }
                    }
                } else {
                    Label("Base case", systemImage: "text.book.closed").tag(SidebarItem.baseCase)
                    Label("Quiz", systemImage: "checklist").tag(SidebarItem.quiz)
                    Label("Basic flow", systemImage: "list.number").tag(SidebarItem.flow)
                }

                // Themes are a sublist of “Content”; each theme opens the list of its variations.
                DisclosureGroup(isExpanded: $themesExpanded) {
                    ForEach(document.project.content.themes) { theme in
                        DisclosureGroup {
                            ForEach(document.project.content.variations.filter { $0.theme == theme.id }) { v in
                                Label("\(v.number). \(v.title.isEmpty ? "Untitled" : v.title)", systemImage: "arrow.triangle.branch")
                                    .lineLimit(2)
                                    .tag(SidebarItem.variation(v.uid))
                            }
                        } label: {
                            HStack {
                                Label(theme.title.isEmpty ? "Untitled theme" : theme.title, systemImage: "folder")
                                    .lineLimit(2)
                                Spacer(minLength: 4)
                                Button {
                                    addVariation(in: theme.id)
                                } label: {
                                    Image(systemName: "plus.circle")
                                }
                                .buttonStyle(.borderless)
                                .help("New variation in this theme")
                            }
                            .tag(SidebarItem.theme(theme.id))
                            .contextMenu {
                                Button("New variation in this theme") { addVariation(in: theme.id) }
                            }
                        }
                    }

                    // Variations whose theme was removed or never existed.
                    let ids = Set(document.project.content.themes.map(\.id))
                    let orphans = document.project.content.variations.filter { !ids.contains($0.theme) }
                    if !orphans.isEmpty {
                        DisclosureGroup {
                            ForEach(orphans) { v in
                                Label("\(v.number). \(v.title)", systemImage: "exclamationmark.triangle")
                                    .tag(SidebarItem.variation(v.uid))
                            }
                        } label: {
                            Label("No theme", systemImage: "exclamationmark.triangle")
                        }
                    }
                } label: {
                    HStack {
                        Label("Themes", systemImage: "square.grid.2x2")
                        Spacer(minLength: 4)
                        Button {
                            addTheme()
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("New theme")
                    }
                    .tag(SidebarItem.themes)
                }

                if document.project.customSections == nil {
                    Label("Synthesis", systemImage: "flag.checkered").tag(SidebarItem.synthesis)
                }
            }

            Section("Project") {
                Label("Settings", systemImage: "gearshape").tag(SidebarItem.settings)
                Label {
                    Text("Checks")
                } icon: {
                    Image(systemName: Validator.hasErrors(findings) ? "xmark.octagon" : (findings.isEmpty ? "checkmark.seal" : "exclamationmark.triangle"))
                }
                .badge(findings.count)
                .tag(SidebarItem.verification)
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selection ?? .general {
        case .general:
            GeneralEditor(project: project)
        case .baseCase:
            BaseCaseEditor(project: project)
        case .quiz:
            QuizEditor(project: project)
        case .flow:
            FlowEditor(project: project)
        case .themes, .theme:
            ThemesEditor(project: project)
        case .synthesis:
            SynthesisEditor(project: project)
        case .settings:
            SettingsEditor(project: project, convertToSections: convertToSections)
        case .verification:
            FindingsPanel(findings: findings)
        case .section(let id):
            if let index = document.project.customSections?.firstIndex(where: { $0.id == id }) {
                SectionEditor(
                    section: sectionBinding(id),
                    position: index,
                    total: document.project.customSections?.count ?? 0,
                    hasVariations: !document.project.content.variations.isEmpty,
                    allSections: document.project.customSections ?? [],
                    moveUp: { moveSection(id, by: -1) },
                    moveDown: { moveSection(id, by: 1) },
                    delete: { deleteSection(id) }
                )
                .id(id)
            } else {
                ContentUnavailableView("Section not found", systemImage: "questionmark.folder")
            }
        case .variation(let uid):
            if document.project.content.variations.contains(where: { $0.uid == uid }) {
                VariationEditor(
                    variation: variationBinding(uid),
                    themes: document.project.content.themes,
                    delete: { deleteVariation(uid) }
                )
                .id(uid)
            } else {
                ContentUnavailableView("Variation not found", systemImage: "questionmark.folder")
            }
        }
    }

    /// Binding by identifier (not by position), so it does not break if the variation is deleted in the middle of an update.
    private func variationBinding(_ uid: UUID) -> Binding<Variation> {
        let empty = Variation(number: 0, theme: "", title: "", whatIf: "", changes: [], staysSame: [], synthesis: "", question: "")
        return Binding<Variation>(
            get: {
                document.project.content.variations.first(where: { $0.uid == uid }) ?? empty
            },
            set: { created in
                if let i = document.project.content.variations.firstIndex(where: { $0.uid == uid }) {
                    document.project.content.variations[i] = created
                }
            }
        )
    }

    /// Binding by identifier, so it survives reordering and deletion.
    private func sectionBinding(_ id: String) -> Binding<ScormSection> {
        let empty = ScormSection(id: id, title: "")
        return Binding<ScormSection>(
            get: {
                document.project.customSections?.first(where: { $0.id == id }) ?? empty
            },
            set: { updated in
                if let i = document.project.customSections?.firstIndex(where: { $0.id == id }) {
                    document.project.customSections?[i] = updated
                }
            }
        )
    }

    // MARK: - Actions

    private func convertToSections() {
        let sections = V1Converter.convert(document.project).sections
        document.project.customSections = sections
        selection = sections.first.map { .section($0.id) } ?? .general
    }

    private func addSection() {
        let created = ScormSection(id: ScormSection.newID(), title: "New section", menuLabel: "", intro: "", blocks: [])
        document.project.customSections?.append(created)
        sectionsExpanded = true
        selection = .section(created.id)
    }

    private func deleteSection(_ id: String) {
        document.project.customSections?.removeAll { $0.id == id }
        selection = .general
    }

    private func moveSection(_ id: String, by offset: Int) {
        guard var sections = document.project.customSections,
              let i = sections.firstIndex(where: { $0.id == id }) else { return }
        let target = i + offset
        guard sections.indices.contains(target) else { return }
        sections.swapAt(i, target)
        document.project.customSections = sections
    }

    /// Creates a variation inside the given theme, with the next free number.
    private func addVariation(in theme: String) {
        let nextNumber = (document.project.content.variations.map(\.number).max() ?? 0) + 1
        let created = Variation(
            number: nextNumber, theme: theme,
            title: "New variation", whatIf: "E se...?",
            changes: [""], staysSame: [""],
            synthesis: "", question: ""
        )
        document.project.content.variations.append(created)
        themesExpanded = true
        selection = .variation(created.uid)
    }

    private func addTheme() {
        let existing = Set(document.project.content.themes.map(\.id))
        var n = document.project.content.themes.count + 1
        while existing.contains("theme-\(n)") { n += 1 }
        let created = Theme(id: "theme-\(n)", title: "New theme", description: "")
        document.project.content.themes.append(created)
        themesExpanded = true
        selection = .theme(created.id)
    }

    private func deleteVariation(_ uid: UUID) {
        document.project.content.variations.removeAll { $0.uid == uid }
        selection = .general
    }
}
