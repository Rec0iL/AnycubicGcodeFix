"""Headless use:  python3 -m gcodefix.cli file.gcode [more files / folders] [--out DIR]"""
from __future__ import annotations

import sys
from pathlib import Path

from . import fixer


def main(argv: list[str]) -> int:
    out = None
    args = []
    it = iter(argv)
    for a in it:
        if a == "--out":
            out = Path(next(it))
        else:
            args.append(a)
    files = fixer.expand_inputs(args)
    if not files:
        print("No G-code files given.", file=sys.stderr)
        return 1
    rc = 0
    for f in files:
        try:
            r = fixer.convert(f, out or f.parent, fixer.Options())
            print(f"{r.status:8} {f.name} -> {r.output.name if r.output else '-'}  {r.message}"
                  + (f"  ⚠ {r.warning}" if r.warning else ""))
        except fixer.ConvertError as exc:
            rc = 1
            print(f"error    {f.name}: {exc}", file=sys.stderr)
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
