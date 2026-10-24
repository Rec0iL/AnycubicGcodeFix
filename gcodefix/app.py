"""Qt Quick bootstrap."""
from __future__ import annotations

import sys
from pathlib import Path

from PySide6.QtCore import QCoreApplication, QUrl
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle

from .backend import Backend

ROOT = Path(__file__).resolve().parent.parent


def run(argv: list[str] | None = None) -> int:
    argv = list(sys.argv if argv is None else argv)
    QCoreApplication.setApplicationName("AnycubicGcodeFix")
    QCoreApplication.setOrganizationName("AnycubicGcodeFix")
    QQuickStyle.setStyle("Basic")  # fully custom-styled controls
    app = QGuiApplication(argv)
    app.setDesktopFileName("anycubic-gcodefix")
    icon = ROOT / "packaging" / "anycubic-gcodefix.svg"
    if icon.exists():
        app.setWindowIcon(QIcon(str(icon)))

    backend = Backend()
    app.aboutToQuit.connect(backend.shutdown)

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
