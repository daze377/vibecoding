"""Generate sample PDFs in code so tests never depend on binaries in git."""
import fitz  # PyMuPDF

PAGE_TEXTS = [
    ("Welcome to PageMark", "PageMark is a small PDF reader and editor. "
     "You can highlight text, add notes, and even change words on the page."),
    ("Chapter One", "The quick brown fox jumps over the lazy dog. "
     "Search works across every page of the document."),
    ("Chapter Two", "Editing a PDF means working with positioned glyphs. "
     "There are no paragraphs inside a PDF, only letters with coordinates."),
]


def make_sample(path):
    """Write a three-page sample PDF and return its path."""
    doc = fitz.open()
    for title, body in PAGE_TEXTS:
        page = doc.new_page()  # A4 by default
        page.insert_text((72, 96), title, fontsize=20, fontname="helv")
        page.insert_textbox(fitz.Rect(72, 130, 523, 700), body,
                            fontsize=12, fontname="helv")
    doc.save(path)
    doc.close()
    return path


if __name__ == "__main__":
    print(make_sample("sample.pdf"))
