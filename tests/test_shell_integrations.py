import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ShellIntegrationTests(unittest.TestCase):
    def test_zoxide_initializes_each_time_without_reading_or_writing_cache(self) -> None:
        with tempfile.TemporaryDirectory(dir="/home/pablo/.tmp/opencode") as directory:
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
                text=True, capture_output=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), "fresh")
            self.assertEqual((home / "calls").read_text().splitlines(), ["init", "init"])
            self.assertEqual(cache.read_text(), "export ZOXIDE_VALUE=stale\n")

    def test_python_launcher_uses_dotfiles_python_version(self) -> None:
        with tempfile.TemporaryDirectory(dir="/home/pablo/.tmp/opencode") as directory:
            home = Path(directory)
            mise = home / ".local/bin/mise"
            mise.parent.mkdir(parents=True)
            mise.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
            mise.chmod(0o755)
            result = subprocess.run(
                ["sh", str(ROOT / "private_dot_config/herdr/bin/executable_herdr-python"), "herdr-navigator", "left", "h", "--status"],
                env=dict(os.environ, HOME=str(home)), text=True, capture_output=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            args = result.stdout.splitlines()
            self.assertEqual(args[:6], ["exec", "--fresh-env", "-C", str(home), "python@3.14", "--"])
            self.assertEqual(args[-4:], [str(home / ".config/herdr/bin/herdr-navigator"), "left", "h", "--status"])

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
