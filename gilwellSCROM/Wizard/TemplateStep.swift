//
//  TemplateStep.swift
//  gilwellSCROM
//
//  Wizard step 1: choose the SCORM template.
//

import Foundation
import SwiftUI

struct TemplateStep: View {
    @Binding var selection: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What kind of SCORM do you want to build?")
                .font(.title3.bold())
            Text("Each template defines what the learner sees and which fields you fill in. New templates will be added to this list.")
                .foregroundStyle(.secondary)

            ForEach(Templates.all) { template in
                TemplateCard(template: template, selected: selection == template.id) {
                    selection = template.id
                }
            }
        }
        .onAppear {
            // With a single template available, it comes preselected.
            if selection == nil, Templates.all.count == 1 {
                selection = Templates.all.first?.id
            }
        }
    }
}

private struct TemplateCard: View {
    let template: ScormTemplate
    let selected: Bool
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: template.icon)
                    .font(.system(size: 28))
                    .frame(width: 40)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 6) {
                    Text(template.name).font(.headline)
                    Text(template.summary)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(template.highlights, id: \.self) { d in
                            Label(d, systemImage: "checkmark")
                                .font(.callout)
                        }
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selected ? Color.accentColor.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: selected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
