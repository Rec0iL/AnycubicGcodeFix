"""Persistent settings + conversion history (JSON in ~/.config/AnycubicGcodeFix)."""
from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path
from typing import Any


def config_dir() -> Path:
    """Linux: ~/.config  |  macOS: ~/Library/Application Support  |  Windows: %APPDATA%"""
    if sys.platform == "win32":
        base = Path(os.environ.get("APPDATA") or Path.home() / "AppData" / "Roaming")
    elif sys.platform == "darwin":
        base = Path.home() / "Library" / "Application Support"
    else:
        base = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    return base / "AnycubicGcodeFix"


CONFIG_DIR = config_dir()

DEFAULTS: dict[str, Any] = {
    "material": "auto",          # auto | PLA | PETG | ABS | TPU
    "color": "#FF7A1A",          # filament colour shown on the printer's screen
    "useFileTemps": True,        # keep the temperatures the file asks for
    "pressureAdvance": True,     # M900 K.. like Anycubic's filament profiles
    "purgeLine": False,          # add Anycubic's purge line (files usually bring their own)
    "outputMode": "source",      # source (next to the original) | custom
    "customDir": "",
    "overwrite": "rename",       # rename | overwrite
    "theme": "auto",             # auto (follow system) | light | dark
    "lowPower": False,           # calmer background animation
    "lastDir": "",
}

HISTORY_LIMIT = 300


def _read(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return default


def _write(path: Path, data) -> None:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(".tmp")
        tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
        os.replace(tmp, path)
    except OSError:
        pass


class Store:
    def __init__(self) -> None:
        self.settings_path = CONFIG_DIR / "settings.json"
        self.history_path = CONFIG_DIR / "history.json"
        self.data: dict[str, Any] = {**DEFAULTS}
        loaded = _read(self.settings_path, {})
        if isinstance(loaded, dict):
            self.data.update({k: v for k, v in loaded.items() if k in DEFAULTS})
        hist = _read(self.history_path, [])
        self.history: list[dict[str, Any]] = hist if isinstance(hist, list) else []

    def set(self, key: str, value: Any) -> bool:
        if key not in DEFAULTS or self.data.get(key) == value:
            return False
        self.data[key] = value
        _write(self.settings_path, self.data)
        return True

    def add_history(self, source: str, output: str, status: str) -> None:
        self.history.append({"source": source, "output": output, "status": status,
                             "time": int(time.time())})
        del self.history[:-HISTORY_LIMIT]
        _write(self.history_path, self.history)

    def clear_history(self) -> None:
        self.history = []
        _write(self.history_path, self.history)
