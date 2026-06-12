"""Task 5: the window shell builds and loads a PDF — offscreen, no display."""
import os

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

import pytest
from PySide6.QtWidgets import QApplication


@pytest.fixture(scope="session")
def qapp():
    return QApplication.instance() or QApplication([])


def test_window_builds_and_loads_pdf(qapp, sample_pdf):
    from app_window import MainWindow

    window = MainWindow()
    window.load_path(sample_pdf)
    assert "PageMark" in window.windowTitle()
    assert window.thumbnails.count() == 3          # one thumb per page
    assert window.page_view.current_index == 0


def test_page_navigation_updates_view(qapp, sample_pdf):
    from app_window import MainWindow

    window = MainWindow()
    window.load_path(sample_pdf)
    window.go_to_page(2)
    assert window.page_view.current_index == 2
    window.go_to_page(99)                          # clamped, not crashed
    assert window.page_view.current_index == 2


def test_search_jumps_to_hit_page(qapp, sample_pdf):
    from app_window import MainWindow

    window = MainWindow()
    window.load_path(sample_pdf)
    window.search_bar.field.setText("glyphs")      # only on page 3
    window.search_bar.go_next()
    assert window.page_view.current_index == 2


def test_selecting_text_enables_edit_and_replaces_it(qapp, sample_pdf, monkeypatch):
    import app_window
    from app_window import MainWindow

    window = MainWindow()
    window.load_path(sample_pdf)
    [(page, rect)] = window.doc.search("quick brown fox")
    window.go_to_page(page)

    assert not window.edit_action.isEnabled()
    window.on_selection((rect.x0, rect.y0, rect.x1, rect.y1))
    assert window.edit_action.isEnabled()

    monkeypatch.setattr(app_window.QInputDialog, "getText",
                        staticmethod(lambda *a, **k: ("slow green fox", True)))
    window.on_edit_selection()
    text = window.doc.page_text(page)
    assert "slow green fox" in text and "quick brown fox" not in text
    assert not window.edit_action.isEnabled()      # selection consumed


def test_double_click_on_empty_space_reports_no_text(qapp, sample_pdf):
    from app_window import MainWindow

    window = MainWindow()
    window.load_path(sample_pdf)
    window.page_view.word_missed.emit()
    assert "No editable text" in window.status.currentMessage()


def test_drag_overlay_is_drawn_under_the_cursor(qapp, sample_pdf):
    """The page sits centered in the view — the selection rectangle must be
    shifted by that offset, not painted at raw cursor coordinates."""
    from PySide6.QtCore import QRect
    from app_window import MainWindow

    window = MainWindow()
    window.load_path(sample_pdf)
    window.resize(1080, 760)
    window.show()
    qapp.processEvents()

    view = window.page_view
    dx, dy = view._pixmap_offset(view.label.pixmap().size())
    assert dx > 0                                   # page is centered → offset exists

    view._drag_rect = QRect(dx + 300, dy + 500, 80, 40)   # cursor drag, label coords
    view.refresh()
    image = view.label.pixmap().toImage()

    under_cursor = image.pixelColor(300 + 40, 500 + 20)   # same spot, pixmap coords
    assert under_cursor.blue() > under_cursor.red()        # sky-blue tint is there

    old_buggy_spot = image.pixelColor(dx + 300 + 40, dy + 500 + 20)
    assert old_buggy_spot.red() == old_buggy_spot.blue() == 255   # plain white page
