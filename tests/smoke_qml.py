"""Headless smoke test: load the real UI, wait a moment, exit 0 if it came up without QML errors.

    QT_QPA_PLATFORM=offscreen python3 tests/smoke_qml.py
"""
import os
import sys
import tempfile
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ["XDG_CONFIG_HOME"] = tempfile.mkdtemp()      # never touch the real settings
os.environ["APPDATA"] = os.environ["XDG_CONFIG_HOME"]
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from PySide6.QtCore import QCoreApplication, QTimer, QUrl, qInstallMessageHandler
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle

from gcodefix.backend import Backend

errors: list[str] = []
qInstallMessageHandler(lambda mode, ctx, msg: errors.append(msg) if "Error" in str(mode) or "Critical" in str(mode)
                       or "TypeError" in msg or "ReferenceError" in msg or "is not a type" in msg else None)

QCoreApplication.setApplicationName("AnycubicGcodeFixSmoke")
QQuickStyle.setStyle("Basic")
app = QGuiApplication(sys.argv)
backend = Backend()
engine = QQmlApplicationEngine()
engine.rootContext().setContextProperty("backend", backend)
engine.load(QUrl.fromLocalFile(str(Path(__file__).resolve().parent.parent / "qml" / "Main.qml")))
if not engine.rootObjects():
    print("FAIL: Main.qml did not load", file=sys.stderr)
    sys.exit(1)

QTimer.singleShot(1500, app.quit)
app.exec()
backend.shutdown()
if errors:
    print("FAIL: QML reported errors:\n  " + "\n  ".join(errors), file=sys.stderr)
    sys.exit(1)
print("OK: UI loaded")
