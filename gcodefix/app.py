"""Qt Quick bootstrap."""
from __future__ import annotations

import sys
from pathlib import Path

from PySide6.QtCore import QCoreApplication, QEvent, QObject, QUrl
from PySide6.QtGui import QFont, QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle

from .backend import Backend

ROOT = Path(__file__).resolve().parent.parent

# The UI asks for Noto Sans; on systems without it fall back to the native UI / mono fonts.
_FONT_FALLBACKS = {
    "win32": (["Segoe UI", "Arial"], ["Consolas", "Courier New"]),
    "darwin": (["Helvetica Neue", "Arial"], ["Menlo", "Courier New"]),
}


class _OpenFileFilter(QObject):
    """macOS delivers 'open with' / Dock drops as QFileOpenEvent instead of argv."""

    def __init__(self, backend: Backend) -> None:
        super().__init__()
        self.backend = backend

    def eventFilter(self, obj, event):  # noqa: N802
        if event.type() == QEvent.Type.FileOpen:
            path = event.file() or event.url().toLocalFile()
            if path:
                self.backend.addPaths([path])
            return True
        return False


def run(argv: list[str] | None = None) -> int:
    argv = list(sys.argv if argv is None else argv)
    QCoreApplication.setApplicationName("AnycubicGcodeFix")
    QCoreApplication.setOrganizationName("AnycubicGcodeFix")
    QQuickStyle.setStyle("Basic")  # fully custom-styled controls
    if sys.platform == "win32":
        try:  # own taskbar identity (icon + grouping) instead of python.exe's
            import ctypes
            ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("rec0il.AnycubicGcodeFix")
        except Exception:  # noqa: BLE001 - cosmetic only
            pass
    app = QGuiApplication(argv)
    app.setDesktopFileName("anycubic-gcodefix")
    for family, fallbacks in zip(("Noto Sans", "Noto Sans Mono"), _FONT_FALLBACKS.get(sys.platform, ([], []))):
        QFont.insertSubstitutions(family, fallbacks)
    icon = ROOT / "packaging" / ("anycubic-gcodefix.ico" if sys.platform == "win32" else "anycubic-gcodefix.svg")
    if icon.exists():
        app.setWindowIcon(QIcon(str(icon)))

    backend = Backend()
    app.aboutToQuit.connect(backend.shutdown)
    open_filter = _OpenFileFilter(backend)
    app.installEventFilter(open_filter)

    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(QUrl.fromLocalFile(str(ROOT / "qml" / "Main.qml")))
    if not engine.rootObjects():
        return 1

    # Files passed on the command line are queued right away.
    cli = [a for a in argv[1:] if not a.startswith("-")]
    if cli:
        backend.addPaths(cli)
    return app.exec()
