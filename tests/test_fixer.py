import tempfile
import unittest
from array import array
from pathlib import Path

from gcodefix import fixer, thumbnail

SRC = """; made by some tool
M82
G28
M140 S60
M104 S245
M190 S60
M109 S245
G92 E0
G1 Z0.3 F600
G1 X10 Y10 F3000
G1 X50 Y10 E4 F1200
G1 X50 Y20 E5
G92 E0
G1 Z0.6 F600
G1 X10 Y20 E1.5 F1500
G1 X10 Y30 E3
G1 E1.5 F1800
G1 Z5
M104 S0
M140 S0
M84
; trailing note
"""


def run(text, **kw):
    return fixer.fix_lines(text.splitlines(), "part.gcode", fixer.Options(**kw))


class FixerTests(unittest.TestCase):
    def test_structure_and_markers(self):
        lines, info, _ = run(SRC)
        fixer.validate(lines)
        self.assertEqual(lines[0], "; HEADER_BLOCK_START")
        self.assertTrue(fixer.is_anycubic("\n".join(lines)))
        self.assertIn("G9111 bedTemp=60 extruderTemp=245", lines)
        self.assertEqual(info["material"], "ABS")        # 245 °C -> ABS guess

    def test_setup_commands_removed_only_in_preamble(self):
        lines, _, _ = run(SRC)
        body = lines[lines.index("; EXECUTABLE_BLOCK_START"):lines.index("; EXECUTABLE_BLOCK_END")]
        self.assertFalse(any(l.startswith(("G28", "M82", "M109", "M190")) for l in body))
        self.assertIn("; trailing note", lines)
        # the source's shut-down commands are replaced by Anycubic's end sequence (exactly one M84)
        self.assertEqual(sum(l.startswith("M84") for l in body), 1)

    def test_absolute_extrusion_becomes_relative(self):
        lines, _, _ = run(SRC)
        self.assertIn("G1 X50 Y10 E4 F1200", lines)
        self.assertIn("G1 X50 Y20 E1", lines)            # 5 - 4
        self.assertIn("G1 X10 Y20 E1.5 F1500", lines)    # after G92 E0
        self.assertIn("G1 X10 Y30 E1.5", lines)          # 3 - 1.5
        self.assertIn("G1 E-1.5 F1800", lines)           # 1.5 - 3 = retraction

    def test_temps_from_file_or_material_defaults(self):
        lines, _, _ = run(SRC, use_file_temps=False, material="PLA")
        self.assertIn("G9111 bedTemp=55 extruderTemp=220", lines)

    def test_layer_markers_and_stats(self):
        lines, info, _ = run(SRC)
        self.assertEqual(lines[lines.index(";LAYER_CHANGE") + 1], ";Z:0.3")
        self.assertEqual(info["layers"], 2)
        self.assertIn("; total layer number: 2", lines)
        self.assertTrue(any(l.startswith("M73 P100") for l in lines))

    def test_out_of_bed_warning(self):
        _, _, warns = run(SRC.replace("X50 Y10 E4", "X300 Y10 E4"))
        self.assertTrue(warns and "outside" in warns[0])

    def test_no_extrusion_is_an_error(self):
        with self.assertRaises(fixer.ConvertError):
            run("G28\nG1 X10 Y10\n")

    def test_convert_roundtrip_and_skip(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            src = d / "part.gcode"
            src.write_text(SRC)
            res = fixer.convert(src, d, fixer.Options())
            self.assertEqual(res.status, "done")
            self.assertEqual(res.output.name, "part_anycubic.gcode")
            again = fixer.convert(res.output, d, fixer.Options())
            self.assertEqual(again.status, "skipped")
            second = fixer.convert(src, d, fixer.Options())      # name collision -> renamed
            self.assertEqual(second.output.name, "part_anycubic (2).gcode")

    def test_crlf_input_and_lf_output(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            src = d / "win.gcode"
            src.write_bytes(SRC.replace("\n", "\r\n").encode())
            res = fixer.convert(src, d, fixer.Options())
            self.assertEqual(res.status, "done")
            data = res.output.read_bytes()
            self.assertNotIn(b"\r", data)
            self.assertIn(b"G9111 bedTemp=60 extruderTemp=245\n", data)

    def test_binary_gcode_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "x.gcode"
            f.write_bytes(b"GCDE\x01\x00\x00")
            with self.assertRaises(fixer.ConvertError):
                fixer.convert(f, Path(d), fixer.Options())

    def test_expand_inputs(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            (d / "sub").mkdir()
            (d / "a.gcode").write_text("G1")
            (d / "sub" / "b.GCO").write_text("G1")
            (d / "c.txt").write_text("x")
            self.assertEqual([p.name for p in fixer.expand_inputs([str(d)])], ["a.gcode", "b.GCO"])


class ThumbnailTests(unittest.TestCase):
    def test_png_and_block_format(self):
        segs = array("f", [10, 10, 40, 10, 0.2, 40, 10, 40, 40, 0.4])
        png = thumbnail.render(segs, 230, 110, "#ff7a1a")
        self.assertTrue(png.startswith(b"\x89PNG"))
        blk = thumbnail.block(png, 230, 110)
        self.assertTrue(blk[1].startswith("; thumbnail begin 230x110 "))
        self.assertTrue(all(len(l) <= 80 for l in blk))


if __name__ == "__main__":
    unittest.main()
