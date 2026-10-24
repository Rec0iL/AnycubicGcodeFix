"""Anycubic Kobra S1 profile: everything copied from what AnycubicSlicerNext itself writes."""
from __future__ import annotations

from pathlib import Path

# The printer / its app look for this banner and the *_BLOCK_* markers, so we write them the
# same way the slicer does. Change it here if a future firmware wants a newer version string.
SLICER_NAME = "AnycubicSlicerNext"
SLICER_VERSION = "1.3.9.4"
SLICER_BUILD = "20260319224604"

PRINTER_MODEL = "Anycubic Kobra S1"
BED_X, BED_Y, MAX_Z = 250.0, 250.0, 250.0
FILAMENT_DIAMETER = 1.75
NOZZLE_DIAMETER = 0.4

# Machine limits block, verbatim from the slicer's start of every file.
MACHINE_LIMITS = [
    "M201 X20000 Y20000 Z1000 E20000",
    "M203 X600 Y600 Z15 E600",
    "M204 P20000 R20000 T20000",
    "M205 X15.00 Y15.00 Z15.00 E15.00",
]

# time estimate ratios seen in slicer output (silent / sport relative to normal mode)
QUIET_FACTOR = 1.92
SPORT_FACTOR = 0.79

PROJECT_INFO = ('{"flush_multiplier":1.0,"flush_volumes_chan_multipliers":[1.0,1.0,1.0,1.0],'
                '"flush_volumes_matrix":[0.0,710.0,612.0,630.0,246.0,0.0,280.0,280.0,178.0,280.0,0.0,'
                '280.0,234.0,280.0,280.0,0.0],"flush_volumes_vector":[140.0,140.0,140.0,140.0,140.0,'
                '140.0,140.0,140.0]}')

# Anycubic's own purge line (printed on layer 0 by before_layer_change_gcode); accel/retract lines left out
# on purpose because they would leak into the rest of a foreign file.
PURGE_LINE = [
    " ; PURGE LINE",
    "G1 Z0.50 F900",
    "G1 X89.365 Y255 F18000",
    "G1 Z.25 F900",
    "G1 E0.8 F2400",
    "G1 E0.6",
    "G1 F3000",
    "G1 X158.835 Y255 E3.72454",
    "G1 X158.835 Y255.45 E.0252",
    "G1 X89.365 Y255.45 E3.72454",
    "G1 X89.365 Y255.02 E.02305",
    "G1 Z0.5 F600",
]


class Material:
    def __init__(self, name: str, nozzle: int, nozzle_first: int, bed: int, density: float,
                 pressure_advance: float | None, fan_max: int):
        self.name, self.nozzle, self.nozzle_first = name, nozzle, nozzle_first
        self.bed, self.density, self.pressure_advance, self.fan_max = bed, density, pressure_advance, fan_max


# PLA / PETG values are what the Kobra S1 profiles ship with; ABS / TPU are common
# defaults used only when the file itself doesn't say which temperatures it wants.
MATERIALS = {m.name: m for m in (
    Material("PLA", 210, 220, 55, 1.24, 0.035, 100),
    Material("PETG", 230, 230, 75, 1.27, 0.04, 90),
    Material("ABS", 250, 250, 90, 1.04, None, 50),
    Material("TPU", 225, 225, 50, 1.21, None, 100),
)}
DEFAULT_MATERIAL = "PLA"


def material(name: str) -> Material:
    return MATERIALS.get(name.upper(), MATERIALS[DEFAULT_MATERIAL])


def config_lines() -> list[str]:
    """Trimmed machine section of the slicer's config block (printer-only, no print settings)."""
    return (Path(__file__).parent / "data" / "kobra_s1_config.txt").read_text(encoding="utf-8").splitlines()


def start_gcode(bed: int, nozzle: int, mat: Material, pressure_advance: bool) -> list[str]:
    """Machine start + filament start, in the order the slicer emits them (minus the M73 line)."""
    out = list(MACHINE_LIMITS)
    out += ["M106 S0", "M106 P2 S0", ";TYPE:Custom",
            f"G9111 bedTemp={bed} extruderTemp={nozzle}",
            "M117", "G90", "G21", "M83 ; use relative distances for extrusion",
            "; EXECUTABLE_BLOCK_HEAD", "; filament start gcode"]
    if pressure_advance and mat.pressure_advance:
        out.append(f"M900 K{mat.pressure_advance}; Override pressure advance value")
    out += ["T0", "M75 ; The first extruder is ready.", "M106 S0", "M106 P2 S0"]
    return out


def end_gcode(max_z: float) -> list[str]:
    lift = min(max_z + 2, MAX_Z)
    return [
        "G90", "M83",
        "G92 E0", "G1 E-2 F3000",
        *([f"G1 Z{lift:g} F900 ; Move print head further up"] if max_z < MAX_Z - 1 else []),
        "G1 F12000; present print", "G1 X44;  throw_position_x", "G1 Y270; throw_position_y",
        "M140 S0 ; turn off heatbed", "M104 S0 ; turn off temperature", "M106 P1 S0 ; turn off fan",
        "M106 P2 S0", "M106 P3 S0", "M84; disable motors",
        "; disable stepper motors",
        "M73 P100 R0 QuietR0 SportR0 ; NormalR0s",
    ]
