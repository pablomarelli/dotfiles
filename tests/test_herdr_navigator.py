import os
import runpy
import subprocess
import unittest
from pathlib import Path
from unittest.mock import patch


SOURCE = Path(__file__).resolve().parents[1] / "private_dot_config/herdr/bin/executable_herdr-navigator.tmpl"


class NavigatorTests(unittest.TestCase):
    def test_executable_resolution(self) -> None:
        navigator = runpy.run_path(str(SOURCE))
        for value, expected in (("/opt/herdr/bin/herdr", "/opt/herdr/bin/herdr"), (None, "herdr"), ("", "herdr")):
            with self.subTest(value=value), patch.dict(os.environ, {}, clear=True):
                if value is not None:
                    os.environ["HERDR_BIN_PATH"] = value
                result = subprocess.CompletedProcess((expected,), 0, stdout="ok", stderr="")
                with patch("shutil.which", return_value=value), patch("subprocess.run", return_value=result) as run:
                    self.assertEqual(navigator["herdr"]("pane", "current"), "ok")
                    run.assert_called_once_with((expected, "pane", "current"), text=True, capture_output=True)

    def test_deleted_configured_executable_falls_back_to_path(self) -> None:
        navigator = runpy.run_path(str(SOURCE))
        result = subprocess.CompletedProcess(("herdr",), 0, stdout="ok", stderr="")
        with patch.dict(os.environ, {"HERDR_BIN_PATH": "/deleted/herdr"}):
            with patch("shutil.which", return_value=None), patch("subprocess.run", return_value=result) as run:
                self.assertEqual(navigator["herdr"]("pane", "current"), "ok")
                run.assert_called_once_with(("herdr", "pane", "current"), text=True, capture_output=True)

    def test_navigation_routes(self) -> None:
        runpy.run_path(str(SOURCE))["self_check"]()


if __name__ == "__main__":
    unittest.main()
