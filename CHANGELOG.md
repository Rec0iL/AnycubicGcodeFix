# Changelog

All notable changes to this project are documented here. Format based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [SemVer](https://semver.org/).

## [Unreleased]

## [1.1.0] - 2026-10-25

Adds Windows and macOS support. The new Windows / macOS installers pass CI but have not been run on real machines yet -
please [report problems](https://github.com/Rec0iL/AnycubicGcodeFix/issues/new/choose). See [INSTALL.md](INSTALL.md).

### Added
- **Windows** support: `install-windows.bat` / `.ps1` (per-user, no admin: Start menu entry + right-click *Send to*),
  `uninstall-windows.bat`, and `run-windows.bat` to run from a folder without installing.
- **macOS** support: `install-macos.sh` builds `~/Applications/Anycubic GcodeFix.app` (icon, `.gcode` registered, drop files on
  the Dock icon); `uninstall-macos.sh`.
- Linux: `./install.sh --venv` installs into a private Python environment with pip-installed PySide6, for distros that
  have no PySide6 package (Ubuntu / Debian / Mint / openSUSE …).
- `INSTALL.md` with step-by-step instructions for Windows, macOS, Fedora, Arch, Ubuntu/Debian, openSUSE and Nix.
- Windows `.ico` and macOS `.icns` icons (`packaging/make_icons.py` regenerates them from the SVG).
- CI runs the converter tests on Linux, Windows and macOS, plus a headless UI smoke test (`tests/smoke_qml.py`).
- Releases also ship a `.zip` (for Windows).

### Changed
- Settings / history live in the platform's standard folder (`%APPDATA%`, `~/Library/Application Support`, `~/.config`).
- Converted files are always written with LF line endings (Windows would have produced CRLF).
- UI falls back to Segoe UI / Helvetica Neue / Consolas / Menlo where Noto Sans is not installed.

## [1.0.0] - 2026-10-24

First release. Verified on an Anycubic Kobra S1 with a FullControl-generated file.

### Added
- Drag & drop GUI (Qt Quick / PySide6) with queue, per-file progress, preview thumbnail, history, light / dark / auto theme.
- Converter that re-wraps G-code from any slicer or generator (FullControl, Orca, Prusa, Cura, hand-written) into the
  layout the Anycubic Kobra S1 accepts: header block, thumbnails, `G9111` start sequence, `M73` progress, end sequence,
  statistics and config blocks.
- Absolute → relative extrusion conversion, `;LAYER_CHANGE` markers, time / filament estimates.
- Warnings for printing moves outside the 250×250 mm bed or above 250 mm.
- Filament presets (Auto / PLA / PETG / ABS / TPU), filament colour, keep-file-temperatures, pressure advance, optional purge line.
- Headless CLI: `python3 -m gcodefix.cli`.
- `install.sh` / `uninstall.sh` (per-user, `--link`, `--system`).

[Unreleased]: https://github.com/Rec0iL/AnycubicGcodeFix/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/Rec0iL/AnycubicGcodeFix/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Rec0iL/AnycubicGcodeFix/releases/tag/v1.0.0
