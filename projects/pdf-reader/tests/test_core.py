"""Tasks 1-2: open, render, read text, and search — no GUI involved."""
import pytest

from pdf_document import PdfDocument


def test_open_counts_pages(sample_pdf):
    doc = PdfDocument.open(sample_pdf)
    assert doc.page_count == 3


def test_open_missing_file_raises(tmp_path):
    with pytest.raises(FileNotFoundError):
        PdfDocument.open(str(tmp_path / "nope.pdf"))


def test_render_page_size_scales_with_zoom(sample_pdf):
    doc = PdfDocument.open(sample_pdf)
    _, w1, h1 = doc.render_page(0, zoom=1.0)
    _, w2, h2 = doc.render_page(0, zoom=2.0)
    assert w2 == pytest.approx(w1 * 2, abs=2)
    assert h2 == pytest.approx(h1 * 2, abs=2)


def test_page_text_contains_title(sample_pdf):
    doc = PdfDocument.open(sample_pdf)
    assert "Welcome to PageMark" in doc.page_text(0)
    assert "quick brown fox" in doc.page_text(1)


def test_search_is_case_insensitive_and_returns_rects(sample_pdf):
    doc = PdfDocument.open(sample_pdf)
    hits = doc.search("CHAPTER")
    assert {page for page, _ in hits} == {1, 2}
    page, rect = hits[0]
    assert rect.width > 0 and rect.height > 0


def test_search_miss_returns_empty(sample_pdf):
    doc = PdfDocument.open(sample_pdf)
    assert doc.search("zebra-unicorn") == []


def test_text_in_rect_reads_selection(sample_pdf):
    doc = PdfDocument.open(sample_pdf)
    [(page, rect)] = doc.search("brown fox")
    assert "brown fox" in doc.text_in_rect(page, rect)


def test_word_at_finds_word_under_click(sample_pdf):
    doc = PdfDocument.open(sample_pdf)
    [(page, rect)] = doc.search("glyphs")
    middle = ((rect.x0 + rect.x1) / 2, (rect.y0 + rect.y1) / 2)
    found = doc.word_at(page, middle)
    assert found is not None
    assert "glyphs" in found[1]


def test_word_at_empty_space_is_none(sample_pdf):
    doc = PdfDocument.open(sample_pdf)
    assert doc.word_at(0, (15, 15)) is None
