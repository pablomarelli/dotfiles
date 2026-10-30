import json
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEMP = Path.home() / ".tmp/opencode"


class ShellIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        TEMP.mkdir(parents=True, exist_ok=True)

    def test_zoxide_initializes_each_time_without_reading_or_writing_cache(self) -> None:
        with tempfile.TemporaryDirectory(dir=TEMP) as directory:
            home = Path(directory)
            binary = home / "bin/zoxide"
            binary.parent.mkdir()
            binary.write_text('#!/bin/sh\nprintf "init\\n" >> "$HOME/calls"\nprintf "export ZOXIDE_VALUE=fresh\\n"\n')
            binary.chmod(0o755)
            cache = home / ".cache/zsh/zoxide_init.zsh"
            cache.parent.mkdir(parents=True)
            cache.write_text("export ZOXIDE_VALUE=stale\n")
            result = subprocess.run(
                ["zsh", "-df", "-c", 'source "$1"; source "$1"; print -r -- "$ZOXIDE_VALUE"', "zsh", str(ROOT / "private_dot_config/zsh/cli-tools.zsh")],
                env=dict(os.environ, HOME=str(home), PATH=f"{binary.parent}:/usr/bin:/bin"),
                text=True, capture_output=True, check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), "fresh")
            self.assertEqual((home / "calls").read_text().splitlines(), ["init", "init"])
            self.assertEqual(cache.read_text(), "export ZOXIDE_VALUE=stale\n")

    def test_python_launcher_uses_dotfiles_python_version(self) -> None:
        with tempfile.TemporaryDirectory(dir=TEMP) as directory:
            home = Path(directory)
            mise = home / ".local/bin/mise"
            mise.parent.mkdir(parents=True)
            mise.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
            mise.chmod(0o755)
            result = subprocess.run(
                ["sh", str(ROOT / "private_dot_config/herdr/bin/executable_herdr-python"), "herdr-navigator", "left", "h", "--status"],
                env=dict(os.environ, HOME=str(home)), text=True, capture_output=True, check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            args = result.stdout.splitlines()
            self.assertEqual(args[:6], ["exec", "--fresh-env", "-C", str(home), "python@3.14", "--"])
            self.assertEqual(args[-4:], [str(home / ".config/herdr/bin/herdr-navigator"), "left", "h", "--status"])

    @unittest.skipUnless(sys.platform == "darwin", "macOS detached-command regression")
    def test_macos_login_shell_runs_navigator_with_mise_python(self) -> None:
        mise = shutil.which("mise")
        if not mise:
            self.skipTest("mise is not installed")
        installed = subprocess.run(
            [mise, "where", "python@3.14"], text=True, capture_output=True, check=False,
        )
        if installed.returncode:
            self.skipTest("mise Python 3.14 is not installed")
        with tempfile.TemporaryDirectory(dir=TEMP) as directory:
            home = Path(directory)
            mise_link = home / ".local/bin/mise"
            mise_link.parent.mkdir(parents=True)
            mise_link.symlink_to(Path(mise).resolve())
            helper = home / ".config/herdr/bin/herdr-navigator"
            helper.parent.mkdir(parents=True)
            shutil.copyfile(ROOT / "private_dot_config/herdr/bin/executable_herdr-navigator.tmpl", helper)
            launcher = ROOT / "private_dot_config/herdr/bin/executable_herdr-python"
            # Herdr uses /bin/sh -lc for detached shortcuts on macOS.
            result = subprocess.run(
                ["/bin/sh", "-lc", f"/bin/sh {shlex.quote(str(launcher))} herdr-navigator --self-test"],
                env=dict(
                    os.environ, HOME=str(home),
                    MISE_DATA_DIR=str(Path(installed.stdout.strip()).parents[2]),
                    MISE_CONFIG_DIR=str(home / ".config/mise"),
                ), cwd=home, text=True, capture_output=True, timeout=30, check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_herdr_status_command_matches_os(self) -> None:
        chezmoi = shutil.which("chezmoi")
        if not chezmoi:
            self.skipTest("chezmoi is not installed")
        template = ROOT / "private_dot_config/herdr/config.toml.tmpl"
        for os_name, expected, excluded in (
            ("darwin", 'sh "$HOME/.config/herdr/status.sh"', 'sh "$HOME/.config/herdr/bin/herdr-system-health"'),
            ("linux", 'sh "$HOME/.config/herdr/bin/herdr-system-health"', 'sh "$HOME/.config/herdr/status.sh"'),
        ):
            with self.subTest(os=os_name):
                result = subprocess.run(
                    [chezmoi, "execute-template", "--override-data", json.dumps({"chezmoi": {"os": os_name}}),
                     "--file", str(template)], text=True, capture_output=True, check=False,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(expected, result.stdout)
                self.assertNotIn(excluded, result.stdout)

    def test_removed_pr_helpers_are_not_in_source(self) -> None:
        for path in (
            "private_dot_config/opencode/commands/reviewpr.md.tmpl",
            "private_dot_config/opencode/commands/writepr.md",
            "private_dot_config/opencode/skills/github-pr-writing/SKILL.md",
        ):
            with self.subTest(path=path):
                self.assertFalse((ROOT / path).exists())


if __name__ == "__main__":
    unittest.main()
