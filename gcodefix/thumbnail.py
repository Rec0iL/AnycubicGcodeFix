"""Tiny software renderer: turns the extruded toolpath into the PNG thumbnails Anycubic shows.

Pure Python (zlib + struct), so the converter has no GUI dependency.
"""
from __future__ import annotations

import base64
import math
import struct
import zlib
from array import array


def png_bytes(width: int, height: int, rgba: bytearray) -> bytes:
    stride = width * 4
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        raw += rgba[y * stride:(y + 1) * stride]

    def chunk(tag: bytes, data: bytes) -> bytes:
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(raw), 6))
            + chunk(b"IEND", b""))


def _parse_hex(color: str) -> tuple[int, int, int]:
    c = color.lstrip("#")
    if len(c) == 3:
        c = "".join(ch * 2 for ch in c)
    try:
        return int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16)
    except ValueError:
        return 255, 138, 61


def render(segments: array, width: int, height: int, color: str, view: str = "iso",
           max_segments: int = 600_000) -> bytes:
    """segments: flat array('f') of x0, y0, x1, y1, z (per extruded segment). Returns PNG bytes."""
    n = len(segments) // 5
    rgba = bytearray(width * height * 4)
    if n == 0:
        return png_bytes(width, height, rgba)

    step = max(1, n // max_segments)
    xs = segments[0::5]; ys = segments[1::5]; zs = segments[4::5]
    cx = (min(xs) + max(xs)) / 2
    cy = (min(ys) + max(ys)) / 2
    zmax = max(zs) or 1.0

    if view == "top":
        ang, elev = 0.0, math.pi / 2
    else:
        ang, elev = math.radians(40), math.radians(35)
    ca, sa = math.cos(ang), math.sin(ang)
    se, ce = math.sin(elev), math.cos(elev)

    def project(x: float, y: float, z: float) -> tuple[float, float, float]:
        u = (x - cx) * ca - (y - cy) * sa
        v = (x - cx) * sa + (y - cy) * ca
        return u, -(v * se + z * ce), -v * ce + z * se   # screen x, screen y, depth toward viewer

    # fit the projected bounding box into the canvas
    pts = [project(x, y, z) for x, y, z in ((min(xs), min(ys), 0), (max(xs), min(ys), 0),
                                           (min(xs), max(ys), 0), (max(xs), max(ys), 0),
                                           (min(xs), min(ys), zmax), (max(xs), min(ys), zmax),
                                           (min(xs), max(ys), zmax), (max(xs), max(ys), zmax))]
    minx = min(p[0] for p in pts); maxx = max(p[0] for p in pts)
    miny = min(p[1] for p in pts); maxy = max(p[1] for p in pts)
    margin = 0.08
    scale = min(width * (1 - 2 * margin) / max(maxx - minx, 1e-6),
                height * (1 - 2 * margin) / max(maxy - miny, 1e-6))
    ox = width / 2 - (minx + maxx) / 2 * scale
    oy = height / 2 - (miny + maxy) / 2 * scale
    stamp = max(1, round(0.5 * scale))      # extrusion width in pixels
    half = stamp // 2

    r0, g0, b0 = _parse_hex(color)
    palette = []
    for i in range(32):                      # darker at the bed, full colour at the top
        k = 0.45 + 0.55 * i / 31
        palette.append((int(r0 * k), int(g0 * k), int(b0 * k)))
    depth_buf = [-1e9] * (width * height)

    for i in range(0, n, step):
        j = i * 5
        x0, y0, x1, y1, z = segments[j:j + 5]
        sx0, sy0, d0 = project(x0, y0, z)
        sx1, sy1, d1 = project(x1, y1, z)
        px0, py0 = sx0 * scale + ox, sy0 * scale + oy
        px1, py1 = sx1 * scale + ox, sy1 * scale + oy
        steps = max(1, int(max(abs(px1 - px0), abs(py1 - py0))))
        r, g, b = palette[min(31, int(31 * z / zmax))]
        for s in range(steps + 1):
            t = s / steps
            px = int(px0 + (px1 - px0) * t) - half
            py = int(py0 + (py1 - py0) * t) - half
            d = d0 + (d1 - d0) * t
            for yy in range(max(py, 0), min(py + stamp, height)):
                row = yy * width
                for xx in range(max(px, 0), min(px + stamp, width)):
                    if d >= depth_buf[row + xx]:
                        depth_buf[row + xx] = d
                        o = (row + xx) * 4
                        rgba[o] = r; rgba[o + 1] = g; rgba[o + 2] = b; rgba[o + 3] = 255
    return png_bytes(width, height, rgba)


def block(png: bytes, width: int, height: int, tag: str = "") -> list[str]:
    """Format PNG bytes the way the slicer embeds them in the G-code header."""
    b64 = base64.b64encode(png).decode("ascii")
    head = f"; thumbnail begin {width}x{height} {len(b64)}" + (f" {tag}" if tag else "")
    lines = ["; THUMBNAIL_BLOCK_START", head]
    lines += ["; " + b64[i:i + 78] for i in range(0, len(b64), 78)]
    lines += ["; thumbnail end", "; THUMBNAIL_BLOCK_END"]
    return lines
