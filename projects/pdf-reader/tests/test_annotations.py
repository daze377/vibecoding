"""Tasks 3-4: highlight, note, and replace-text — all must survive a save."""
import pytest

from pdf_document import PdfDocument


def reopen_after_save(doc, tmp_path):
    out = str(tmp_path / "out.pdf")
    doc.save_as(out)
    return PdfDocument.open(out)


def test_highlight_persists(sample_pdf, tmp_path):
    doc = PdfDocument.open(sample_pdf)
    [(page, rect)] = doc.search("brown fox")
    doc.add_highlight(page, [rect])
    assert doc.is_dirty

    saved = reopen_after_save(doc, tmp_path)
    kinds = [kind for _, kind, _ in saved.annotations(page)]
    assert "Highlight" in kinds


def test_note_persists_with_text(sample_pdf, tmp_path):
    doc = PdfDocument.open(sample_pdf)
    doc.add_note(0, (100, 200), "Remember this part!")

    saved = reopen_after_save(doc, tmp_path)
    notes = [text for _, kind, text in saved.annotations(0) if kind == "FreeText"]
    assert notes == ["Remember this part!"]


def test_delete_annotation(sample_pdf):
    doc = PdfDocument.open(sample_pdf)
    annot_id = doc.add_note(0, (100, 200), "temp")
    doc.delete_annotation(0, annot_id)
    assert doc.annotations(0) == []


def test_replace_text_swaps_words(sample_pdf, tmp_path):
    doc = PdfDocument.open(sample_pdf)
    [(page, rect)] = doc.search("lazy")
    doc.replace_text(page, rect, "sleepy")

    saved = reopen_after_save(doc, tmp_path)
    text = saved.page_text(page)
    assert "sleepy" in text
    assert "lazy" not in text


def test_replace_with_empty_removes_text(sample_pdf, tmp_path):
    doc = PdfDocument.open(sample_pdf)
    [(page, rect)] = doc.search("brown fox")
    doc.replace_text(page, rect, "")

    saved = reopen_after_save(doc, tmp_path)
    assert "brown fox" not in saved.page_text(page)


def test_save_clears_dirty_flag(sample_pdf, tmp_path):
    doc = PdfDocument.open(sample_pdf)
    doc.add_note(0, (100, 200), "note")
    assert doc.is_dirty
    doc.save_as(str(tmp_path / "out.pdf"))
    assert not doc.is_dirty
