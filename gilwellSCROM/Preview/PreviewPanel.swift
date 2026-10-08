//
//  PreviewPanel.swift
//  gilwellSCROM
//
//  Side panel: the package actually running, at phone, pop-up or desktop widths,
//  and a summary of what the simulated Moodle received (status, progress, reflections).
//

import Foundation
import SwiftUI

private enum PreviewWidth: String, CaseIterable, Identifiable {
    case phone = "Phone"
    case popup = "Pop-up"
    case desktop = "Desktop"

    var id: String { rawValue }

    /// Fixed width in points; nil = fills the whole panel.
    var width: CGFloat? {
        switch self {
        case .phone: return 390
        case .popup: return 640
        case .desktop: return nil
        }
    }
}

struct PreviewPanel: View {
    let project: Project
    @ObservedObject var controller: PreviewController

    @State private var width: PreviewWidth = .popup
    @State private var showLog = true

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            ZStack {
                Color(nsColor: .underPageBackgroundColor)
                WebViewContainer(controller: controller)
                    .frame(maxWidth: width.width ?? .infinity)
                    .shadow(radius: 2)
                if let error = controller.error {
                    Text(error)
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .padding()
                }
            }
            Divider()
            log
        }
        .task(id: project) {
            // Reloads half a second after the last edit, keeping the simulated learner's progress.
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            controller.load(project)
        }
    }

    // MARK: - Parts

    private var topBar: some View {
        HStack {
            Picker("Width", selection: $width) {
                ForEach(PreviewWidth.allCases) { l in
                    Text(l.rawValue).tag(l)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 260)
            Spacer()
            Button {
                controller.load(project)
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }
            .help("Reloads the preview, keeping the simulated learner's progress")
            Button {
                controller.reset(project)
            } label: {
                Label("Reset learner", systemImage: "arrow.counterclockwise")
            }
            .help("Clears the simulated learner's progress and starts over")
        }
        .labelStyle(.titleAndIcon)
        .padding(8)
    }

    private var log: some View {
        DisclosureGroup(isExpanded: $showLog) {
            VStack(alignment: .leading, spacing: 6) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                    GridRow {
                        Text("Moodle status").foregroundStyle(.secondary)
                        Label(controller.readableStatus, systemImage: statusIcon)
                            .foregroundStyle(statusColor)
                    }
                    GridRow {
                        Text("Variations revealed").foregroundStyle(.secondary)
                        Text("\(controller.variationsSeen) of \(project.content.variations.count)")
                    }
                    GridRow {
                        Text("Reflections submitted").foregroundStyle(.secondary)
                        Text("\(controller.reflectionsSent)")
                    }
                    if !controller.sessionTime.isEmpty {
                        GridRow {
                            Text("Session time").foregroundStyle(.secondary)
                            Text(controller.sessionTime)
                        }
                    }
                }
                .font(.callout)

                ForEach(controller.alerts, id: \.self) { a in
                    Label(a, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if !controller.interactions.isEmpty {
                    Text("Recorded answers (Interactions report)")
                        .font(.caption.bold())
                        .padding(.top, 4)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(controller.interactions) { i in
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(i.name).font(.caption.monospaced())
                                    Text(i.answer)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 110)
                }
            }
            .padding(.top, 6)
        } label: {
            Text("Simulated Moodle").font(.callout.bold())
        }
        .padding(10)
    }

    private var statusIcon: String {
        switch controller.status {
        case "completed", "passed": return "checkmark.circle.fill"
        case "incomplete": return "clock"
        default: return "circle"
        }
    }

    private var statusColor: Color {
        switch controller.status {
        case "completed", "passed": return .green
        case "incomplete": return .orange
        default: return .secondary
        }
    }
}
