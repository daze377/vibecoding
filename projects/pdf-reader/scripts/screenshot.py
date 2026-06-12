"""Render demo screenshots of PageMark (offscreen — no display needed).

Usage: python scripts/screenshot.py output-dir/
"""
import os
import sys

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtWidgets import QApplication

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app_window import MainWindow
from samples.make_sample import make_sample


def main(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    app = QApplication([])

    sample = make_sample(os.path.join(out_dir, "demo.pdf"))
    window = MainWindow()
    window.load_path(sample)
    window.resize(1080, 760)
    window.show()

    # Demo state on page 2: highlight "quick brown fox", add a note.
    doc = window.doc
    [(page, rect)] = doc.search("quick brown fox")
    doc.add_highlight(page, [(rect.x0, rect.y0, rect.x1, rect.y1)])
    doc.add_note(page, (rect.x0, rect.y1 + 18), "Classic pangram — keep!")
    window.go_to_page(page)
    app.processEvents()
    window.grab().save(os.path.join(out_dir, "pagemark-annotate.png"))

    # Search view: find every "Chapter" and jump to the first hit.
    window.toggle_search()
    window.search_bar.field.setText("Chapter")
    window.search_bar.go_next()
    app.processEvents()
    window.grab().save(os.path.join(out_dir, "pagemark-search.png"))

    os.remove(sample)
    print(f"saved 2 screenshots to {out_dir}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "docs")
