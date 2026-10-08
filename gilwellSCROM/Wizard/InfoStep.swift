//
//  InfoStep.swift
//  gilwellSCROM
//
//  Wizard step 2: content identification.
//

import Foundation
import SwiftUI

struct InfoStep: View {
    @Binding var draft: WizardDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("About the content")
                .font(.title3.bold())
            Text("You can change all of this later under “General”. Blank fields keep the template's default text.")
                .foregroundStyle(.secondary)

            field("Label (appears above the title)", "e.g. Case study with variations", $draft.label)
            field("Title", "e.g. Sexualized behavior among young people", $draft.title)
            field("Subtitle", "e.g. How to act and what changes in each situation", $draft.subtitle)
        }
    }

    private func field(_ label: String, _ hint: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.callout.bold())
            TextField(hint, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }
}
