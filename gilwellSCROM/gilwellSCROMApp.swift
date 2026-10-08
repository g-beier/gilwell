//
//  gilwellSCROMApp.swift
//  gilwellSCROM
//
//  Document-based app: each case study is a .gilwell file.
//

import SwiftUI

@main
struct gilwellSCROMApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: GilwellDocument()) { file in
            ContentView(document: file.$document)
        }
        .defaultSize(width: 1280, height: 780)
    }
}
