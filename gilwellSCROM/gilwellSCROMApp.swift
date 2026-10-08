//
//  gilwellSCROMApp.swift
//  gilwellSCROM
//
//  Created by Gustav Beier on 08/10/26.
//

import SwiftUI
import CoreData

@main
struct gilwellSCROMApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
