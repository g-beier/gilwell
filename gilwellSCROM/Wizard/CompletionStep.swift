//
//  CompletionStep.swift
//  gilwellSCROM
//
//  Wizard step 3: starting point (blank or example) and Moodle completion rules.
//

import Foundation
import SwiftUI

struct CompletionStep: View {
    @Binding var draft: WizardDraft
    let template: ScormTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Starting point and completion")
                .font(.title3.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text("Start with").font(.callout.bold())
                Picker("Start with", selection: $draft.startingPoint) {
                    Text("Blank project").tag(WizardDraft.StartingPoint.blank)
                    if template.examplePath != nil {
                        Text("Complete example").tag(WizardDraft.StartingPoint.example)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                if draft.startingPoint == .example {
                    Text(template.exampleDescription + ". Good for seeing how everything works, then replacing the content.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text("A minimal skeleton, with one variation for you to rewrite.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("When does Moodle mark it as completed?").font(.callout.bold())
                Toggle("The learner must open all the variations", isOn: $draft.requireAllVariations)
                if !draft.requireAllVariations {
                    Stepper("Variations required: \(draft.requiredVariations)",
                            value: $draft.requiredVariations, in: 1...50)
                }
                Stepper(draft.requiredReflections == 0
                        ? "Reflections required: none (optional)"
                        : "Reflections required: \(draft.requiredReflections)",
                        value: $draft.requiredReflections, in: 0...20)
                Text("Can be adjusted later under “Settings”.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
