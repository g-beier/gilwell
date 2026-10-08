# Gilwell SCORM

Native macOS app that builds SCORM 1.2 packages of **case studies with variations** for Moodle.
You fill in forms, see the result running next to them (with a simulated Moodle) and export the `.zip`.

## How to open and run

1. Open `gilwellSCROM.xcodeproj` in Xcode and run (⌘R).
2. Under **File > New**, the wizard asks for the template and the basic details (and can start right away with the UD 4 example). Or use **File > Open…** on `Samples/case-study-ud4.gilwell`.
3. Edit on the left, check the preview on the right and use **Export SCORM…** in the toolbar.

Each case study is a `.gilwell` file (readable JSON), easy to version in Git.

## Structure

```
gilwellSCROM/
  gilwellSCROMApp.swift        DocumentGroup: one .gilwell file per window
  ContentView.swift            router: no template → wizard; with a template → the template's screen
  Wizard/                      initial wizard (3 steps) and ProjectBuilder (rules, testable)
  Shared/                      ProjectWindow (frame: preview + export) and form components
  Blocks/                      sections and blocks (format 2) and the converter from the old format (see docs/BLOCKS-PLAN.md)
  Model/                       GilwellDocument (.gilwell) and ZipDocument
  Export/                      ScormBuilder (package, manifest), ZipWriter (dependency-free ZIP)
  Preview/                     WKWebView + “Simulated Moodle” (SCORM 1.2 window.API)
  Templates/
    ScormTemplate.swift        descriptor of each template + the `Templates.all` catalog
    CaseStudy/                 everything specific to the case study:
      CaseStudyView.swift        sidebar and editor selection
      Editors.swift              forms for each part
      Project.swift              project data (Codable)
      Validator.swift            checks before exporting
      Runtime/                   HTML/CSS/JS and fonts of the package the learner sees
      Example/                   example project offered in the wizard
Info-Gilwell.plist             declares the .gilwell file type
Samples/                       example project (copy)
Tools/                         reference generator and converter to blocks (Node), runtime tests (jsdom)
gilwellSCROMTests/             unit tests (ZIP, package, validation, wizard)
```

## How to add a template

1. Create `Templates/NewTemplate/` with the runtime (`Runtime/index.html`, etc.), the editing screens and the validator.
2. Add its descriptor to `Templates` (`ScormTemplate.swift`): `id`, name, summary, `runtimeFolder` (e.g. `"NewTemplate/Runtime"`) and `runtimeFiles`.
3. In `ContentView.swift`, add `if id == Templates.newTemplate.id { NewTemplateView(...) }`. Use `ProjectWindow` as the frame: it already provides the preview and export.
4. If the template needs different data, `Project` currently describes the case study; the next step is to generalize the content (for example, store the template's content as its own JSON inside `Project`).
5. `ScormBuilder.dataJS` and the wizard (`ProjectBuilder`) will also need to handle the new template.

Note: runtime file names repeat across templates (`index.html`), which is why the full path, including the template folder, is used for lookups inside the app.

## How the package is generated

`ScormBuilder` copies the template's `Runtime/` files, writes `js/data.js` (`STRUCTURE`: sections, blocks, variations and
completion rules; the current project is converted by `V1Converter`) and creates `imsmanifest.xml`. To change the look or behavior of
what the learner sees, edit the files in `Runtime/` (`css/style.css`, `js/app.js`); the content always comes from the project.

After changing the runtime, run its tests:

```
cd Tools/tests && npm install
node ../build-reference.js ../../Samples/case-study-ud4.gilwell /tmp/package
for t in smoke.js smoke3.js smoke4.js smoke6.js smoke7.js; do node $t /tmp/package; done
node smoke2.js /tmp/package normal; node smoke2.js /tmp/package popup; node smoke5.js /tmp/package 0
```

`Tools/build-reference.js` does in Node the same thing as `ScormBuilder.swift`; it is used to cross-check the two. The format 1 → 2 converter lives in `Tools/convert-v2.js` (the Node twin of `Blocks/V1Converter.swift`).

## Xcode project settings changed from the template

- `ENABLE_USER_SELECTED_FILES = readwrite` (save projects and export the .zip).
- `ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES` (the sandboxed WKWebView needs this, even for local files).
- `INFOPLIST_FILE = Info-Gilwell.plist` (declares the `.gilwell` type; the rest of Info.plist is still generated).
- Core Data removed (`Persistence.swift` and the `Item` model).

## Known limitations of this first version

- No undo/redo (⌘Z) in the forms.
- A single template (“case study with variations”); the catalog, the wizard and the frame are ready for others, but the data format (`Project`) is still the case study's.
- Colors, fonts and logo are not yet configurable per project (Poppins and Krona One, with the module's colors).
- ZIP without compression (enough for the size of the packages).
