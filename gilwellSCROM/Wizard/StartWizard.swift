//
//  StartWizard.swift
//  gilwellSCROM
//
//  Wizard shown for every new project: 1) choose the template, 2) basic information,
//  3) starting point and completion rules. When finished, it writes the project to the document.
//

import Foundation
import SwiftUI

struct StartWizard: View {
    @Binding var document: GilwellDocument

    private enum Step: Int, CaseIterable {
        case template, info, completion

        var title: String {
            switch self {
            case .template: return "Template"
            case .info: return "Information"
            case .completion: return "Completion"
            }
        }
    }

    @State private var step: Step = .template
    @State private var draft = WizardDraft()
    @State private var errorMessage: String?

    private var template: ScormTemplate? {
        draft.templateID.flatMap { Templates.find($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                contentStep
                    .frame(maxWidth: 680, alignment: .leading)
                    .padding(28)
                    .frame(maxWidth: .infinity)
            }
            Divider()
            footer
        }
        .frame(minWidth: 640, minHeight: 520)
        .alert("Could not create the project", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Parts

    private var header: some View {
        VStack(spacing: 10) {
            Text("New SCORM package")
                .font(.title2.bold())
            HStack(spacing: 8) {
                ForEach(Step.allCases, id: \.rawValue) { p in
                    HStack(spacing: 6) {
                        Image(systemName: p.rawValue < step.rawValue ? "checkmark.circle.fill" : "\(p.rawValue + 1).circle\(p == step ? ".fill" : "")")
                        Text(p.title)
                    }
                    .font(.callout)
                    .foregroundStyle(p == step ? Color.accentColor : Color.secondary)
                    if p != Step.allCases.last {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var contentStep: some View {
        switch step {
        case .template:
            TemplateStep(selection: $draft.templateID)
        case .info:
            InfoStep(draft: $draft)
        case .completion:
            if let template {
                CompletionStep(draft: $draft, template: template)
            }
        }
    }

    private var footer: some View {
        HStack {
            if step != .template {
                Button("Back") { go(-1) }
            }
            Spacer()
            if step == .completion {
                Button("Create project") { create() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Continue") { go(1) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(template == nil)
            }
        }
        .padding(14)
    }

    // MARK: - Actions

    private func go(_ offset: Int) {
        if let created = Step(rawValue: step.rawValue + offset) {
            step = created
        }
    }

    private func create() {
        do {
            document.project = try ProjectBuilder.create(draft)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
