#!/usr/bin/env bash
# Anycubic GcodeFix installer for macOS - builds "Anycubic GcodeFix.app" in ~/Applications.
#
#   ./install-macos.sh          install (needs Python 3.10+ and internet for PySide6)
#   ./install-macos.sh --link   app uses this checkout directly (for development)
#   ./install-macos.sh --help
#
# Layout:  ~/Library/Application Support/AnycubicGcodeFix/{app,venv}   code + Python environment
#          ~/Applications/Anycubic GcodeFix.app                          the launcher you double-click
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINK=0
NO_PIP=0   # undocumented: skip the pip download (offline packaging / tests)
for arg in "$@"; do
    case "$arg" in
        --link)   LINK=1 ;;
        --no-pip) NO_PIP=1 ;;
        -h|--help) sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg (try --help)" >&2; exit 1 ;;
    esac
done

say()  { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!! \033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx \033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "This is the macOS installer. On Linux run ./install.sh, on Windows install-windows.bat."
[[ $EUID -ne 0 ]] || die "Don't run this with sudo - it installs into your own home folder."
[[ -f "$SRC_DIR/shaders/bg.frag.qsb" ]] || die "shaders/bg.frag.qsb missing - compile it first (see README)."

SUPPORT="$HOME/Library/Application Support/AnycubicGcodeFix"
APP_DIR="$SUPPORT/app"
VENV_DIR="$SUPPORT/venv"
BUNDLE="$HOME/Applications/Anycubic GcodeFix.app"
VERSION="$(sed -n 's/^__version__ = "\(.*\)"/\1/p' "$SRC_DIR/gcodefix/__init__.py")"
VERSION="${VERSION:-1.0.0}"

# ---------------------------------------------------------------- python 3.10+
# Apple's own /usr/bin/python3 is too old on most macOS versions, so look at Homebrew / python.org first.
PYTHON=""
shopt -s nullglob
for cand in /opt/homebrew/bin/python3 /usr/local/bin/python3 \
            /Library/Frameworks/Python.framework/Versions/3.1[0-9]/bin/python3 \
            "$(command -v python3.13 || true)" "$(command -v python3.12 || true)" \
            "$(command -v python3.11 || true)" "$(command -v python3.10 || true)" "$(command -v python3 || true)"; do
    [[ -n "$cand" && -x "$cand" ]] || continue
    if "$cand" -c 'import sys; sys.exit(sys.version_info < (3, 10))' 2>/dev/null; then PYTHON="$cand"; break; fi
done
shopt -u nullglob
if [[ -z "$PYTHON" ]]; then
    warn "Python 3.10 or newer was not found."
    warn "  Homebrew:   brew install python@3.12"
    warn "  or download the macOS installer from https://www.python.org/downloads/"
    die "Install Python, then run this script again."
fi
say "Using $PYTHON ($("$PYTHON" --version 2>&1))"

# ---------------------------------------------------------------- environment
mkdir -p "$SUPPORT" "$HOME/Applications"
say "Creating Python environment"
rm -rf "$VENV_DIR"
"$PYTHON" -m venv "$VENV_DIR" || die "Could not create a virtual environment."
if [[ $NO_PIP -eq 0 ]]; then
    say "Installing PySide6 with pip (a few hundred MB, one time)…"
    "$VENV_DIR/bin/python" -m pip install --quiet --upgrade pip
    "$VENV_DIR/bin/python" -m pip install --quiet "PySide6>=6.6" || die "pip could not install PySide6 (offline?)."
fi

# ---------------------------------------------------------------- app files
say "Installing app files to $APP_DIR"
rm -rf "$APP_DIR"
if [[ $LINK -eq 1 ]]; then
    ln -s "$SRC_DIR" "$APP_DIR"
else
    mkdir -p "$APP_DIR/shaders" "$APP_DIR/packaging"
    cp -R "$SRC_DIR/gcodefix" "$SRC_DIR/qml" "$APP_DIR/"
    cp "$SRC_DIR/main.py" "$APP_DIR/"
    cp "$SRC_DIR/packaging/anycubic-gcodefix.svg" "$APP_DIR/packaging/"
    cp "$SRC_DIR/shaders/bg.frag" "$SRC_DIR/shaders/bg.frag.qsb" "$APP_DIR/shaders/"
    find "$APP_DIR" -name '__pycache__' -type d -prune -exec rm -rf {} +
fi

# ---------------------------------------------------------------- .app bundle
say "Building $BUNDLE"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$SRC_DIR/packaging/anycubic-gcodefix.icns" "$BUNDLE/Contents/Resources/anycubic-gcodefix.icns"

cat > "$BUNDLE/Contents/MacOS/anycubic-gcodefix" <<EOF
#!/bin/bash
exec "$VENV_DIR/bin/python" "$APP_DIR/main.py" "\$@"
EOF
chmod 755 "$BUNDLE/Contents/MacOS/anycubic-gcodefix"

cat > "$BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                <string>Anycubic GcodeFix</string>
    <key>CFBundleDisplayName</key>         <string>Anycubic GcodeFix</string>
    <key>CFBundleIdentifier</key>          <string>io.github.rec0il.anycubic-gcodefix</string>
    <key>CFBundleExecutable</key>          <string>anycubic-gcodefix</string>
    <key>CFBundleIconFile</key>            <string>anycubic-gcodefix</string>
    <key>CFBundlePackageType</key>         <string>APPL</string>
    <key>CFBundleVersion</key>             <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>  <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>      <string>11.0</string>
    <key>LSApplicationCategoryType</key>   <string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key>     <true/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>       <string>G-code</string>
            <key>CFBundleTypeExtensions</key> <array><string>gcode</string><string>gco</string><string>gc</string></array>
            <key>CFBundleTypeRole</key>       <string>Viewer</string>
            <key>LSHandlerRank</key>          <string>Alternate</string>
        </dict>
    </array>
</dict>
</plist>
EOF

# files unpacked from a browser download carry a quarantine flag; this bundle is built locally, so clear it
command -v xattr >/dev/null && xattr -dr com.apple.quarantine "$BUNDLE" "$APP_DIR" 2>/dev/null || true
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[[ -x "$LSREGISTER" ]] && "$LSREGISTER" -f "$BUNDLE" >/dev/null 2>&1 || true

say "Done! Open it from ~/Applications (or Launchpad / Spotlight: \"Anycubic GcodeFix\"),"
say "then drop .gcode files onto the window - or onto the app icon in the Dock."
