"""Rewrite G-code from any slicer into the layout the Anycubic printer accepts.

The Kobra S1 only prints files that look like AnycubicSlicerNext output: a header block,
thumbnails, an EXECUTABLE block that starts with the machine start sequence (G9111 does the
heating, homing and levelling) and a footer with statistics. Files from other slicers - or
hand-made ones such as FullControl's - miss all of that. This module keeps the toolpath
untouched and rebuilds the rest around it.
"""
from __future__ import annotations

import base64
import json
import math
import re
import threading
import time
from array import array
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

from . import profile, thumbnail

GCODE_EXT = {".gcode", ".gco", ".gc", ".g"}
SUFFIX = "_anycubic"

Progress = Callable[[float, str], None]


class ConvertError(Exception):
    pass


class Cancelled(Exception):
    pass


@dataclass
class Options:
    material: str = "auto"          # auto | PLA | PETG | ABS | TPU
    color: str = "#FF7A1A"
    use_file_temps: bool = True     # keep the temperatures the file asks for
    purge_line: bool = False        # add Anycubic's own purge line
    pressure_advance: bool = True   # M900 K... like the slicer's filament start gcode


@dataclass
class Result:
    status: str                     # done | skipped | error
    output: Path | None = None
    message: str = ""
    warning: str = ""
    info: dict = field(default_factory=dict)


# --------------------------------------------------------------------------- detection
def is_anycubic(head: str) -> bool:
    return "HEADER_BLOCK_START" in head and "EXECUTABLE_BLOCK_START" in head


def expand_inputs(paths: list[str]) -> list[Path]:
    """Files stay as they are; folders are searched (recursively) for G-code files."""
    found: list[Path] = []
    seen: set[Path] = set()
    for raw in paths:
        p = Path(raw)
        cands = sorted(p.rglob("*")) if p.is_dir() else [p]
        for c in cands:
            if c.is_file() and c.suffix.lower() in GCODE_EXT and c.resolve() not in seen:
                seen.add(c.resolve())
                found.append(c)
    return found


# --------------------------------------------------------------------------- parsing
_E_TOKEN = re.compile(r"(?<![A-Za-z])[eE][-+]?\d*\.?\d+")
_ZE_LINE = re.compile(r"^\s*G0?1\b[^;]*\bZ(-?\d*\.?\d+)[^;]*\bE", re.I)
_TOOL = re.compile(r"^T\d+$")

# Set-up commands that G9111 / the Anycubic start sequence replaces (only dropped before the first print move).
DROP_PRE = {"M104", "M109", "M140", "M190", "M141", "M191", "M155", "M105", "G28", "G29", "G34", "G32",
            "M420", "M117", "M73", "M75", "M76", "M77", "M84", "M18", "M201", "M203", "M204", "M205",
            "G9111", "START_PRINT", "PRINT_START", "BED_MESH_CALIBRATE", "BED_MESH_PROFILE",
            "Z_TILT_ADJUST", "QUAD_GANTRY_LEVEL"}
# Shut-down commands after the last print move; the Anycubic end sequence replaces them.
DROP_TAIL = {"M104", "M109", "M140", "M190", "M141", "M107", "M84", "M18", "M81", "M73", "M117", "M300",
             "G28", "END_PRINT", "PRINT_END", "M220", "M221", "M900", "M105", "M82", "M83", "M155"}


def _parse(line: str) -> tuple[str | None, dict[str, float]]:
    code = line.split(";", 1)[0].strip()
    if not code:
        return None, {}
    parts = code.split()
    params: dict[str, float] = {}
    for w in parts[1:]:
        try:
            params[w[0].upper()] = float(w[1:])
        except ValueError:
            pass
    return parts[0].upper(), params


def _fmt(v: float) -> str:
    s = f"{v:.5f}".rstrip("0").rstrip(".")
    return "0" if s in ("", "-0") else s


def _duration(seconds: float) -> str:
    s = int(round(seconds))
    h, rem = divmod(s, 3600)
    m, s = divmod(rem, 60)
    return (f"{h}h " if h else "") + (f"{m}m " if h or m else "") + f"{s}s"


def _layer_height(lines: list[str]) -> tuple[float, float]:
    """(first z, layer height) guessed from the Z values of moves that also extrude."""
    zs: set[float] = set()
    first = None
    for ln in lines:
        m = _ZE_LINE.match(ln)
        if m:
            z = round(float(m.group(1)), 4)
            if first is None:
                first = z
            zs.add(z)
    ordered = sorted(zs)
    diffs: dict[float, int] = {}
    for a, b in zip(ordered, ordered[1:]):
        d = round(b - a, 2)
        if d >= 0.05:
            diffs[d] = diffs.get(d, 0) + 1
    height = max(diffs, key=diffs.get) if diffs else 0.2
    return (first if first else height), height


def _detect_material(lines: list[str], nozzle: int | None) -> str:
    for ln in lines[:4000] + lines[-4000:]:
        m = re.match(r"^;\s*(?:filament_type|material_type|MATERIAL)\s*[=:]\s*\"?([A-Za-z-]+)", ln)
        if m and m.group(1).upper() in profile.MATERIALS:
            return m.group(1).upper()
    if nozzle is None:
        return profile.DEFAULT_MATERIAL
    return "ABS" if nozzle >= 235 else "PETG" if nozzle >= 222 else "PLA"


def _hex_rgb(color: str) -> list[int]:
    c = color.lstrip("#")
    try:
        return [int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16)]
    except ValueError:
        return [255, 122, 26]


# --------------------------------------------------------------------------- core
def fix_lines(src_lines: list[str], name: str, opts: Options,
              progress: Progress | None = None, cancel: threading.Event | None = None
              ) -> tuple[list[str], dict, list[str]]:
    """Returns (output lines, info dict, warnings)."""
    report = progress or (lambda f, m: None)
    first_z, layer_h = _layer_height(src_lines)

    x = y = z = 0.0
    e_last = 0.0
    feed = 1500.0
    xyz_abs, e_abs = True, False
    pre = True
    nozzle_t: int | None = None
    bed_t: int | None = None

    out: list[str] = ["", "", ""]      # layer-0 marker placeholder, patched below
    cum: list[float] = [0.0, 0.0, 0.0]
    t = 0.0
    segs = array("f")
    filament = 0.0
    layer_no = 0
    layer_z = None
    first_layer_z = None
    last_ext = -1
    ext_min_z, ext_max_z = 1e9, 0.0
    bbox = [1e9, 1e9, -1e9, -1e9]
    oob = 0
    oob_first = 0
    total = len(src_lines)

    for i, line in enumerate(src_lines):
        if i % 20000 == 0:
            if cancel is not None and cancel.is_set():
                raise Cancelled()
            report(0.05 + 0.6 * i / max(total, 1), "Rewriting G-code…")
        cmd, p = _parse(line)
        if cmd is None:
            out.append(line.rstrip()); cum.append(t)
            continue

        if cmd == "G90":
            xyz_abs = True
        elif cmd == "G91":
            xyz_abs = False
        elif cmd in ("M82", "M83"):
            e_abs = cmd == "M82"
            continue                                   # we write our own M83
        elif cmd == "G92":
            if "E" in p:
                e_last = p["E"]
            x = p.get("X", x); y = p.get("Y", y); z = p.get("Z", z)
        elif pre and (cmd in DROP_PRE or _TOOL.match(cmd)):
            if cmd in ("M104", "M109") and p.get("S", p.get("R", 0)) > 0:
                nozzle_t = int(round(p.get("S", p.get("R"))))
            elif cmd in ("M140", "M190") and p.get("S", p.get("R", 0)) > 0:
                bed_t = int(round(p.get("S", p.get("R"))))
            continue
        elif not pre and cmd == "M73":
            continue
        elif cmd == "G4":
            t += p.get("P", 0) / 1000 + p.get("S", 0)
        elif cmd in ("G0", "G1", "G2", "G3"):
            if "F" in p:
                feed = p["F"] or feed
            nx = p.get("X", x) if xyz_abs else x + p.get("X", 0.0)
            ny = p.get("Y", y) if xyz_abs else y + p.get("Y", 0.0)
            nz = p.get("Z", z) if xyz_abs else z + p.get("Z", 0.0)
            de = 0.0
            if "E" in p:
                if e_abs:
                    de = p["E"] - e_last
                    e_last = p["E"]
                    line = _E_TOKEN.sub("E" + _fmt(de), line, count=1)
                else:
                    de = p["E"]
            dist = math.hypot(nx - x, ny - y)
            dz = nz - z
            length = math.sqrt(dist * dist + dz * dz)
            speed = max(feed, 1.0) / 60
            if length > 0:
                t += length / min(speed, 15 if dist == 0 else 600)
            elif de:
                t += abs(de) / speed
            moved = length > 0
            if de > 0 and moved:
                # first printing move: setup commands are over from here on
                pre = False
                filament += de
                if layer_z is None:
                    layer_z = first_layer_z = nz
                elif nz >= layer_z + 0.75 * layer_h and cmd in ("G0", "G1"):
                    layer_no += 1
                    out += [";LAYER_CHANGE", f";Z:{nz:g}", f";HEIGHT:{round(nz - layer_z, 4):g}"]
                    cum += [t, t, t]
                    layer_z = nz
                segs.extend((x, y, nx, ny, nz))
                bbox[0] = min(bbox[0], nx, x); bbox[1] = min(bbox[1], ny, y)
                bbox[2] = max(bbox[2], nx, x); bbox[3] = max(bbox[3], ny, y)
                ext_min_z = min(ext_min_z, nz); ext_max_z = max(ext_max_z, nz)
                if not (-1 <= nx <= profile.BED_X + 1 and -1 <= ny <= profile.BED_Y + 6):   # Y≈255 = Anycubic's purge line
                    oob += 1
                    oob_first = oob_first or i + 1
                last_ext = len(out)
            else:
                filament += de          # retractions / E-only primes
            x, y, z = nx, ny, nz
        # anything else (M106, M220, comments, custom macros...) passes through unchanged
        out.append(line.rstrip()); cum.append(t)

    if last_ext < 0:
        raise ConvertError("No printing moves found - is this really G-code?")

    # ---- tail: drop the source's shut-down commands, keep trailing comments as a footer
    tail_lines, tail_cum, footer = [], [], []
    for ln, ct in zip(out[last_ext + 1:], cum[last_ext + 1:]):
        c, p = _parse(ln)
        if c is None:
            if ln.strip():
                footer.append(ln)
            continue
        if c in DROP_TAIL or (c == "M106" and p.get("S", 0) == 0):
            continue
        tail_lines.append(ln); tail_cum.append(ct)
    out = out[:last_ext + 1] + tail_lines
    cum = cum[:last_ext + 1] + tail_cum

    # ---- patch layer 0 marker + optional purge line
    out[0:3] = [";LAYER_CHANGE", f";Z:{first_layer_z:g}", f";HEIGHT:{first_layer_z:g}"]
    if opts.purge_line:
        out[3:3] = profile.PURGE_LINE
        cum[3:3] = [0.0] * len(profile.PURGE_LINE)

    # ---- temperatures / material
    mat_name = opts.material.upper()
    if mat_name not in profile.MATERIALS:
        mat_name = _detect_material(src_lines, nozzle_t)
    mat = profile.material(mat_name)
    nozzle = nozzle_t if (opts.use_file_temps and nozzle_t) else mat.nozzle_first
    bed = bed_t if (opts.use_file_temps and bed_t) else mat.bed

    # ---- progress (M73) lines
    total_time = max(t, 1.0)

    def m73(pct: int, remaining: float) -> str:
        r, q, s = remaining / 60, remaining * profile.QUIET_FACTOR / 60, remaining * profile.SPORT_FACTOR / 60
        if pct == 0:
            return f"M73 P0 R{r:.1f} QuietR{q:.1f} SportR{s:.1f} ; NormalR{remaining:.3f}s"
        return f"M73 P{pct} R{int(r)} QuietR{int(q)} SportR{int(s)} ; NormalR{remaining:.3f}s"

    body: list[str] = []
    last_pct = 0
    for ln, ct in zip(out, cum):
        body.append(ln)
        pct = int(100 * ct / total_time)
        if pct > last_pct and pct < 100:
            last_pct = pct
            body.append(m73(pct, total_time - ct))

    # ---- statistics
    area = math.pi * (profile.FILAMENT_DIAMETER / 2) ** 2
    filament = max(filament, 0.0)
    cm3 = filament * area / 1000
    grams = cm3 * mat.density
    layers = layer_no + 1
    size = (bbox[2] - bbox[0], bbox[3] - bbox[1], ext_max_z)
    tstr = _duration(total_time)

    warnings: list[str] = []
    if oob:
        warnings.append(f"{oob} printing moves lie outside the {profile.BED_X:g}×{profile.BED_Y:g} mm bed "
                        f"(first near line {oob_first})")
    if ext_max_z > profile.MAX_Z:
        warnings.append(f"model is {ext_max_z:.1f} mm tall, the printer manages {profile.MAX_Z:g} mm")

    # ---- thumbnails
    report(0.68, "Rendering thumbnails…")
    if cancel is not None and cancel.is_set():
        raise Cancelled()
    png_small = thumbnail.render(segs, 230, 110, opts.color, "iso")
    report(0.8, "Rendering thumbnails…")
    png_top = thumbnail.render(segs, 512, 512, opts.color, "top")

    # ---- assemble
    stem = re.sub(r"[^\w.\- ]", "_", Path(name).stem)
    now = time.localtime()
    paint = [{"material_type": mat.name, "paint_color": _hex_rgb(opts.color), "paint_index": 0}]
    dens = [mat.density, 1.24, 1.24, 1.24]
    res: list[str] = [
        "; HEADER_BLOCK_START",
        f"; generated by {profile.SLICER_NAME} {profile.SLICER_VERSION} on "
        f"{time.strftime('%Y-%m-%d', now)} at {time.strftime('%H:%M:%S', now)}",
        f"; total layer number: {layers}",
        "; filament_density: " + ",".join(f"{d:g}" for d in dens),
        "; filament_diameter: " + ",".join([f"{profile.FILAMENT_DIAMETER:g}"] * 4),
        f"; max_z_height: {ext_max_z:.2f}",
        "; exclude_object: 0",
        "; model_instances: 1",
        "; source_info: " + json.dumps({"models": [{"file_source": 0, "mo_file_id": -1, "name": stem}],
                                         "models_from": 0, "plate_index": 1, "slice_paras_process": 2,
                                         "software_version": f"{profile.SLICER_NAME} {profile.SLICER_VERSION} "
                                                             f"{profile.SLICER_BUILD}"}, separators=(",", ":")),
        "; paint_info = " + json.dumps(paint, separators=(",", ":")),
        "; project_info = " + profile.PROJECT_INFO,
        "; flush_multiplier_calculate_by_acnext: 1",
        "; test_mode: 0",
        "; HEADER_BLOCK_END",
        "",
        *thumbnail.block(png_small, 230, 110),
        "",
        *thumbnail.block(png_top, 512, 512, "top"),
        "",
        f"; toolpath imported from \"{Path(name).name}\" and re-wrapped by Anycubic GcodeFix",
        "",
        "; EXECUTABLE_BLOCK_START",
        m73(0, total_time),
        *profile.start_gcode(bed, nozzle, mat, opts.pressure_advance),
        "M204 S10000 ; default acceleration",
        *body,
        *profile.end_gcode(ext_max_z),
        "; EXECUTABLE_BLOCK_END",
        "",
        *footer,
        *([""] if footer else []),
        f"; filament used [mm] = {filament:.2f}, 0.00, 0.00, 0.00",
        f"; filament used [cm3] = {cm3:.2f}, 0.00, 0.00, 0.00",
        f"; filament used [g] = {grams:.2f}, 0.00, 0.00, 0.00",
        f"; filament cost = {grams * 0.04:.2f}, 0.00, 0.00, 0.00",
        f"; total filament used [g] = {grams:.2f}",
        f"; total filament cost = {grams * 0.04:.2f}",
        f"; total layers count = {layers}",
        f"; estimated printing time (normal mode) = {tstr}",
        f"; estimated printing time (silent mode) = {_duration(total_time * profile.QUIET_FACTOR)}",
        f"; estimated printing time (sport mode) = {_duration(total_time * profile.SPORT_FACTOR)}",
        "",
        "; CONFIG_BLOCK_START = begin",
        "; AnycubicSlicer_config = begin",
        *_config(mat, nozzle, bed, opts.color, first_layer_z),
        "; AnycubicSlicer_config = end",
        "; CONFIG_BLOCK_END = end",
        "",
        "",
        "",
        "; ams_info = begin",
        "; paint_info = " + json.dumps(paint, separators=(",", ":")),
        "; ams_info = end",
        "",
        "; statistics = begin",
        f"; used_filament = {filament / 1000:.2f}",
        f"; print_time = {tstr}",
        f"; model_size = {size[0]:.2f},{size[1]:.2f},{size[2]:.2f}",
        f"; total_layers = {layers}",
        "; statistics = end",
    ]
    validate(res)

    info = {
        "layers": layers, "seconds": round(total_time), "time": tstr, "grams": round(grams, 2),
        "material": mat.name, "nozzle": nozzle, "bed": bed, "size": [round(v, 2) for v in size],
        "thumb": "data:image/png;base64," + base64.b64encode(png_small).decode("ascii"),
    }
    return res, info, warnings


def _config(mat: profile.Material, nozzle: int, bed: int, color: str, first_z: float) -> list[str]:
    rows = [r for r in profile.config_lines() if not r.startswith("; extruder_colour")]
    rows += [
        f"; extruder_colour = {color.upper()};#FFFF00;#FFFFFF;#00FFFF",
        f"; filament_colour = {color.upper()};#FFFF00;#FFFFFF;#00FFFF",
        f"; filament_type = {mat.name};PLA;PLA;PLA",
        f"; filament_density = {mat.density:g},1.24,1.24,1.24",
        f"; filament_diameter = {profile.FILAMENT_DIAMETER:g},1.75,1.75,1.75",
        f"; filament_settings_id = \"Anycubic {mat.name} @{profile.PRINTER_MODEL} 0.4 nozzle\"",
        f"; nozzle_temperature = {nozzle},210,210,210",
        f"; nozzle_temperature_initial_layer = {nozzle},220,220,220",
        f"; hot_plate_temp = {bed},55,55,55",
        f"; hot_plate_temp_initial_layer = {bed},55,55,55",
        f"; first_layer_height = {first_z:.3f}",
        f"; first_layer_temperature = {nozzle}",
        f"; first_layer_bed_temperature = {bed}",
        f"; bed_temperature = {bed}",
    ]
    return rows


def validate(lines: list[str]) -> None:
    """Sanity-check the layout we promise the printer. Raises ConvertError if something is off."""
    marks = ["; HEADER_BLOCK_START", "; HEADER_BLOCK_END", "; THUMBNAIL_BLOCK_START", "; EXECUTABLE_BLOCK_START",
             "; EXECUTABLE_BLOCK_END", "; CONFIG_BLOCK_START = begin", "; CONFIG_BLOCK_END = end"]
    pos = []
    for m in marks:
        try:
            pos.append(lines.index(m))
        except ValueError:
            raise ConvertError(f"internal error: missing marker {m!r}") from None
    if pos != sorted(pos):
        raise ConvertError("internal error: blocks are out of order")
    body = lines[pos[3]:pos[4]]
    if any(re.match(r"^M82\b", ln) for ln in body):
        raise ConvertError("internal error: absolute extrusion left in output")
    if not any(ln.startswith("G9111 ") for ln in body):
        raise ConvertError("internal error: start sequence missing")


# --------------------------------------------------------------------------- file level
def _unique(path: Path, overwrite: str) -> Path:
    if overwrite == "overwrite" or not path.exists():
        return path
    n = 2
    while True:
        cand = path.with_name(f"{path.stem} ({n}){path.suffix}")
        if not cand.exists():
            return cand
        n += 1


def convert(src: Path, out_dir: Path, opts: Options, overwrite: str = "rename",
            progress: Progress | None = None, cancel: threading.Event | None = None) -> Result:
    report = progress or (lambda f, m: None)
    report(0.0, "Reading…")
    try:
        raw = src.read_bytes()
    except OSError as exc:
        raise ConvertError(f"Can't read the file: {exc.strerror or exc}") from exc
    if raw[:4] == b"GCDE":
        raise ConvertError("Binary G-code (.bgcode) isn't supported - export plain G-code from your slicer.")
    text = raw.decode("utf-8", errors="surrogateescape")
    if is_anycubic(text[:262144]):
        return Result("skipped", None, "Already in Anycubic format - nothing to fix")

    lines = text.splitlines()
    out_lines, info, warnings = fix_lines(lines, src.name, opts, report, cancel)

    out_dir.mkdir(parents=True, exist_ok=True)
    dest = _unique(out_dir / f"{src.stem}{SUFFIX}.gcode", overwrite)
    report(0.92, "Writing…")
    tmp = dest.with_name(dest.name + ".part")
    try:
        # newline="\n": keep LF like the slicer does (Windows would otherwise write CRLF)
        tmp.write_text("\n".join(out_lines) + "\n", encoding="utf-8", errors="surrogateescape", newline="\n")
        tmp.replace(dest)
    except OSError as exc:
        tmp.unlink(missing_ok=True)
        raise ConvertError(f"Can't write {dest.name}: {exc.strerror or exc}") from exc
    report(1.0, "Done")
    msg = (f"{info['layers']} layers · ~{info['time']} · {info['material']} "
           f"{info['nozzle']}/{info['bed']}°C · {info['grams']} g")
    return Result("done", dest, msg, "; ".join(warnings), info)
