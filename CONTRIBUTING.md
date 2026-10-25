# Contributing

Bug reports and PRs are welcome - for file problems please use the *Bug report* form and paste only the first / last lines
of your G-code.

## Setup

```bash
git clone https://github.com/Rec0iL/AnycubicGcodeFix && cd AnycubicGcodeFix
pip install -r requirements.txt        # PySide6 (GUI only; the converter is pure Python)
python3 main.py                        # run the app
python3 -m unittest discover -s tests -t .
QT_QPA_PLATFORM=offscreen python3 tests/smoke_qml.py   # loads the real UI headlessly
```

## Layout

| Path | What |
|---|---|
| `gcodefix/fixer.py` | the converter (parse → rewrite → wrap); no Qt imports |
| `gcodefix/profile.py`, `gcodefix/data/` | printer profile copied from AnycubicSlicerNext output |
| `gcodefix/thumbnail.py` | pure-Python toolpath → PNG renderer |
| `gcodefix/backend.py`, `worker.py` | Qt glue: job queue + background thread |
| `qml/`, `shaders/` | UI. Recompile the shader after editing (see README) |
| `install*.sh`, `*-windows.*`, `install-macos.sh` | per-OS installers (see `INSTALL.md`); `packaging/make_icons.py` rebuilds the `.ico` / `.icns` |

## Adding a printer

Slice any small model with AnycubicSlicerNext for that printer and compare it with a converted file. Update
`profile.py` (bed size, limits, start / end G-code) and `data/*_config.txt`. A sample (first + last ~60 lines) attached to
the issue helps a lot.

## Releasing (maintainer)

1. Bump `gcodefix/__init__.py`, move *Unreleased* notes to a new version in `CHANGELOG.md`.
2. `git tag v1.2.3 && git push --tags` - the *Release* workflow tests, builds the tarball + checksum and publishes it.
