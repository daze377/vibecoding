"""PageMark — a small PDF reader & editor.  Run:  python main.py [file.pdf]"""
import sys

from PySide6.QtWidgets import QApplication

from app_window import MainWindow


def main():
    app = QApplication(sys.argv)
    window = MainWindow()
    if len(sys.argv) > 1:
        window.load_path(sys.argv[1])
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
