#!/usr/bin/env bash
# Anycubic GcodeFix installer for Linux - installs the app, launcher, icon and .desktop entry.
# (macOS: ./install-macos.sh   Windows: install-windows.bat)
#
#   ./install.sh              per-user install into ~/.local   (no sudo needed)
#   ./install.sh --venv       same, but into its own Python venv with pip-installed PySide6
#                             (use this when your distro has no PySide6 package: Ubuntu LTS, Debian, Mint, openSUSE…)
#   ./install.sh --system     system-wide install into /usr/local (run with sudo)
#   ./install.sh --link       per-user, but symlink to this checkout (for development)
#   ./install.sh --help
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="user"
LINK=0
VENV=0
NO_PIP=0   # undocumented: skip the pip download (offline packaging / tests)

for arg in "$@"; do
    case "$arg" in
        --system) MODE="system" ;;
        --link)   LINK=1 ;;
        --venv)   VENV=1 ;;
        --no-pip) NO_PIP=1 ;;
        -h|--help) sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg (try --help)" >&2; exit 1 ;;
    esac
done

case "$(uname -s)" in
    Linux) ;;
    Darwin) echo "This is the Linux installer. On macOS run: ./install-macos.sh" >&2; exit 1 ;;
    *)      echo "This is the Linux installer. On Windows double-click install-windows.bat" >&2; exit 1 ;;
esac

if [[ "$MODE" == "system" ]]; then
    if [[ $EUID -ne 0 ]]; then
        echo "--system needs root: sudo $0 --system" >&2
        exit 1
    fi
    PREFIX="/usr/local"
    APP_DIR="$PREFIX/share/anycubic-gcodefix"
    VENV_DIR="$PREFIX/share/anycubic-gcodefix-venv"
    BIN_DIR="$PREFIX/bin"
    APPS_DIR="$PREFIX/share/applications"
    ICON_DIR="$PREFIX/share/icons/hicolor/scalable/apps"
else
    if [[ $EUID -eq 0 ]]; then
        echo "Running as root without --system would install into root's home. Aborting." >&2
        exit 1
    fi
    DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    APP_DIR="$DATA_HOME/anycubic-gcodefix"
    VENV_DIR="$DATA_HOME/anycubic-gcodefix-venv"
    BIN_DIR="$HOME/.local/bin"
    APPS_DIR="$DATA_HOME/applications"
    ICON_DIR="$DATA_HOME/icons/hicolor/scalable/apps"
fi

say()  { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!! \033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx \033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- python
PYTHON=""
for cand in python3 python3.13 python3.12 python3.11 python3.10; do
    if command -v "$cand" >/dev/null && "$cand" -c 'import sys; sys.exit(sys.version_info < (3, 10))' 2>/dev/null; then
        PYTHON="$(command -v "$cand")"
        break
    fi
done
[[ -n "$PYTHON" ]] || die "Python 3.10 or newer is required (found: $(python3 --version 2>&1 || echo none)). See INSTALL.md."
[[ -f "$SRC_DIR/shaders/bg.frag.qsb" ]] || die "shaders/bg.frag.qsb missing - compile it first (see README)."

RUN_PY="$PYTHON"
if [[ $VENV -eq 1 ]]; then
    say "Creating Python environment in $VENV_DIR"
    rm -rf "$VENV_DIR"
    "$PYTHON" -m venv "$VENV_DIR" 2>/dev/null || {
        warn "python3 -m venv failed. Debian/Ubuntu/Mint: sudo apt install python3-venv"
        die "Could not create a virtual environment."
    }
    RUN_PY="$VENV_DIR/bin/python"
    if [[ $NO_PIP -eq 0 ]]; then
        say "Installing PySide6 with pip (a few hundred MB, one time)…"
        "$RUN_PY" -m pip install --quiet --upgrade pip
        "$RUN_PY" -m pip install --quiet "PySide6>=6.6" || die "pip could not install PySide6 (offline? unsupported platform?)."
    fi
elif ! "$PYTHON" -c 'import PySide6.QtQuick, PySide6.QtQuickControls2' 2>/dev/null; then
    warn "PySide6 (with Qt Quick) is missing for $PYTHON."
    warn "  Fedora/Nobara: sudo dnf install python3-pyside6      Arch/Manjaro: sudo pacman -S pyside6"
    warn "  Anything else (Ubuntu, Debian, Mint, openSUSE…): re-run with  ./install.sh --venv"
    MISSING_PYSIDE=1
fi

# ---------------------------------------------------------------- install files
say "Installing to $APP_DIR"
mkdir -p "$BIN_DIR" "$APPS_DIR" "$ICON_DIR"

if [[ $LINK -eq 1 ]]; then
    rm -rf "$APP_DIR"
    ln -s "$SRC_DIR" "$APP_DIR"
else
    rm -rf "$APP_DIR"
    mkdir -p "$APP_DIR/shaders" "$APP_DIR/packaging"
    cp -r "$SRC_DIR/gcodefix" "$SRC_DIR/qml" "$APP_DIR/"
    cp "$SRC_DIR/main.py" "$APP_DIR/"
    cp "$SRC_DIR/packaging/anycubic-gcodefix.svg" "$APP_DIR/packaging/"
    cp "$SRC_DIR/shaders/bg.frag" "$SRC_DIR/shaders/bg.frag.qsb" "$APP_DIR/shaders/"
    find "$APP_DIR" -name '__pycache__' -type d -prune -exec rm -rf {} +
fi

say "Writing launcher $BIN_DIR/anycubic-gcodefix"
cat > "$BIN_DIR/anycubic-gcodefix" <<EOF
#!/usr/bin/env bash
exec "$RUN_PY" "$APP_DIR/main.py" "\$@"
EOF
chmod 755 "$BIN_DIR/anycubic-gcodefix"

say "Installing icon"
cp "$SRC_DIR/packaging/anycubic-gcodefix.svg" "$ICON_DIR/anycubic-gcodefix.svg"

say "Writing desktop entry $APPS_DIR/anycubic-gcodefix.desktop"
cat > "$APPS_DIR/anycubic-gcodefix.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Anycubic GcodeFix
GenericName=G-code Fixer
Comment=Drag & drop G-code from any slicer so Anycubic printers accept it
Exec=$BIN_DIR/anycubic-gcodefix %F
Icon=anycubic-gcodefix
Terminal=false
Categories=Utility;
Keywords=gcode;3d;printer;anycubic;kobra;fullcontrol;slicer;
MimeType=text/x-gcode;
StartupWMClass=anycubic-gcodefix
StartupNotify=true
EOF
chmod 644 "$APPS_DIR/anycubic-gcodefix.desktop"

# ---------------------------------------------------------------- refresh caches
command -v desktop-file-validate >/dev/null && desktop-file-validate "$APPS_DIR/anycubic-gcodefix.desktop" || true
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS_DIR" 2>/dev/null || true
if command -v gtk-update-icon-cache >/dev/null; then
    gtk-update-icon-cache -q -t "$(dirname "$(dirname "$ICON_DIR")")" 2>/dev/null || true
fi
command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 >/dev/null 2>&1 || true

say "Done! Launch it from your application menu or run: anycubic-gcodefix"
if [[ "$MODE" == "user" && ":$PATH:" != *":$BIN_DIR:"* ]]; then
    warn "$BIN_DIR is not in your PATH - the menu entry works, but add it to run 'anycubic-gcodefix' from a terminal."
fi
[[ -z "${MISSING_PYSIDE:-}" ]] || warn "Install PySide6 (see above) before starting the app."
