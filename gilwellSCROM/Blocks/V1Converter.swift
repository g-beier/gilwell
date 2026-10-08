//
//  ConversorV1.swift
//  gilwellSCROM
//
//  Converts a project in the old format (version 1: base case, flow, variations, synthesis and references
//  in fixed fields) into sections and blocks. Reproduces the six pages of the current package.
//  Tools/convert-v2.js does the same in Node; keep the two identical.
//

import Foundation

nonisolated enum V1Converter {

    static let baseCaseQuizID = "baseCase-quiz"

    static func convert(_ p: Project) -> Structure {
        let c = p.content
        let texts = p.texts
        let config = p.config
        let total = c.variations.count
        let required = (config.requiredVariations > 0) ? min(config.requiredVariations, total) : total
        let reflections = config.requiredReflections > 0 ? min(config.requiredReflections, total) : 0

        var sections: [ScormSection] = []

        // Home
        var home: [Block] = []
        if !c.objectives.isEmpty {
            home.append(Block(id: "home-objectives", data: .alert(AlertData(
                style: .highlight, title: "Objectives", list: true, marker: .check, items: c.objectives))))
        }
        let reflectionRule = reflections > 0
            ? " (submitting \(reflections) reflections is required to complete)."
            : ", but this is optional."
        home.append(Block(id: "home-como-funciona", data: .content(ContentData(
            title: "How this case study works", style: .standard, list: true, marker: .plain, items: [
                "You start with a base case and decide what the group should do before seeing the recommended flow.",
                "Then you explore variations of the same case, in any order you like. For each one, think before revealing the analysis.",
                "In each variation, notice what changes and what stays the same. The central idea emerges when you compare them all.",
                "At the end of each analysis there is a reflective question. You can write and submit your reflection" + reflectionRule,
                "The activity is complete once you have revealed the analysis of the \(required) variations."
            ]))))
        home.append(Block(id: "home-button", data: .button(ButtonData(
            label: "Start with the base case", destination: .section("baseCase")))))
        sections.append(ScormSection(id: "home", title: "Welcome", menuLabel: "Home",
                            intro: c.subtitle, blocks: home))

        // Base case
        var afterQuiz: [Block] = []
        for (i, b) in c.caseSupport.enumerated() {
            afterQuiz.append(Block(id: "baseCase-support-\(i + 1)", data: .content(ContentData(
                title: b.title, style: .standard, list: true,
                marker: i > 0 ? .check : .plain, items: b.items))))
        }
        let flowTitle = texts.flowTitle
        afterQuiz.append(Block(id: "baseCase-button", data: .button(ButtonData(
            label: "Go to: " + flowTitle, destination: .section("flow")))))

        let baseCase: [Block] = [
            Block(id: "baseCase-text", data: .content(ContentData(
                title: "", style: .highlight, list: true, marker: .plain, items: c.baseCase))),
            Block(id: "baseCase-question", data: .content(ContentData(
                title: "Trigger question", style: .question, list: false, marker: .plain,
                items: [c.triggerQuestion]))),
            Block(id: baseCaseQuizID, data: .quiz(QuizData(
                title: "Your reasoning", prompt: c.quiz.prompt, options: c.quiz.options,
                verifyLabel: "Check answers",
                successMessage: "Well done: your answer matches the recommended flow.",
                reviewMessage: "Some points deserve another look. See the comments on the options.",
                countsForCompletion: false))),
            Block(id: "baseCase-after", data: .reveal(RevealData(
                trigger: .quiz(baseCaseQuizID), label: "", blocks: afterQuiz)))
        ]
        sections.append(ScormSection(id: "baseCase", title: "Base case", menuLabel: "1. Base case",
                            intro: "Read the case carefully. It is the starting point for all the variations.",
                            blocks: baseCase))

        // Basic flow
        var flow: [Block] = [
            Block(id: "flow-steps", data: .accordion(AccordionData(
                title: "", numbered: true,
                items: c.flow.map { AccordionItem(title: $0.title, items: $0.items) })))
        ]
        if !c.donts.isEmpty {
            flow.append(Block(id: "flow-not-do", data: .alert(AlertData(
                style: .error, title: texts.dontsTitle, list: true, marker: .cross, items: c.donts))))
        }
        flow.append(Block(id: "flow-button", data: .button(ButtonData(
            label: "Explore the variations", destination: .section("variations")))))
        sections.append(ScormSection(id: "flow", title: texts.flowTitle, menuLabel: "2. Basic flow",
                            intro: texts.flowIntro, blocks: flow))

        // Variations
        sections.append(ScormSection(id: "variations", title: "Variations map", menuLabel: "3. Variations",
                            intro: "What if the case were different? Pick a variation, think about what changes and what stays the same, and only then reveal the analysis.",
                            blocks: [
                                Block(id: "variations-map", data: .map(MapData(
                                    intro: "", labelOnComplete: "Go to the synthesis", destinationOnComplete: .section("synthesis"))))
                            ]))

        // Synthesis
        var synthesis: [Block] = [
            Block(id: "synthesis-progress", data: .progress(ProgressData(
                buttonLabel: "Back to the variations", destination: .section("variations")))),
            Block(id: "synthesis-question", data: .content(ContentData(
                title: "Before seeing the table", style: .question, list: false, marker: .plain,
                items: [texts.synthesisQuestion]))),
            Block(id: "synthesis-idea", data: .reveal(RevealData(
                trigger: .button, label: "Show the central idea", blocks: [
                    Block(id: "synthesis-idea-columns", data: .columns(ColumnsData(
                        columns: texts.centralIdea.map {
                            ContentColumn(title: $0.title, list: false, marker: .plain,
                                             items: $0.text.isEmpty ? [] : [$0.text])
                        })))
                ]))),
            Block(id: "synthesis-table", data: .table(TableData(title: "All variations side by side")))
        ]
        if !c.principles.isEmpty {
            synthesis.append(Block(id: "synthesis-principles", data: .content(ContentData(
                title: texts.principlesTitle, style: .standard, list: true, marker: .check, items: c.principles))))
        }
        if !c.takeaways.isEmpty {
            synthesis.append(Block(id: "synthesis-take", data: .alert(AlertData(
                style: .highlight, title: texts.takeawaysTitle, list: true, marker: .check, items: c.takeaways))))
        }
        sections.append(ScormSection(id: "synthesis", title: "Synthesis", menuLabel: "4. Synthesis", intro: "", blocks: synthesis))

        // References
        let references = c.references.isEmpty ? ["No references listed."] : c.references
        sections.append(ScormSection(id: "references", title: "References", menuLabel: "", intro: "", blocks: [
            Block(id: "references-list", data: .content(ContentData(
                title: "", style: .standard, list: true, marker: .plain, items: references)))
        ]))

        return structure(for: p, sections: sections)
    }

    /// Assembles the structure of a project from a list of sections (generated or edited by the author).
    static func structure(for p: Project, sections: [ScormSection]) -> Structure {
        let c = p.content
        let config = p.config
        var structure = Structure()
        structure.template = p.template
        structure.label = c.label
        structure.title = c.title
        structure.subtitle = c.subtitle
        structure.sections = sections
        structure.variations = VariationData(
            reflectionNotice: c.reflectionNotice,
            reflectionMinimum: config.reflectionMin,
            reflectionMaximum: config.reflectionMax,
            themes: c.themes,
            variations: c.variations)
        structure.completion = CompletionCriteria(
            requireAllSections: false,
            // Without a map block there is no way to open the variations, so they cannot be required.
            requireVariations: !c.variations.isEmpty && structure.allBlocks.contains(where: { $0.type == .map }),
            requiredVariations: config.requiredVariations,
            requireQuizzes: false,
            requiredReflections: config.requiredReflections)
        return structure
    }
}
