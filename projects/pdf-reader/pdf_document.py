"""The core PDF engine — wraps PyMuPDF (fitz). No Qt imports allowed here:
everything in this file runs (and is tested) without a window.
"""
import os
import tempfile

import fitz  # PyMuPDF

NOTE_BOX_SIZE = (170, 50)        # free-text note width/height in PDF points
HIGHLIGHT_YELLOW = (1, 0.85, 0)  # classic marker color


class PdfDocument:
    """Open → read/render/search → annotate/edit → save."""

    def __init__(self, doc, path):
        self._doc = doc
        self.path = path
        self._dirty = False

    # --- lifecycle ---------------------------------------------------------

    @classmethod
    def open(cls, path):
        if not os.path.isfile(path):
            raise FileNotFoundError(f"No such PDF: {path}")
        return cls(fitz.open(path), path)

    @property
    def page_count(self):
        return self._doc.page_count

    @property
    def is_dirty(self):
        return self._dirty

    def save_as(self, path):
        """Write a full copy to a new path and keep editing that file."""
        self._doc.save(path)
        self.path = path
        self._dirty = False

    def save(self):
        """Overwrite the original file safely (write a sibling, then swap)."""
        data = self._doc.tobytes()
        directory = os.path.dirname(os.path.abspath(self.path)) or "."
        fd, tmp = tempfile.mkstemp(suffix=".pdf", dir=directory)
        with os.fdopen(fd, "wb") as handle:
            handle.write(data)
        os.replace(tmp, self.path)
        self._dirty = False

    # --- reading -----------------------------------------------------------

    def render_page(self, index, zoom=1.0):
        """Render a page to raw RGB bytes: (pixels, width, height)."""
        page = self._doc[index]
        pix = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom), alpha=False)
        return pix.samples, pix.width, pix.height

    def page_size(self, index):
        rect = self._doc[index].rect
        return rect.width, rect.height

    def page_text(self, index):
        return self._doc[index].get_text()

    def search(self, text):
        """Case-insensitive search across the whole document → [(page, rect)]."""
        hits = []
        if not text.strip():
            return hits
        for index in range(self.page_count):
            for rect in self._doc[index].search_for(text):
                hits.append((index, rect))
        return hits

    def text_in_rect(self, index, rect):
        """The words inside a selection rectangle."""
        return self._doc[index].get_textbox(fitz.Rect(rect)).strip()

    def word_at(self, index, point):
        """The word under a click: (rect, text), or None."""
        x, y = point
        for x0, y0, x1, y1, word, *_ in self._doc[index].get_text("words"):
            if x0 <= x <= x1 and y0 <= y <= y1:
                return fitz.Rect(x0, y0, x1, y1), word
        return None

    # --- annotating --------------------------------------------------------

    def add_highlight(self, index, rects, color=HIGHLIGHT_YELLOW):
        """Marker-style highlight over one or more line rectangles."""
        page = self._doc[index]
        annot = page.add_highlight_annot([fitz.Rect(r) for r in rects])
        annot.set_colors(stroke=color)
        annot.update()
        self._dirty = True
        return annot.xref

    def add_note(self, index, point, text):
        """A small free-text note anchored at a click point."""
        x, y = point
        width, height = NOTE_BOX_SIZE
        page = self._doc[index]
        annot = page.add_freetext_annot(
            fitz.Rect(x, y, x + width, y + height), text,
            fontsize=10, text_color=(0.1, 0.1, 0.1),
            fill_color=(1, 0.98, 0.75),
        )
        annot.update()
        self._dirty = True
        return annot.xref

    def annotations(self, index):
        """[(id, kind, text)] for one page — kind is 'Highlight', 'FreeText', …"""
        result = []
        for annot in self._doc[index].annots() or []:
            result.append((annot.xref, annot.type[1], annot.info.get("content", "")))
        return result

    def delete_annotation(self, index, annot_id):
        page = self._doc[index]
        for annot in page.annots() or []:
            if annot.xref == annot_id:
                page.delete_annot(annot)
                self._dirty = True
                return
        raise KeyError(f"No annotation {annot_id} on page {index}")

    # --- editing -----------------------------------------------------------

    def replace_text(self, index, rect, new_text):
        """Swap the text inside ``rect`` for ``new_text`` (may be empty).

        PDFs store positioned glyphs, not paragraphs — so we do what
        desktop editors do for simple edits: redact the old glyphs, then
        insert the new word at the same baseline and size.
        """
        page = self._doc[index]
        rect = fitz.Rect(rect)
        origin, size = self._first_span_style(page, rect)
        page.add_redact_annot(rect, fill=(1, 1, 1))
        page.apply_redactions()
        if new_text:
            page.insert_text(origin, new_text, fontsize=size,
                             fontname="helv", color=(0, 0, 0))
        self._dirty = True

    @staticmethod
    def _first_span_style(page, rect):
        """Baseline origin + font size of the text being replaced."""
        for block in page.get_text("dict", clip=rect)["blocks"]:
            for line in block.get("lines", []):
                for span in line["spans"]:
                    return fitz.Point(span["origin"]), span["size"]
        return fitz.Point(rect.x0, rect.y1 - 2), 11.0  # sensible fallback
