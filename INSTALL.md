# Installing Anycubic GcodeFix

You need **Python 3.10 or newer** and **PySide6 6.6+** (the Qt bindings). The installers below set both up for you.
Nothing needs administrator rights, and nothing is installed system-wide unless you ask for it.

| | Windows 10/11 | macOS 11+ | Linux |
|---|---|---|---|
| Install | double-click `install-windows.bat` | `./install-macos.sh` | `./install.sh` or `./install.sh --venv` |
| Try without installing | `run-windows.bat` | `python3 main.py` | `python3 main.py` |
| Uninstall | `uninstall-windows.bat` | `./uninstall-macos.sh` | `./uninstall.sh` |

> **Status:** developed and run on Linux (Fedora-based Nobara). The Windows and macOS installers were written to the
> same design and checked for structure, but **have not been run on real Windows / macOS machines yet** - if something
> breaks, please [open an issue](https://github.com/Rec0iL/AnycubicGcodeFix/issues/new/choose) with the console output.

Get the files from the [latest release](https://github.com/Rec0iL/AnycubicGcodeFix/releases/latest)
(`.zip` for Windows, `.tar.gz` for macOS / Linux), or `git clone https://github.com/Rec0iL/AnycubicGcodeFix`.

---

## Windows 10 / 11

1. **Python** - skip this if `py --version` already says 3.10+. Otherwise, in PowerShell or Terminal:
   ```powershell
   winget install Python.Python.3.12
   ```
   (or use the installer from <https://www.python.org/downloads/> and tick *Add python.exe to PATH*).
2. **Unzip** the release. *If Windows blocks the files:* right-click the `.zip` → *Properties* → tick **Unblock** → OK,
   then unzip.
3. **Double-click `install-windows.bat`.** It creates a private Python environment, downloads PySide6 (a few hundred MB,
   one time), and adds:
   - a **Start menu** entry *Anycubic GcodeFix*
   - a right-click **Send to → Anycubic GcodeFix** entry for `.gcode` files

   Options (type them after the file name in a terminal): `-Desktop` adds a desktop icon, `-NoSendTo` skips the
   Send-to entry.
4. Open it from the Start menu and drop `.gcode` files on the window.

*"Windows protected your PC" (SmartScreen)* appears for any unsigned downloaded script: click **More info → Run anyway**.
The script is plain text - open it in Notepad to see exactly what it does.

**Without installing:** double-click `run-windows.bat`. The first start creates a `.venv` next to it; you can also drag
`.gcode` files onto the `.bat`.

**Uninstall:** `uninstall-windows.bat` (add `-Purge` in a terminal to also delete settings and history).

**Where things live:** app and Python environment in `%LOCALAPPDATA%\AnycubicGcodeFix`, settings in `%APPDATA%\AnycubicGcodeFix`.

*If it does not start:* run `"%LOCALAPPDATA%\AnycubicGcodeFix\venv\Scripts\python.exe" "%LOCALAPPDATA%\AnycubicGcodeFix\app\main.py"`
in a terminal to see the error. A message about a missing DLL means the Visual C++ runtime is absent:
`winget install Microsoft.VCRedist.2015+.x64`.

---

## macOS 11 or newer (Apple Silicon and Intel)

1. **Python 3.10+.** Apple's built-in `python3` is usually too old. With [Homebrew](https://brew.sh):
   ```bash
   brew install python@3.12
   ```
   or use the macOS installer from <https://www.python.org/downloads/>.
2. **Unpack** the release, open *Terminal*, `cd` into the folder and run:
   ```bash
   chmod +x install-macos.sh uninstall-macos.sh   # only needed if the files came from a .zip
   ./install-macos.sh
   ```
   It creates a Python environment, downloads PySide6 (a few hundred MB, one time) and builds
   **`~/Applications/Anycubic GcodeFix.app`** with its icon.
3. Open the app from *Launchpad* / *Spotlight*, then drop `.gcode` files onto the window - or onto the **Dock icon**,
   or use *Open With* in Finder.

The app is built on your own Mac, so Gatekeeper does not block it. It is not code-signed or notarized.

**Without installing:** `python3 -m pip install PySide6 && python3 main.py` in the unpacked folder (a virtual
environment is tidier: `python3 -m venv .venv && .venv/bin/pip install PySide6 && .venv/bin/python main.py`).

**Uninstall:** `./uninstall-macos.sh` (add `--purge` to also delete settings and history).

**Where things live:** app + environment in `~/Library/Application Support/AnycubicGcodeFix`, launcher in `~/Applications`.

---

## Linux

Pick your family, run its commands, then run the installer from the unpacked folder. Everything installs under `~/.local`,
adds an entry to your application menu and a `anycubic-gcodefix` command.

| Distro family | 1 · prerequisites | 2 · installer |
|---|---|---|
| **Fedora**, Nobara, Bazzite, RHEL-likes | `sudo dnf install python3 python3-pyside6` | `./install.sh` |
| **Arch**, Manjaro, EndeavourOS, CachyOS | `sudo pacman -S python pyside6` | `./install.sh` |
| **Ubuntu**, Debian, Linux Mint, Pop!_OS, Zorin, elementary | `sudo apt install python3 python3-venv python3-pip libegl1 libgl1 libxkbcommon0 libxcb-cursor0 libdbus-1-3 libfontconfig1` | `./install.sh --venv` |
| **openSUSE** Tumbleweed / Leap | `sudo zypper install python3 python3-pip libxcb-cursor0` | `./install.sh --venv` |
| **Anything else** with Python 3.10+ (Void, Gentoo, Solus…) | install `python3` and its `venv` module | `./install.sh --venv` |

**Why two installer modes?** `./install.sh` uses the PySide6 your distro ships (small, updated with the system).
`./install.sh --venv` creates a private environment and downloads PySide6 from PyPI (a few hundred MB) - it works on
any distro, and is the right choice where no PySide6 package exists (many Ubuntu LTS / Debian stable releases ship no
PySide6 package, and openSUSE names it per Python version). Not sure? Use `--venv`.

Other options: `./install.sh --system` (with `sudo`, installs to `/usr/local`), `./install.sh --link` (runs straight from
the checkout, handy for development). They combine, e.g. `./install.sh --venv --link`.

**NixOS / Nix:** no installer needed -
`nix-shell -p python3 python3Packages.pyside6 --run "python3 main.py"` in the unpacked folder.

**Uninstall:** `./uninstall.sh` (add `--system` if you installed that way, `--purge` to also delete settings and history).

**Where things live:** `~/.local/share/anycubic-gcodefix` (+ `-venv`), launcher in `~/.local/bin`, settings in `~/.config/AnycubicGcodeFix`.
If `anycubic-gcodefix` is "command not found", add `~/.local/bin` to your `PATH` (the menu entry works regardless).

Wayland and X11 both work. On X11, Qt 6.5+ needs `libxcb-cursor0` (included in the commands above).

---

## Run from source on any system

```bash
git clone https://github.com/Rec0iL/AnycubicGcodeFix && cd AnycubicGcodeFix
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt        # Windows: .venv\Scripts\pip ...
.venv/bin/python main.py [file.gcode ...]        # Windows: .venv\Scripts\python main.py
```

## Command line only (no Qt needed)

The converter itself is pure Python 3.10+ with no dependencies:

```bash
python3 -m gcodefix.cli part.gcode [more files or folders] [--out DIR]
```

---

## Troubleshooting

| Problem | Try |
|---|---|
| Window never appears | Start it from a terminal (`anycubic-gcodefix`, or the `python … main.py` command above) and read the error. |
| Black / missing background, or crash on old GPUs | `QSG_RHI_BACKEND=opengl` (Linux), `d3d11` (Windows) or `metal` (macOS) in the environment; or switch on *Low-power background* in Settings. |
| `could not load the Qt platform plugin "xcb"` | `sudo apt install libxcb-cursor0` (or your distro's equivalent). |
| pip cannot find PySide6 | Check `python --version` is 3.10 or newer and 64-bit. A brand-new Python release may not have PySide6 wheels yet - Python 3.12 is a safe choice. |
| File is converted but the printer still refuses it | [Open a bug report](https://github.com/Rec0iL/AnycubicGcodeFix/issues/new/choose) with your printer model + firmware and the first / last lines of the file. |
