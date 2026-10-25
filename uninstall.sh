#!/usr/bin/env bash
# Anycubic GcodeFix uninstaller.
#
#   ./uninstall.sh            remove the per-user install (~/.local)
#   ./uninstall.sh --system   remove the system-wide install (run with sudo)
#   ./uninstall.sh --purge    additionally delete settings & history (~/.config/AnycubicGcodeFix)
set -euo pipefail

MODE="user"
PURGE=0
for arg in "$@"; do
    case "$arg" in
        --system) MODE="system" ;;
        --purge)  PURGE=1 ;;
        -h|--help) sed -n '2,6p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg (try --help)" >&2; exit 1 ;;
    esac
done

if [[ "$MODE" == "system" ]]; then
    [[ $EUID -eq 0 ]] || { echo "--system needs root: sudo $0 --system" >&2; exit 1; }
    PREFIX="/usr/local"
    APP_DIR="$PREFIX/share/anycubic-gcodefix"
    VENV_DIR="$PREFIX/share/anycubic-gcodefix-venv"
    BIN_DIR="$PREFIX/bin"
    APPS_DIR="$PREFIX/share/applications"
    ICON_DIR="$PREFIX/share/icons/hicolor/scalable/apps"
else
    DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    APP_DIR="$DATA_HOME/anycubic-gcodefix"
    VENV_DIR="$DATA_HOME/anycubic-gcodefix-venv"
    BIN_DIR="$HOME/.local/bin"
    APPS_DIR="$DATA_HOME/applications"
    ICON_DIR="$DATA_HOME/icons/hicolor/scalable/apps"
fi

rm -rf "$APP_DIR"                       # a symlink (--link install) is removed, not followed
rm -rf "$VENV_DIR"                      # only exists after ./install.sh --venv
rm -f  "$BIN_DIR/anycubic-gcodefix" "$APPS_DIR/anycubic-gcodefix.desktop" "$ICON_DIR/anycubic-gcodefix.svg"

command -v update-desktop-database >/dev/null && update-desktop-database "$APPS_DIR" 2>/dev/null || true
if command -v gtk-update-icon-cache >/dev/null; then
    gtk-update-icon-cache -q -t "$(dirname "$(dirname "$ICON_DIR")")" 2>/dev/null || true
fi
command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 >/dev/null 2>&1 || true

if [[ $PURGE -eq 1 ]]; then
    rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/AnycubicGcodeFix"
    echo "Settings and history removed."
fi
echo "Anycubic GcodeFix uninstalled."
