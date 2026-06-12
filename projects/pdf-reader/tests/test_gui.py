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
