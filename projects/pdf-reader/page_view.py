"""The page widget: renders one page, handles zoom, selection, and clicks.

Qt only displays here — every PDF operation goes through PdfDocument.
"""
from PySide6.QtCore import QPoint, QRect, Qt, Signal
from PySide6.QtGui import QColor, QImage, QPainter, QPixmap
from PySide6.QtWidgets import QLabel, QScrollArea

SELECT_FILL = QColor(14, 165, 233, 60)     # translucent sky blue
SELECT_EDGE = QColor(14, 165, 233, 180)
HIT_FILL = QColor(249, 115, 22, 70)        # translucent orange
DRAG_THRESHOLD = 6                          # px before a click becomes a drag


class PageView(QScrollArea):
    """Shows one page; reports selections and clicks in PDF coordinates."""

    selection_made = Signal(tuple)          # (x0, y0, x1, y1)
    word_double_clicked = Signal(tuple, str)
    word_missed = Signal()                  # double-click found no text
    note_point_chosen = Signal(tuple)       # (x, y)

    def __init__(self):
        super().__init__()
        self.doc = None
        self.current_index = 0
        self.zoom = 1.25
        self.hits = []                      # rects to outline on this page
        self._drag_start = None
        self._drag_rect = None
        self.label = QLabel("Open a PDF to get started  (Ctrl+O)\n\n"
                            "Double-click a word to edit it  ·  drag to select,"
                            " then 🖍 highlight or ✏ replace  ·  right-click adds a note")
        self.label.setAlignment(Qt.AlignCenter)
        self.label.setMouseTracking(True)
        self.label.installEventFilter(self)
        self.setWidget(self.label)
        self.setWidgetResizable(True)
        self.setAlignment(Qt.AlignCenter)

    # --- public API ---------------------------------------------------------

    def set_document(self, doc):
        self.doc = doc
        self.show_page(0)

    def show_page(self, index):
        if self.doc is None:
            return
        self.current_index = max(0, min(index, self.doc.page_count - 1))
        self.refresh()

    def set_zoom(self, zoom):
        self.zoom = max(0.4, min(zoom, 4.0))
        self.refresh()

    def set_hits(self, rects):
        self.hits = rects
        self.refresh()

    def refresh(self):
        """Re-render the current page and draw overlays."""
        if self.doc is None:
            return
        pixels, width, height = self.doc.render_page(self.current_index, self.zoom)
        image = QImage(pixels, width, height, width * 3, QImage.Format_RGB888)
        pixmap = QPixmap.fromImage(image.copy())

        painter = QPainter(pixmap)
        for rect in self.hits:
            painter.fillRect(self._to_widget(rect), HIT_FILL)
        if self._drag_rect:
            painter.fillRect(self._drag_rect, SELECT_FILL)
            painter.setPen(SELECT_EDGE)
            painter.drawRect(self._drag_rect)
        painter.end()

        self.label.setPixmap(pixmap)
        self.label.resize(pixmap.size())

    # --- coordinate mapping ---------------------------------------------------

    def _to_widget(self, pdf_rect):
        z = self.zoom
        return QRect(int(pdf_rect[0] * z), int(pdf_rect[1] * z),
                     int((pdf_rect[2] - pdf_rect[0]) * z),
                     int((pdf_rect[3] - pdf_rect[1]) * z))

    def _to_pdf(self, pos):
        # the pixmap is centered inside the label — remove that offset first
        pixmap = self.label.pixmap()
        if pixmap is None:
            return None
        dx = max(0, (self.label.width() - pixmap.width()) // 2)
        dy = max(0, (self.label.height() - pixmap.height()) // 2)
        return ((pos.x() - dx) / self.zoom, (pos.y() - dy) / self.zoom)

    # --- mouse handling -------------------------------------------------------

    def eventFilter(self, obj, event):
        if obj is not self.label or self.doc is None:
            return super().eventFilter(obj, event)

        kind = event.type()
        if kind == event.Type.MouseButtonPress and event.button() == Qt.LeftButton:
            self._drag_start = event.position().toPoint()
            self._drag_rect = None
        elif kind == event.Type.MouseMove and self._drag_start:
            self._drag_rect = QRect(self._drag_start,
                                    event.position().toPoint()).normalized()
            self.refresh()
        elif kind == event.Type.MouseButtonRelease and self._drag_start:
            end = event.position().toPoint()
            moved = (end - self._drag_start).manhattanLength()
            if moved > DRAG_THRESHOLD and self._drag_rect:
                p0 = self._to_pdf(self._drag_rect.topLeft())
                p1 = self._to_pdf(self._drag_rect.bottomRight())
                self.selection_made.emit((p0[0], p0[1], p1[0], p1[1]))
            self._drag_start = None
        elif kind == event.Type.MouseButtonDblClick:
            point = self._to_pdf(event.position().toPoint())
            found = self.doc.word_at(self.current_index, point)
            if found:
                rect, word = found
                self.word_double_clicked.emit(
                    (rect.x0, rect.y0, rect.x1, rect.y1), word)
            else:
                self.word_missed.emit()
        elif kind == event.Type.ContextMenu:
            point = self._to_pdf(QPoint(event.pos()))
            if point:
                self.note_point_chosen.emit(point)
            return True
        return super().eventFilter(obj, event)

    def clear_selection(self):
        self._drag_rect = None
        self.refresh()
