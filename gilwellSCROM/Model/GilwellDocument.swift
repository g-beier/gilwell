//
//  GilwellDocument.swift
//  gilwellSCROM
//
//  App document: a `.gilwell` file (JSON) holding the project. Plus the document for the exported ZIP.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Declared in `Info-Gilwell.plist` (UTExportedTypeDeclarations). Conforms to JSON.
    nonisolated static let gilwellProject = UTType(exportedAs: "xyz.gustavbeier.gilwell.project", conformingTo: .json)
}

nonisolated struct GilwellDocument: FileDocument {
    var project: Project

    static var readableContentTypes: [UTType] { [.gilwellProject] }
    static var writableContentTypes: [UTType] { [.gilwellProject] }

    /// New document: no template chosen; the initial wizard asks and fills it in.
    init(project: Project = .created(template: "")) {
        self.project = project
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        project = try JSONDecoder().decode(Project.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return FileWrapper(regularFileWithContents: try encoder.encode(project))
    }
}

/// Document used only to save the .zip through the export panel.
nonisolated struct ZipDocument: FileDocument {
    var data: Data

    static var readableContentTypes: [UTType] { [.zip] }
    static var writableContentTypes: [UTType] { [.zip] }

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
