# task-22.md — PDF Reader/Editor Design (Windows desktop app)

> The plan for the AI agent to follow, the **Superpowers** way:
> brainstorm → plan (this file) → build with TDD → test → ship.
> Same method as task-11, new domain: a desktop app instead of a website.

---

## 1. Overview
Build **PageMark** — a desktop PDF reader that also *edits*: open any PDF,
read it comfortably, search it, highlight passages, add notes, and change
text on the page. Runs on Windows (and macOS/Linux — same code).

## 2. Goals / Non-Goals
**Goals**
- A real desktop app a beginner can read end-to-end (~1,000 lines).
- View **and** edit: the two sides of Adobe Acrobat, scoped honestly.
- Core logic fully unit-tested **without opening a window**.

**Non-Goals (keep it simple)**
- No text *reflow* editing (Adobe can't do it well either — PDF has no
  paragraphs, only positioned glyphs; we replace text in place).
- No forms, signatures, OCR, or cloud sync — they go on the roadmap, not
  in the MVP.

## 3. Feature map — what Adobe has vs. what we build
*Engineering is choosing.* List the whole feature space first, then scope.

| Adobe Acrobat feature | MVP | Later |
|---|---|---|
| Open / render / scroll / zoom | ✅ | |
| Page thumbnails sidebar | ✅ | |
| Text search with hit highlights | ✅ | |
| Select text | ✅ | |
| **Highlight** (and underline/strikeout) | ✅ highlight | underline, strikeout |
| Sticky notes / free-text boxes | ✅ free-text | popup notes |
| **Edit page text** (replace in place) | ✅ | font matching, reflow |
| Save / Save As (real PDF output) | ✅ | incremental save |
| Page management (rotate/reorder/delete) | | ✅ |
| Forms, e-sign, OCR, export to Word | | ✅ (each is its own project) |

## 4. Tech Stack
| Layer | Choice | Why |
|-------|--------|-----|
| Language | **Python 3.13** | One language for UI, logic, and tests |
| UI | **PySide6 (Qt 6)** | Real native desktop windows on Windows/macOS/Linux |
| PDF engine | **PyMuPDF (fitz)** | Renders pages AND edits content — one library |
| Tests | **pytest** | Core logic tested headless (no window needed) |
| Packaging | **PyInstaller** | `pyinstaller --windowed main.py` → a Windows .exe |

The split that makes it testable: **Qt only displays; fitz does the work.**

## 5. Architecture / Module Division
```
pdf-reader/
  main.py            # entry point: QApplication + MainWindow
  app_window.py      # main window: toolbar, sidebar, page view, statusbar
  page_view.py       # the page widget: zoom, render, text selection, clicks
  pdf_document.py    # THE CORE: wraps fitz — open/save/render/search/edit
  annotations.py     # highlight + free-text + replace-text operations
  search_bar.py      # find-in-document UI strip
  samples/           # make_sample.py generates test PDFs
  tests/             # pytest: all of pdf_document/annotations, no GUI
  task-22.md         # this file
```
Rule: **`pdf_document.py` and `annotations.py` never import Qt.**
That's why they can be tested in CI and reused in a CLI tool later.

## 6. Core API (the contract the UI calls)
```python
doc = PdfDocument.open(path)
doc.page_count            -> int
doc.render_page(i, zoom)  -> (pixels, width, height)   # for QImage
doc.page_text(i)          -> str
doc.search(text)          -> [(page, rect), ...]       # case-insensitive
doc.text_in_rect(i, rect) -> str                       # selection -> words
doc.add_highlight(i, rects, color=YELLOW)  -> annot id
doc.add_note(i, point, text)               -> annot id
doc.replace_text(i, rect, new_text)        # redact old glyphs, insert new
doc.annotations(i)        -> [(id, kind, text), ...]
doc.delete_annotation(i, id)
doc.is_dirty              -> bool
doc.save() / doc.save_as(path)
```
`replace_text` is the honest version of "edit PDF text": cover the old
glyphs with a redaction, apply it, insert new text at the same baseline
with a matching size. Same trick Acrobat uses for simple edits.

## 7. UI Layout
```
┌──────────────────────────────────────────────┐
│ Open  Save │ ◀ 3/12 ▶ │ − 100% + │ 🔍 Find   │  toolbar
├────────┬─────────────────────────────────────┤
│ thumbs │                                     │
│  [1]   │         the current page            │
│  [2]   │   (drag = select text → Highlight,  │
│  [3]   │    double-click word = Edit text,   │
│        │    right-click = Add note)          │
├────────┴─────────────────────────────────────┤
│ sample.pdf — page 3 of 12 — edited           │  statusbar
└──────────────────────────────────────────────┘
```

## 8. Task Breakdown (one failing test first, then the code)
1. **Core: open + render** — `PdfDocument.open`, `page_count`,
   `render_page` returns pixels of the right size.
2. **Core: text + search** — `page_text`, `search` finds rects,
   case-insensitive, `text_in_rect` extracts a selection.
3. **Core: highlight + note** — annotations appear in `annotations()`,
   survive save + reopen.
4. **Core: replace text** — old text gone, new text present after
   save + reopen; `is_dirty` flips.
5. **Window shell** — app opens with toolbar/sidebar/page view
   (test with Qt offscreen mode: `QT_QPA_PLATFORM=offscreen`).
6. **Wire viewing** — open file dialog, page nav, zoom, thumbnails.
7. **Wire search** — type → hits highlighted, Enter jumps to next.
8. **Wire editing** — drag-select → Highlight button; double-click word →
   inline edit box → replace; right-click → note. Statusbar shows "edited".
9. **Save + polish** — Save/Save As, unsaved-changes guard on close,
   keyboard shortcuts (Ctrl+O/S/F, +/−).
10. **Package** — PyInstaller one-folder build; on Windows:
    `pyinstaller --noconsole --name PageMark main.py`.

## 9. Testing Plan
- pytest; sample PDFs **generated by code** (`samples/make_sample.py`) so
  tests never depend on a binary file in git.
- Every core feature: do it → save → **reopen → assert it persisted**.
- Edge cases: search miss → `[]`; replace with empty string → removes
  text; highlight across two lines (two rects, one annotation);
  open a missing path → clean `FileNotFoundError`.
- GUI smoke test only (offscreen): window builds, widgets exist, a PDF
  loads into the view. Logic stays out of the GUI = little to GUI-test.

## 10. Definition of Done + Workflow
- A task is done when its tests pass **and** it's committed
  (`feat: core search` …). Same Superpowers loop as task-11.
- Functions small, modules under ~300 lines, no Qt in core modules.

## 11. Ship it
- macOS/Linux: `python main.py` from the venv.
- Windows .exe: `pip install pyinstaller` →
  `pyinstaller --noconsole --onedir --name PageMark main.py` →
  `dist/PageMark/PageMark.exe`. Test on a machine without Python!
