import os
import unittest
from pathlib import Path
from unittest import mock

from gcodefix import settings


class ConfigDirTests(unittest.TestCase):
    def test_windows_uses_appdata(self):
        with mock.patch.object(settings.sys, "platform", "win32"), \
                mock.patch.dict(os.environ, {"APPDATA": "/fake/AppData/Roaming"}):
            self.assertEqual(settings.config_dir(), Path("/fake/AppData/Roaming/AnycubicGcodeFix"))

    def test_macos_uses_application_support(self):
        with mock.patch.object(settings.sys, "platform", "darwin"):
            self.assertEqual(settings.config_dir(),
                             Path.home() / "Library" / "Application Support" / "AnycubicGcodeFix")

    def test_linux_honours_xdg(self):
        with mock.patch.object(settings.sys, "platform", "linux"), \
                mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": "/fake/xdg"}):
            self.assertEqual(settings.config_dir(), Path("/fake/xdg/AnycubicGcodeFix"))

    def test_linux_default(self):
        env = {k: v for k, v in os.environ.items() if k != "XDG_CONFIG_HOME"}
        with mock.patch.object(settings.sys, "platform", "linux"), mock.patch.dict(os.environ, env, clear=True):
            self.assertEqual(settings.config_dir(), Path.home() / ".config" / "AnycubicGcodeFix")


if __name__ == "__main__":
    unittest.main()
