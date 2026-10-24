# Changelog

All notable changes to this project are documented here. Format based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [SemVer](https://semver.org/).

## [Unreleased]

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

[Unreleased]: https://github.com/Rec0iL/AnycubicGcodeFix/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Rec0iL/AnycubicGcodeFix/releases/tag/v1.0.0
