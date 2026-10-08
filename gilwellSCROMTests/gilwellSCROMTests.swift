//
//  gilwellSCROMTests.swift
//  gilwellSCROMTests
//
//  Tests for everything that does not depend on the UI: ZIP, SCORM package, validation and file format.
//

import XCTest
@testable import gilwellSCROM

final class gilwellSCROMTests: XCTestCase {

    // MARK: - ZIP

    func testCRC32StandardValue() {
        // Reference CRC-32 value for "123456789".
        XCTAssertEqual(ZipWriter.crc32(Data("123456789".utf8)), 0xCBF43926)
    }

    func testZipHasValidStructure() throws {
        var zip = ZipWriter()
        zip.add("imsmanifest.xml", Data("<manifest/>".utf8))
        zip.add("css/style.css", Data("body{}".utf8))
        let data = zip.build()
        let bytes = [UInt8](data)

        // Starts with the signature of the first local header.
        XCTAssertEqual(Array(bytes[0..<4]), [0x50, 0x4B, 0x03, 0x04])

        // End of central directory: 22 bytes, no comment.
        let end = bytes.count - 22
        XCTAssertEqual(Array(bytes[end..<(end + 4)]), [0x50, 0x4B, 0x05, 0x06])
        let entries = Int(bytes[end + 10]) | (Int(bytes[end + 11]) << 8)
        XCTAssertEqual(entries, 2)

        // The central directory offset points to the 0x02014b50 signature.
        let offset = Int(bytes[end + 16]) | (Int(bytes[end + 17]) << 8) | (Int(bytes[end + 18]) << 16) | (Int(bytes[end + 19]) << 24)
        XCTAssertEqual(Array(bytes[offset..<(offset + 4)]), [0x50, 0x4B, 0x01, 0x02])
    }

    func testZipWritesToDisk() throws {
        var zip = ZipWriter()
        zip.add("a.txt", Data("héllo".utf8))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID().uuidString).zip")
        try zip.build().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        // Checks that the file is written in full (the signatures are already checked in the previous test).
        let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
        XCTAssertGreaterThan(size, 22)
    }

    // MARK: - Package

    func testPackageHasAllFiles() throws {
        let files = try ScormBuilder.build(.created())
        let paths = Set(files.map(\.path))
        for expected in Templates.caseStudy.runtimeFiles + ["js/data.js", "imsmanifest.xml"] {
            XCTAssertTrue(paths.contains(expected), "missing \(expected)")
        }
    }

    func testManifestListsPackageFiles() throws {
        let files = try ScormBuilder.build(.created())
        let manifest = String(decoding: files.first(where: { $0.path == "imsmanifest.xml" })!.data, as: UTF8.self)
        XCTAssertTrue(manifest.contains("<schemaversion>1.2</schemaversion>"))
        XCTAssertTrue(manifest.contains("href=\"index.html\""))
        for a in files where a.path != "imsmanifest.xml" {
            XCTAssertTrue(manifest.contains("<file href=\"\(a.path)\"/>"), "manifest missing \(a.path)")
        }
    }

    func testDataJSContainsSectionsBlocksAndCompletion() throws {
        var project = Project.created()
        project.config.requiredReflections = 3
        let data = try ScormBuilder.dataJS(project)
        var text = String(decoding: data, as: UTF8.self)
        let home = try XCTUnwrap(text.range(of: "var STRUCTURE = "))
        text = String(text[home.upperBound...])
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: ";\n "))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])

        let sections = try XCTUnwrap(object["sections"] as? [[String: Any]])
        XCTAssertEqual(sections.compactMap { $0["id"] as? String }, ["home", "baseCase", "flow", "variations", "synthesis", "references"])
        let first = try XCTUnwrap((sections.first?["blocks"] as? [[String: Any]])?.first)
        XCTAssertEqual(first["type"] as? String, "alert")
        let variations = try XCTUnwrap((object["variations"] as? [String: Any])?["variations"] as? [[String: Any]])
        XCTAssertEqual(variations.first?["id"] as? Int, 1)
        let completion = try XCTUnwrap(object["completion"] as? [String: Any])
        XCTAssertEqual(completion["requiredReflections"] as? Int, 3)
    }

    func testFileName() {
        XCTAssertEqual(ScormBuilder.fileName("Café culture: protection!"), "cafe-culture-protection-scorm")
        XCTAssertEqual(ScormBuilder.fileName("   "), "case-study")
    }

    // MARK: - File format

    func testProjectSurvivesWriteCycle() throws {
        let original = Project.created()
        let data = try JSONEncoder().encode(original)
        let read = try JSONDecoder().decode(Project.self, from: data)
        // The internal identifiers (uid) are regenerated; the editable content is the same.
        XCTAssertEqual(read.content.title, original.content.title)
        XCTAssertEqual(read.content.variations.map(\.number), original.content.variations.map(\.number))
        XCTAssertEqual(read.content.quiz.options.map(\.text), original.content.quiz.options.map(\.text))
        XCTAssertEqual(read.texts, original.texts)
        XCTAssertEqual(read.config, original.config)
    }

    func testLegacyFileWithoutTextsOrConfigStillOpens() throws {
        // Minimal format: only `content`. `texts` and `config` take default values; `extra` may be missing from the variations.
        let json = """
        {"content":{"label":"","title":"T","subtitle":"","objectives":[],"baseCase":[],"triggerQuestion":"",
        "reflectionNotice":"","quiz":{"prompt":"","options":[]},"caseSupport":[],"flow":[{"title":"E","items":[]}],
        "donts":[],"themes":[{"id":"g","title":"G","description":""}],
        "variations":[{"id":7,"theme":"g","title":"V","whatIf":"","changes":[],"staysSame":[],"synthesis":"","question":""}],
        "principles":[],"takeaways":[],"references":[]}}
        """
        let project = try JSONDecoder().decode(Project.self, from: Data(json.utf8))
        XCTAssertEqual(project.content.variations.first?.number, 7)
        XCTAssertEqual(project.content.variations.first?.extra.count, 0)
        XCTAssertEqual(project.config.reflectionMax, 500)
    }

    // MARK: - Validation

    func testNewProjectHasNoErrors() {
        XCTAssertFalse(Validator.hasErrors(Validator.validate(.created())))
    }

    func testDuplicateNumbersAreErrors() {
        var project = Project.created()
        var copy = project.content.variations[0]
        copy.uid = UUID()
        project.content.variations.append(copy)
        XCTAssertTrue(Validator.hasErrors(Validator.validate(project)))
    }

    func testVariationWithMissingThemeAndNoTitleAreErrors() {
        var project = Project.created()
        project.content.variations[0].theme = "not-exists"
        project.content.variations[0].title = " "
        let errors = Validator.validate(project).filter { $0.level == .error }
        XCTAssertGreaterThanOrEqual(errors.count, 2)
    }

    func testReferenceToMissingVariationRaisesNotice() {
        var project = Project.created()
        project.content.variations[0].changes = ["See Variation 9."]
        let findings = Validator.validate(project)
        XCTAssertTrue(findings.contains(where: { $0.level == .notice && $0.text.contains("9") }))
    }

    func testCitedNumbers() {
        XCTAssertEqual(Validator.citedNumbers(in: "see Variation 1 and Variation 12"), [1, 12])
        XCTAssertEqual(Validator.citedNumbers(in: "no reference"), [])
    }

    // MARK: - Templates and wizard

    func testCatalogHasCaseStudy() {
        XCTAssertEqual(Templates.find("case-study"), Templates.caseStudy)
        XCTAssertNil(Templates.find("not-exists"))
        XCTAssertEqual(Set(Templates.all.map(\.id)).count, Templates.all.count, "duplicate template ids")
    }

    func testNewDocumentStartsWithoutTemplate() {
        XCTAssertEqual(GilwellDocument().project.template, "")
    }

    func testUnknownTemplateDoesNotExport() {
        var project = Project.created()
        project.template = "not-exists"
        XCTAssertThrowsError(try ScormBuilder.build(project))
    }

    func testWizardBlankAppliesAnswers() throws {
        var r = WizardDraft()
        r.templateID = "case-study"
        r.title = "  My case  "
        r.requireAllVariations = false
        r.requiredVariations = 3
        r.requiredReflections = 2
        let p = try ProjectBuilder.create(r)
        XCTAssertEqual(p.template, "case-study")
        XCTAssertEqual(p.content.title, "My case")
        XCTAssertEqual(p.config.requiredVariations, 3)
        XCTAssertEqual(p.config.requiredReflections, 2)
        XCTAssertFalse(Validator.hasErrors(Validator.validate(p)))
    }

    func testWizardWithExampleLoadsVariations() throws {
        var r = WizardDraft()
        r.templateID = "case-study"
        r.startingPoint = .example
        let p = try ProjectBuilder.create(r)
        XCTAssertGreaterThan(p.content.variations.count, 5)
        XCTAssertEqual(p.template, "case-study")
        XCTAssertFalse(Validator.hasErrors(Validator.validate(p)))
    }

    func testWizardWithoutTemplateFails() {
        XCTAssertThrowsError(try ProjectBuilder.create(WizardDraft()))
    }

    // MARK: - Sections and blocks (format 2)

    private func json(_ value: some Encodable) throws -> String {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try e.encode(value), as: UTF8.self)
    }

    private func exampleConverted() throws -> Structure {
        let data = try RuntimeAssets.data(from: Templates.caseStudy.examplePath ?? "")
        return V1Converter.convert(try JSONDecoder().decode(Project.self, from: data))
    }

    func testBlockWritesPropertiesAtSameLevel() throws {
        let block = Block(id: "x", data: .alert(AlertData(style: .error, title: "T", list: true, marker: .cross, items: ["a"])))
        let text = try json(block)
        XCTAssertTrue(text.contains("\"type\":\"alert\""), text)
        XCTAssertTrue(text.contains("\"style\":\"error\""), text)
        XCTAssertTrue(text.contains("\"id\":\"x\""), text)
    }

    func testAllBlockTypesSurviveCycle() throws {
        for type in BlockType.allCases {
            let original = Block(id: "b-\(type.rawValue)", data: .empty(type))
            let read = try JSONDecoder().decode(Block.self, from: try JSONEncoder().encode(original))
            XCTAssertEqual(read.type, type)
            XCTAssertEqual(try json(read), try json(original), "type \(type.rawValue)")
        }
    }

    func testRevealKeepsNestedBlocks() throws {
        let child = Block(id: "child", data: .highlight(HighlightData(text: "hi")))
        let parent = Block(id: "parent", data: .reveal(RevealData(trigger: .quiz("q"), label: "", blocks: [child])))
        let read = try JSONDecoder().decode(Block.self, from: try JSONEncoder().encode(parent))
        guard case .reveal(let r) = read.data else { return XCTFail("not a reveal") }
        XCTAssertEqual(r.trigger, .quiz("q"))
        XCTAssertEqual(r.blocks.map(\.id), ["child"])
    }

    func testConversionProducesSixSectionsInOrder() throws {
        let e = V1Converter.convert(.created())
        XCTAssertEqual(e.sections.map(\.id), ["home", "baseCase", "flow", "variations", "synthesis", "references"])
        XCTAssertEqual(e.schemaVersion, 2)
        XCTAssertEqual(e.sections[1].blocks.map(\.type), [.content, .content, .quiz, .reveal])
    }

    func testExampleConversionIsConsistent() throws {
        let e = try exampleConverted()
        XCTAssertEqual(e.consistencyProblems(), [])
        XCTAssertGreaterThan(e.variations.variations.count, 5)
        XCTAssertTrue(e.completion.requireVariations)
    }

    func testConversionCreatesBaseCaseQuizTrigger() throws {
        let e = try exampleConverted()
        guard case .reveal(let r)? = e.sections[1].blocks.last?.data else { return XCTFail("missing reveal") }
        XCTAssertEqual(r.trigger, .quiz(V1Converter.baseCaseQuizID))
        XCTAssertTrue(e.allBlocks.contains(where: { $0.id == V1Converter.baseCaseQuizID }))
    }

    func testStructureSurvivesCycle() throws {
        let original = try exampleConverted()
        let read = try JSONDecoder().decode(Structure.self, from: try JSONEncoder().encode(original))
        XCTAssertEqual(try json(read), try json(original))
    }

    func testConsistencyCatchesMissingDestinationsAndQuizzes() {
        var e = V1Converter.convert(.created())
        e.sections[0].blocks.append(Block(id: "bad", data: .button(ButtonData(label: "X", destination: .section("not-exists")))))
        e.sections[0].blocks.append(Block(id: "bad2", data: .reveal(RevealData(trigger: .quiz("ghost")))))
        let problems = e.consistencyProblems()
        XCTAssertEqual(problems.count, 2, "\(problems)")
    }

    func testMapWithoutVariationsIsProblem() {
        var e = V1Converter.convert(.created())
        e.variations.variations = []
        XCTAssertTrue(!e.consistencyProblems().isEmpty)
    }

    // MARK: - Free-form sections

    func testCustomSectionsSurviveFileCycleAndDriveTheStructure() throws {
        var project = Project.created()
        project.customSections = [
            ScormSection(id: "s-1", title: "Welcome", blocks: [Block(id: "b-1", data: .empty(.highlight))]),
            ScormSection(id: "s-2", title: "Map", blocks: [Block(id: "b-2", data: .empty(.map))])
        ]
        let read = try JSONDecoder().decode(Project.self, from: try JSONEncoder().encode(project))
        XCTAssertEqual(read.customSections, project.customSections)
        XCTAssertEqual(read.structure.sections.map(\.id), ["s-1", "s-2"])
        XCTAssertFalse(Validator.validate(read).contains { $0.level == .error && $0.text.lowercased().contains("section") })
    }

    func testProjectWithoutCustomSectionsKeepsGeneratedStructure() {
        let project = Project.created()
        XCTAssertNil(project.customSections)
        XCTAssertEqual(project.structure.sections.count, 6)
    }

    func testVariationsAreNotRequiredWithoutAMapBlock() {
        var project = Project.created()
        project.customSections = [ScormSection(id: "s-1", title: "Only page", blocks: [])]
        XCTAssertFalse(project.structure.completion.requireVariations)
    }

    func testDuplicatedBlockGetsFreshIdentifiersRecursively() {
        let inner = Block(id: "inner", data: .empty(.highlight))
        let outer = Block(id: "outer", data: .reveal(RevealData(blocks: [inner])))
        let copy = outer.duplicated()
        XCTAssertNotEqual(copy.id, "outer")
        guard case .reveal(let r) = copy.data else { return XCTFail("not a reveal") }
        XCTAssertNotEqual(r.blocks.first?.id, "inner")
    }

    func testEditorContextListsQuizzesInsideReveals() {
        let quiz = Block(id: "q-1", data: .quiz(QuizData(title: "Check", prompt: "p", options: [])))
        let section = ScormSection(id: "s-1", title: "One", blocks: [Block(id: "r", data: .reveal(RevealData(blocks: [quiz])))])
        let context = EditorContext(sections: [section], hasVariations: false)
        XCTAssertEqual(context.quizzes.map(\.id), ["q-1"])
        XCTAssertEqual(context.sections.map(\.id), ["s-1"])
    }

    func testEmptyBlockOfEveryTypeHasThatType() {
        for type in BlockType.allCases {
            XCTAssertEqual(BlockData.empty(type).type, type)
        }
    }
}
