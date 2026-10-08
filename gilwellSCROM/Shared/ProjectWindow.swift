//
//  ProjectWindow.swift
//  gilwellSCROM
//
//  The common “frame” for all templates: sidebar + editor + live preview,
//  export button and export alerts. Each template supplies only the sidebar and the editor.
//

import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ProjectWindow<Sidebar: View, Detail: View>: View {
    @Binding var document: GilwellDocument
    /// Project problems, computed by the template. Errors block the export.
    let findings: [Finding]
    /// Called when the export is blocked by errors (the template takes the author to the problem list).
    let onBlock: () -> Void
    private let sidebar: Sidebar
    private let detail: Detail

    @State private var showPreview = true
    /// Width of the preview column. Kept by the app, so navigating between editors never changes it.
    @AppStorage("previewWidth") private var previewWidth = 460.0
    @State private var dragStartWidth: Double?
    private let minPreviewWidth = 280.0
    private let maxPreviewWidth = 900.0
    /// Dragging the divider below this width retracts the preview.
    private let retractBelow = 180.0
    @StateObject private var preview = PreviewController()

    @State private var exporting = false
    @State private var zipToExport = ZipDocument()
    @State private var errorMessage: String?
    @State private var exported: String?

    init(
        document: Binding<GilwellDocument>,
        findings: [Finding],
        onBlock: @escaping () -> Void,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder detail: () -> Detail
    ) {
        self._document = document
        self.findings = findings
        self.onBlock = onBlock
        self.sidebar = sidebar()
        self.detail = detail()
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            HStack(spacing: 0) {
                detail
                    .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                if showPreview {
                    divider
                    PreviewPanel(project: document.project, controller: preview)
                        .frame(width: CGFloat(previewWidth))
                        .frame(maxHeight: .infinity)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    showPreview.toggle()
                } label: {
                    Label("Preview", systemImage: "sidebar.right")
                }
                .help("Show or hide the preview (or drag its divider to the right edge)")
                .keyboardShortcut("p", modifiers: [.command, .option])

                Button {
                    export()
                } label: {
                    Label("Export SCORM…", systemImage: "square.and.arrow.up")
                }
                .help("Generates the .zip package to upload to Moodle")
            }
        }
        .fileExporter(
            isPresented: $exporting,
            document: zipToExport,
            contentType: .zip,
            defaultFilename: suggestedName
        ) { result in
            switch result {
            case .success(let url):
                exported = url.lastPathComponent
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .alert("Could not export", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Package exported", isPresented: Binding(
            get: { exported != nil },
            set: { if !$0 { exported = nil } }
        )) {
            Button("OK", role: .cancel) { exported = nil }
        } message: {
            Text("\(exported ?? "") is ready. In Moodle: Add an activity > SCORM package, and upload the .zip without unzipping it.")
        }
    }

    /// Draggable divider between the editor and the preview. Drag it to the right edge to retract the preview.
    private var divider: some View {
        Color.clear
            .frame(width: 9)
            .overlay(Divider())
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { NSCursor.resizeLeftRight.set() } else { NSCursor.arrow.set() }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        let start = dragStartWidth ?? previewWidth
                        dragStartWidth = start
                        let proposed = start - Double(value.translation.width)
                        previewWidth = min(max(proposed, minPreviewWidth), maxPreviewWidth)
                    }
                    .onEnded { value in
                        let start = dragStartWidth ?? previewWidth
                        dragStartWidth = nil
                        if start - Double(value.translation.width) < retractBelow {
                            showPreview = false
                            previewWidth = max(previewWidth, minPreviewWidth)
                        }
                    }
            )
            .help("Drag to resize; drag all the way right to retract the preview")
    }

    private var suggestedName: String {
        ScormBuilder.fileName(document.project.content.title,
                                   standard: Templates.find(document.project.template)?.defaultFileName ?? "scorm")
    }

    private func export() {
        if Validator.hasErrors(findings) {
            onBlock()
            errorMessage = "Fix the errors under “Verification” before exporting."
            return
        }
        do {
            zipToExport = ZipDocument(data: try ScormBuilder.zip(document.project))
            exporting = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
