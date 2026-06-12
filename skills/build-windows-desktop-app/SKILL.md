---
name: build-windows-desktop-app
description: Build a Windows desktop GUI application the engineering-first way — study an incumbent product, cut an MVP, write a design file, keep all logic out of the UI layer, TDD every task offscreen, and ship an .exe. Use when asked to build a desktop app, a document editor/viewer, a PySide6/Qt application, or to structure a GUI project so it stays testable. Worked example: projects/pdf-reader (PageMark, a PDF reader/editor — task-22).
---

# Build a Windows desktop app (the PageMark way)

Every practice below was executed and verified end-to-end while building
**PageMark** (`projects/pdf-reader`), a PDF reader/editor with text edit,
highlight, notes, and search — 21 passing tests, zero test flakiness,
several real bugs caught before and after ship. Copy that project as a
template.

## 1. Start from the incumbent, not from a blank page

Map the features of the product you are imitating (Adobe Acrobat), then
cut ruthlessly to an MVP table: *feature → in/out → why*. "Edit a PDF" hid
the hardest problem — a PDF stores positioned glyphs, not paragraphs — and
the feature map surfaced that before any code existed. Write the result
into a design file (`task-22.md`) containing: the feature map, the chosen
stack, the architecture rule, and a numbered task breakdown.

## 2. Pick a stack where one language does everything

PySide6 (Qt 6) for the window, PyMuPDF (fitz) for the PDF engine, pytest
for tests, PyInstaller for packaging — all Python, all pip-installable.
Avoid split-language stacks for a first desktop app; the build story gets
hard before the app does.

## 3. The one architecture rule: the UI layer only displays

`pdf_document.py` wraps the engine and **imports no Qt**. Window/widget
files do nothing but wire signals to it. This bought:

- The whole engine is testable without a display.
- GUI tests run headless too: set `QT_QPA_PLATFORM=offscreen` at the top
  of the test file before importing Qt, then instantiate the real
  `MainWindow`.
- Bugs sort themselves: wrong pixels → view file; wrong document → engine
  file.

Enforce it the whole project; one stray Qt import in the core breaks every
guarantee at once.

## 4. One task, one failing test

Break the design into ~10 tasks, each delivering one user-visible ability
("open + render", "search", "highlight", "replace text", …). For each:
write the failing test, make it pass, run the whole suite. Engine tests
assert on document state; GUI tests assert on widget state
(`window.thumbnails.count()`, `window.page_view.current_index`).

For **visual** bugs, sample pixels: render, then assert the color at the
expected coordinate (`image.pixelColor(x, y)`). A drag-selection offset
bug got a regression test that checks the tint exists *under the cursor*
and that the old buggy position is plain white.

## 5. Lessons that came from real post-ship bugs

These were found by a real user after "all tests pass" — bake them in
from the start next time:

- **A feature without an affordance does not exist.** Text editing worked
  but was reachable only by double-clicking a word — no button, no hint.
  Users reported "can't edit". Every capability needs a visible control
  (toolbar action + shortcut), a hint at the moment it becomes relevant
  (status-bar tip after opening a file), and **feedback on miss**
  (double-click on empty space says *why* nothing happened).
- **Input mapping and overlay drawing must share one coordinate helper.**
  The page pixmap sat centered inside a larger label. Click→PDF mapping
  subtracted the centering offset, but the live selection rectangle was
  painted without it — visually shifted ~80px+. Put the offset in one
  method (`_pixmap_offset`) and use it on both paths.
- **Windows locks open files.** `os.remove()` on a PDF the app still has
  open raises `PermissionError`. Give the document class an explicit
  `close()` and call it before deleting/replacing files. Save safely by
  writing a sibling temp file then `os.replace()`.

## 6. Automate the evidence

A `scripts/screenshot.py` that builds a sample document, drives the real
window offscreen, and saves PNGs gives you honest docs/slide images on
every UI change — no hand-cropping, always current. Same pattern works
for any Qt app: `window.grab().save(path)` after `app.processEvents()`.

## 7. Ship it

```bash
pip install pyinstaller
pyinstaller --noconsole --onefile --name PageMark main.py
```

Run the .exe from `dist/`, not from the IDE, before calling it done —
packaging finds import and path bugs that `python main.py` never will.
