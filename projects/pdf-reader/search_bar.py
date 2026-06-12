"""Find-in-document strip: type → see hit count → Enter/buttons to jump."""
from PySide6.QtCore import Signal
from PySide6.QtWidgets import QHBoxLayout, QLabel, QLineEdit, QPushButton, QWidget


class SearchBar(QWidget):
    """Owns the hit list; tells the window which (page, rect) is current."""

    hit_selected = Signal(int, object)      # page index, rect
    hits_changed = Signal(list)             # rects on the current page

    def __init__(self):
        super().__init__()
        self.doc = None
        self.hits = []
        self.position = -1

        self.field = QLineEdit()
        self.field.setPlaceholderText("Find in document…")
        self.count = QLabel("")
        prev_button = QPushButton("◀")
        next_button = QPushButton("▶")

        layout = QHBoxLayout(self)
        layout.setContentsMargins(6, 3, 6, 3)
        layout.addWidget(self.field, 1)
        layout.addWidget(self.count)
        layout.addWidget(prev_button)
        layout.addWidget(next_button)

        self.field.textChanged.connect(self._run_search)
        self.field.returnPressed.connect(self.go_next)
        prev_button.clicked.connect(self.go_prev)
        next_button.clicked.connect(self.go_next)

    def set_document(self, doc):
        self.doc = doc
        self._run_search(self.field.text())

    def _run_search(self, text):
        self.hits = self.doc.search(text) if self.doc else []
        self.position = -1
        self.count.setText(f"{len(self.hits)} hits" if text else "")
        self.hits_changed.emit(self.hits)

    def _jump(self, step):
        if not self.hits:
            return
        self.position = (self.position + step) % len(self.hits)
        page, rect = self.hits[self.position]
        self.count.setText(f"{self.position + 1}/{len(self.hits)}")
        self.hit_selected.emit(page, rect)

    def go_next(self):
        self._jump(+1)

    def go_prev(self):
        self._jump(-1)
