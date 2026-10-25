#!/usr/bin/env bash
# Anycubic GcodeFix uninstaller for macOS.
#
#   ./uninstall-macos.sh           remove the app and its Python environment
#   ./uninstall-macos.sh --purge   additionally delete settings & history
set -euo pipefail

PURGE=0
for arg in "$@"; do
    case "$arg" in
        --purge) PURGE=1 ;;
        -h|--help) sed -n '2,5p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg (try --help)" >&2; exit 1 ;;
    esac
done
[[ -n "${HOME:-}" ]] || { echo "HOME is not set." >&2; exit 1; }

SUPPORT="$HOME/Library/Application Support/AnycubicGcodeFix"
rm -rf "${HOME:?}/Applications/Anycubic GcodeFix.app"
rm -rf "${SUPPORT:?}/app" "${SUPPORT:?}/venv"      # a symlink (--link install) is removed, not followed
if [[ $PURGE -eq 1 ]]; then
    rm -rf "${SUPPORT:?}"
    echo "Settings and history removed."
fi
echo "Anycubic GcodeFix uninstalled."
