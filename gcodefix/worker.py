"""Background worker that runs conversions off the GUI thread."""
from __future__ import annotations

import threading
from pathlib import Path

from PySide6.QtCore import QObject, Signal, Slot

from . import fixer


class Worker(QObject):
    progress = Signal(int, float, str)               # job id, 0..1, message
    finished = Signal(int, str, str, str, str, str)  # id, status, output, message, warning, thumbnail

    def __init__(self) -> None:
        super().__init__()
        self.cancel_event = threading.Event()

    @Slot(int, str, dict)
    def run(self, job_id: int, src: str, opts: dict) -> None:
        if self.cancel_event.is_set():
            self.finished.emit(job_id, "error", "", "Cancelled", "", "")
            return
        last = [0.0, ""]

        def cb(frac: float, msg: str) -> None:
            if abs(frac - last[0]) >= 0.004 or msg != last[1] or frac >= 1.0:
                last[0], last[1] = frac, msg
                self.progress.emit(job_id, max(0.0, min(1.0, frac)), msg)

        try:
            res = fixer.convert(
                Path(src), Path(opts["outDir"]),
                fixer.Options(material=opts["material"], color=opts["color"],
                              use_file_temps=opts["useFileTemps"], purge_line=opts["purgeLine"],
                              pressure_advance=opts["pressureAdvance"]),
                overwrite=opts["overwrite"], progress=cb, cancel=self.cancel_event)
            self.finished.emit(job_id, res.status, str(res.output or ""), res.message, res.warning,
                               res.info.get("thumb", ""))
        except fixer.Cancelled:
            self.finished.emit(job_id, "error", "", "Cancelled", "", "")
        except fixer.ConvertError as exc:
            self.finished.emit(job_id, "error", "", str(exc), "", "")
        except Exception as exc:  # noqa: BLE001 - never kill the worker thread
            self.finished.emit(job_id, "error", "", f"{type(exc).__name__}: {exc}", "", "")
