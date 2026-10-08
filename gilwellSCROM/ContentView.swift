//
//  ContentView.swift
//  gilwellSCROM
//
//  Window entry point: new project → initial wizard; project with a template → the template's screen.
//  To register a new template, add an `if` below (and its entry in `Templates`).
//

import Foundation
import SwiftUI

struct ContentView: View {
    @Binding var document: GilwellDocument

    var body: some View {
        let id = document.project.template
        if id.isEmpty {
            StartWizard(document: $document)
        } else if id == Templates.caseStudy.id {
            CaseStudyView(document: $document)
        } else {
            ContentUnavailableView(
                "Unknown template",
                systemImage: "questionmark.folder",
                description: Text("This file uses the template “\(id)”, which this version of the app does not recognize. Update the app to open it.")
            )
        }
    }
}

#Preview {
    ContentView(document: .constant(GilwellDocument()))
}
