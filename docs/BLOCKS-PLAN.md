# Plan: SCORM builder with sections and blocks

## Idea
A project becomes a **list of sections**; each section is a **list of blocks**. The author creates,
renames, removes and reorders sections, and builds each one by dragging blocks from a palette. The learner
runtime becomes a generic renderer (one renderer per block type). The current case study is just the
“starting point” that comes pre-assembled with these blocks.

## Section
- title (shown in the menu), opening sentence (optional), icon/short label (optional), blocks.
- “Empty page, with a header” = a section with no blocks.
- System sections that appear in the menu from a block: the **variations** (see below).

## Block catalog
| Block | Properties | Notes |
|---|---|---|
| Content | title (optional), paragraphs or list, marker (none / ✓ / ✕) | “How this study works”, base case, references |
| Alert | style (highlight / warning / error), title, paragraphs or list | objectives (highlight), “what NOT to do” (error) |
| Accordion | items {title, content}, numbered (yes/no) | basic flow and any list of steps |
| Columns | 2 or 3 columns {title, icon, list} | “what changes / what stays the same”, “core idea” |
| Highlight | short text in the spotlight | one-line synthesis |
| Button | label, destination (next section / section X / map) | “advance button” |
| Quiz | prompt, options {text, correct, feedback}, correct/review messages | reusable, several per page; counts toward completion (optional) |
| Reveal | trigger (button with a label **or** “after answering quiz X”), child blocks | “Before seeing the table”, the variation's analysis, “what does this indicate?” |
| Reflection | question, min/max characters, notice | optional; recorded in Moodle; can be replaced by a Quiz |
| Variations map | opening text | cards per theme, “seen” mark; one of the ways to complete |
| Variations table | columns (no., title, synthesis) | can only be inserted if the project has variations |

### Variations (data for the “case study” type)
Themes + variations are still edited in the **Themes** sublist. Each variation keeps: “What if…?”,
starting point, what changes / what stays the same, synthesis and **optional reflection**. The variation's detail page
uses a fixed layout at first (as today); in a later phase it will also accept free blocks.

### Completion (configurable)
Combinable criteria, under “Completion and reflections”: open all sections · explore all (or N) variations
on the map · answer the marked quizzes correctly · submit N reflections. The SCORM becomes “completed” when all the
checked criteria are met.

## File format (schemaVersion 2)
```
project { template, title, label, subtitle,
          sections: [ { id, title, opening, blocks: [ { id, type, ...properties } ] } ],
          variations: { themes, variations },
          completion { ... }, texts }
```
Every block and every section has a stable `id` (used in Moodle interactions, saved state and button destinations).
Old files (v1) are converted on open: the six current sections become sections with the equivalent blocks.

## Runtime
- `renderBlocks(list)` + a `BLOCKS[type]` registry; adding a new block = one JS function + one Swift editor.
- Saved state (`suspend_data`, kept compact because of the 4096 limit): sections seen, variations seen,
  quizzes (answered/correct), revealed items, reflections submitted.
- Menu generated from the sections; routes: section, map, variation detail.
- The smoke tests (jsdom) remain valid and now run on the converted project.

## Editor (macOS)
- Sidebar: **Sections** (drag to reorder, +, rename, delete) and **Themes/Variations** (as today).
- Center: the open section as a stack of block cards, each editable in place.
- Block palette: drag onto the section **or** a “+ Block” button (a no-drag alternative).
- Blocks that contain blocks (Accordion, Reveal, Columns) accept blocks dropped inside.
- Verification: button pointing to a removed section, table without variations, quiz without a correct option,
  two sections with the same title, impossible completion criterion.

## Steps
1. ✅ **Block model** (Swift: `Blocks/`) + v1→v2 converter + tests; the same converter in `Tools/convert-v2.js` (generates `Samples/case-study-ud4.v2.json`). Added the **Progress** block (the synthesis's “you explored X of Y” summary).
2. ✅ **Generic runtime** (`Runtime/js/app.js` reads `STRUCTURE`): all blocks, completion by criteria, state saved by ids. jsdom `smoke*.js` tests passing on the converted project and `smoke7.js` on a free structure (no variations). Visual differences: the core idea became columns in cards; the Progress block no longer repeats the sentence about the synthesis.
3. ✅ **Editor without dragging**: sections (create/rename/delete/reorder) and blocks via “+ Block”, a form per type. Implemented in `BlockEditor/` (section list in the sidebar, one form per block type, duplicate/reorder/delete). The project stores the author's sections in `customSections`; “Edit sections and blocks freely…” converts the fixed pages into them.
4. **Drag and drop**: palette → section, reorder, nest.
5. **Configurable completion** and new **verifications**.
6. **Section templates** (Introduction, Content, Quiz, Flow, References…) and an updated wizard.

## Risks
- Swift cannot be compiled from here; each editor step goes out for you to run and send back the errors.
- Drag and drop with nesting in SwiftUI is the most fragile part; the “+ Block” button guarantees a path without it.
- Old projects must open without loss (conversion tests with the UD 4 example).
