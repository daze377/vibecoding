"""The main window: toolbar, thumbnail sidebar, page view, status bar.

All real work happens in PdfDocument — this file just wires signals to it.
"""
from PySide6.QtCore import QSize, Qt
from PySide6.QtGui import QAction, QImage, QIcon, QKeySequence, QPixmap
from PySide6.QtWidgets import (
    QFileDialog, QInputDialog, QListWidget, QListWidgetItem, QMainWindow,
    QMessageBox, QToolBar, QLabel,
)

from page_view import PageView
from pdf_document import PdfDocument
from search_bar import SearchBar

THUMB_ZOOM = 0.18
ZOOM_STEP = 1.2


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.doc = None
        self.selection = None
        self.setWindowTitle("PageMark — PDF reader & editor")
        self.resize(1080, 760)

        self.page_view = PageView()
        self.setCentralWidget(self.page_view)
        self.page_view.selection_made.connect(self.on_selection)
        self.page_view.word_double_clicked.connect(self.on_edit_word)
        self.page_view.word_missed.connect(self.on_word_missed)
        self.page_view.note_point_chosen.connect(self.on_add_note)

        self.thumbnails = QListWidget()
        self.thumbnails.setFixedWidth(150)
        self.thumbnails.setIconSize(QSize(110, 150))
        self.thumbnails.currentRowChanged.connect(self.go_to_page)
        dock = self._dock("Pages", self.thumbnails)

        self._build_toolbar()
        self._build_search_bar()
        self.status = self.statusBar()

    # --- UI assembly --------------------------------------------------------

    def _dock(self, title, widget):
        from PySide6.QtWidgets import QDockWidget
        dock = QDockWidget(title, self)
        dock.setWidget(widget)
        dock.setFeatures(QDockWidget.NoDockWidgetFeatures)
        self.addDockWidget(Qt.LeftDockWidgetArea, dock)
        return dock

    def _action(self, text, slot, shortcut=None):
        action = QAction(text, self)
        action.triggered.connect(slot)
        if shortcut:
            action.setShortcut(QKeySequence(shortcut))
        return action

    def _build_toolbar(self):
        bar = QToolBar("Main")
        bar.setMovable(False)
        self.addToolBar(bar)

        bar.addAction(self._action("Open", self.open_dialog, "Ctrl+O"))
        bar.addAction(self._action("Save", self.save, "Ctrl+S"))
        bar.addAction(self._action("Save As", self.save_as, "Ctrl+Shift+S"))
        bar.addSeparator()
        bar.addAction(self._action("◀", lambda: self.go_to_page(self.page_view.current_index - 1)))
        self.page_label = QLabel(" – ")
        bar.addWidget(self.page_label)
        bar.addAction(self._action("▶", lambda: self.go_to_page(self.page_view.current_index + 1)))
        bar.addSeparator()
        bar.addAction(self._action("−", lambda: self.set_zoom(self.page_view.zoom / ZOOM_STEP)))
        self.zoom_label = QLabel(" 125% ")
        bar.addWidget(self.zoom_label)
        bar.addAction(self._action("+", lambda: self.set_zoom(self.page_view.zoom * ZOOM_STEP), "Ctrl+="))
        bar.addSeparator()
        self.highlight_action = self._action("🖍 Highlight", self.on_highlight, "Ctrl+H")
        self.highlight_action.setEnabled(False)
        bar.addAction(self.highlight_action)
        self.edit_action = self._action("✏ Edit text", self.on_edit_selection, "Ctrl+E")
        self.edit_action.setEnabled(False)
        self.edit_action.setToolTip("Replace the selected text (or double-click a word)")
        bar.addAction(self.edit_action)
        bar.addAction(self._action("🔍 Find", self.toggle_search, "Ctrl+F"))

    def _build_search_bar(self):
        self.search_bar = SearchBar()
        search_toolbar = QToolBar("Search")
        search_toolbar.setMovable(False)
        search_toolbar.addWidget(self.search_bar)
        self.addToolBarBreak()
        self.addToolBar(search_toolbar)
        self._search_toolbar = search_toolbar
        search_toolbar.hide()
        self.search_bar.hit_selected.connect(self.on_hit_selected)
        self.search_bar.hits_changed.connect(self.on_hits_changed)

    # --- document lifecycle ---------------------------------------------------

    def open_dialog(self):
        path, _ = QFileDialog.getOpenFileName(self, "Open PDF", "", "PDF files (*.pdf)")
        if path:
            self.load_path(path)

    def load_path(self, path):
        self.doc = PdfDocument.open(path)
        self.page_view.set_document(self.doc)
        self.search_bar.set_document(self.doc)
        self._fill_thumbnails()
        self._refresh_status()
        self.status.showMessage(
            "Double-click a word to edit it  ·  drag to select, then 🖍 highlight"
            " or ✏ replace  ·  right-click adds a note", 10000)

    def save(self):
        if self.doc:
            self.doc.save()
            self._refresh_status()

    def save_as(self):
        if not self.doc:
            return
        path, _ = QFileDialog.getSaveFileName(self, "Save PDF as", "", "PDF files (*.pdf)")
        if path:
            self.doc.save_as(path)
            self._refresh_status()

    def closeEvent(self, event):
        if self.doc and self.doc.is_dirty:
            answer = QMessageBox.question(
                self, "Unsaved changes", "Save changes before closing?",
                QMessageBox.Save | QMessageBox.Discard | QMessageBox.Cancel)
            if answer == QMessageBox.Save:
                self.save()
            elif answer == QMessageBox.Cancel:
                event.ignore()
                return
        event.accept()

    # --- navigation -----------------------------------------------------------

    def go_to_page(self, index):
        if not self.doc:
            return
        self.page_view.show_page(index)
        self._refresh_status()

    def set_zoom(self, zoom):
        self.page_view.set_zoom(zoom)
        self.zoom_label.setText(f" {round(self.page_view.zoom * 100)}% ")

    def toggle_search(self):
        bar = self._search_toolbar
        bar.setVisible(not bar.isVisible())
        if bar.isVisible():
            self.search_bar.field.setFocus()

    # --- editing actions --------------------------------------------------------

    def on_selection(self, rect):
        self.selection = rect
        self.highlight_action.setEnabled(True)
        selected = self.doc.text_in_rect(self.page_view.current_index, rect)
        self.edit_action.setEnabled(bool(selected))
        self.status.showMessage(
            f'Selected: "{selected[:60]}" — 🖍 to highlight, ✏ to replace'
            if selected else "Selection has no text — 🖍 still highlights the area")

    def on_highlight(self):
        if self.doc and self.selection:
            self.doc.add_highlight(self.page_view.current_index, [self.selection])
            self._clear_selection()
            self._refresh_status()

    def on_edit_selection(self):
        if not (self.doc and self.selection):
            return
        page = self.page_view.current_index
        old_text = self.doc.text_in_rect(page, self.selection)
        new_text, ok = QInputDialog.getText(
            self, "Edit text", "Replace selection with:", text=old_text)
        if ok and new_text != old_text:
            self.doc.replace_text(page, self.selection, new_text)
            self._clear_selection()
            self.page_view.refresh()
            self._refresh_status()

    def _clear_selection(self):
        self.selection = None
        self.highlight_action.setEnabled(False)
        self.edit_action.setEnabled(False)
        self.page_view.clear_selection()

    def on_edit_word(self, rect, word):
        new_text, ok = QInputDialog.getText(
            self, "Edit text", "Replace with:", text=word)
        if ok and new_text != word:
            self.doc.replace_text(self.page_view.current_index, rect, new_text)
            self.page_view.refresh()
            self._refresh_status()

    def on_word_missed(self):
        self.status.showMessage(
            "No editable text under the cursor — scanned pages have none", 5000)

    def on_add_note(self, point):
        text, ok = QInputDialog.getMultiLineText(self, "Add note", "Note:")
        if ok and text.strip():
            self.doc.add_note(self.page_view.current_index, point, text.strip())
            self.page_view.refresh()
            self._refresh_status()

    # --- search wiring -----------------------------------------------------------

    def on_hit_selected(self, page, rect):
        self.go_to_page(page)
        self.on_hits_changed(self.search_bar.hits)

    def on_hits_changed(self, hits):
        current = self.page_view.current_index
        rects = [(r.x0, r.y0, r.x1, r.y1) for p, r in hits if p == current]
        self.page_view.set_hits(rects)

    # --- helpers --------------------------------------------------------------

    def _fill_thumbnails(self):
        self.thumbnails.blockSignals(True)
        self.thumbnails.clear()
        for index in range(self.doc.page_count):
            pixels, width, height = self.doc.render_page(index, THUMB_ZOOM)
            image = QImage(pixels, width, height, width * 3, QImage.Format_RGB888)
            item = QListWidgetItem(QIcon(QPixmap.fromImage(image.copy())),
                                   f"Page {index + 1}")
            self.thumbnails.addItem(item)
        self.thumbnails.blockSignals(False)

    def _refresh_status(self):
        if not self.doc:
            return
        name = self.doc.path.split("/")[-1]
        edited = "  —  edited (unsaved)" if self.doc.is_dirty else ""
        self.page_label.setText(f" {self.page_view.current_index + 1}/{self.doc.page_count} ")
        self.status.showMessage(f"{name} — page {self.page_view.current_index + 1}"
                                f" of {self.doc.page_count}{edited}")
