#!/usr/bin/env python3
"""Dev tool: render anycubic-gcodefix.svg into .png / .ico / .icns (committed, so users never need this).

    python3 packaging/make_icons.py
"""
import os
import struct
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
from PySide6.QtCore import QBuffer, QByteArray, QIODevice
from PySide6.QtGui import QGuiApplication, QImage, QPainter
from PySide6.QtSvg import QSvgRenderer

HERE = Path(__file__).resolve().parent
NAME = "anycubic-gcodefix"


def png(renderer: QSvgRenderer, size: int) -> bytes:
    img = QImage(size, size, QImage.Format.Format_ARGB32)
    img.fill(0)
    p = QPainter(img)
    renderer.render(p)
    p.end()
    buf = QBuffer()
    buf.open(QIODevice.OpenModeFlag.WriteOnly)
    img.save(buf, "PNG")
    return bytes(QByteArray(buf.data()))


def ico(images: dict[int, bytes]) -> bytes:
    """Vista+ ICO with PNG-compressed entries (256 px is stored as width/height 0)."""
    head = struct.pack("<HHH", 0, 1, len(images))
    offset = 6 + 16 * len(images)
    entries, blobs = b"", b""
    for size, data in images.items():
        entries += struct.pack("<BBBBHHII", size % 256, size % 256, 0, 0, 1, 32, len(data), offset)
        blobs += data
        offset += len(data)
    return head + entries + blobs


def icns(images: dict[int, bytes]) -> bytes:
    kinds = {16: b"icp4", 32: b"icp5", 64: b"icp6", 128: b"ic07", 256: b"ic08", 512: b"ic09", 1024: b"ic10"}
    body = b"".join(kinds[s] + struct.pack(">I", 8 + len(d)) + d for s, d in images.items() if s in kinds)
    return b"icns" + struct.pack(">I", 8 + len(body)) + body


def main() -> int:
    app = QGuiApplication(sys.argv)  # noqa: F841 - Qt needs one alive for painting
    r = QSvgRenderer(str(HERE / f"{NAME}.svg"))
    if not r.isValid():
        print("bad svg", file=sys.stderr)
        return 1
    sizes = [16, 32, 48, 64, 128, 256, 512, 1024]
    imgs = {s: png(r, s) for s in sizes}
    (HERE / f"{NAME}.png").write_bytes(imgs[256])
    (HERE / f"{NAME}.ico").write_bytes(ico({s: imgs[s] for s in (16, 32, 48, 64, 128, 256)}))
    (HERE / f"{NAME}.icns").write_bytes(icns({s: imgs[s] for s in (16, 32, 64, 128, 256, 512, 1024)}))
    print("wrote", ", ".join(f"{NAME}.{e}" for e in ("png", "ico", "icns")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
