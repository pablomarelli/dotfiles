"""Exercise the picker entry point with only external CLI processes replaced."""
import importlib.machinery
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SOURCE = Path(__file__).resolve().parents[1] / "private_dot_config/herdr/bin/executable_herdr-tv-workspace.tmpl"


class WorkspacePickerTests(unittest.TestCase):
    def setUp(self):
        loader = importlib.machinery.SourceFileLoader("picker", str(SOURCE))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        self.picker = importlib.util.module_from_spec(spec)
        loader.exec_module(self.picker)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.folder = self.root / ".config with spaces"
        self.folder.mkdir()
        self.picker.ROOTS_PATH = self.root / "state/roots.json"
        self.picker.MRU_PATH = self.root / "cache/mru.json"
        self.picker.LAST_WORKSPACE_PATH = self.root / "cache/last"
        self.picker.PROJECT_ROOTS = ()
        self.items = [{"workspace_id": "w1", "label": "main", "focused": True}]
        self.panes = []
        self.created = 0
        self.selections = []
        self.addCleanup(patch.stopall)
        patch.object(self.picker.subprocess, "run", side_effect=self.process).start()
        patch.object(self.picker.shutil, "which", side_effect=lambda name: name).start()

    def process(self, args, **kwargs):
        if args[0] == "tv":
            value = self.selections.pop(0)
            return subprocess.CompletedProcess(args, 0 if value else 1, value or "", "")
        if args[0] == "git":
            return subprocess.CompletedProcess(args, 128, "", "not a repository")
        if args[0] == "zoxide":
            return subprocess.CompletedProcess(args, 0, "", "")
        self.assertEqual(args[0], "herdr")
        command = args[1:3]
        result = {}
        if command == ("workspace", "list"):
            result = {"workspaces": self.items}
        elif command == ("pane", "list"):
            result = {"panes": self.panes}
        elif command == ("workspace", "create"):
            self.created += 1
            workspace_id = f"new{self.created}"
            item = {"workspace_id": workspace_id, "label": args[args.index("--label") + 1]}
            self.items.append(item)
            self.panes.append({"workspace_id": workspace_id, "cwd": args[args.index("--cwd") + 1]})
            result = {"workspace": item, "tab": {"tab_id": workspace_id + ":t1"}}
        elif command == ("workspace", "focus"):
            for item in self.items:
                item["focused"] = item["workspace_id"] == args[3]
        elif command == ("workspace", "rename"):
            next(item for item in self.items if item["workspace_id"] == args[3])["label"] = args[4]
        else:
            self.assertEqual(command, ("tab", "rename"))
        return subprocess.CompletedProcess(args, 0, json.dumps({"result": result}), "")

    def invoke(self, *args):
        with patch("sys.argv", ["picker", *args]):
            self.assertEqual(self.picker.main(), 0)

    def test_direct_hidden_path_and_custom_name_reuses_after_cd_and_symlink(self):
        self.selections = [self.picker.OPEN_ENTRY, self.picker.PATH_ENTRY]
        with patch("builtins.input", side_effect=[str(self.folder), "dotfiles"]):
            self.invoke()
        self.assertEqual(self.items[-1]["label"], "dotfiles")
        self.panes[-1]["cwd"] = str(self.root)
        alias = self.root / "alias"
        alias.symlink_to(self.folder)
        self.invoke("--open", str(alias))
        self.assertEqual(self.created, 1)
        self.assertTrue(self.items[-1]["focused"])

    def test_existing_workspace_is_adopted_and_can_be_renamed(self):
        self.items.append({"workspace_id": "old", "label": ".config"})
        self.panes.append({"workspace_id": "old", "cwd": str(self.folder)})
        self.invoke("--open", str(self.folder), "--label", "dotfiles")
        self.assertEqual(self.created, 0)
        self.assertEqual(self.items[-1]["label"], "dotfiles")
        self.assertEqual(json.loads(self.picker.ROOTS_PATH.read_text())["old"], str(self.folder))

    def test_same_basename_in_different_folders_creates_distinct_workspaces(self):
        other = self.root / "other" / self.folder.name
        other.mkdir(parents=True)
        self.invoke("--open", str(self.folder))
        self.invoke("--open", str(other))
        self.assertEqual(self.created, 2)
        self.assertEqual(len(self.picker.workspace_entries(self.items)), 3)

    def test_duplicate_existing_paths_require_selection(self):
        self.items.extend({"workspace_id": key, "label": "same"} for key in ("w2", "w3"))
        self.panes.extend({"workspace_id": key, "cwd": str(self.folder)} for key in ("w2", "w3"))
        self.selections = ["same  [w3]"]
        self.invoke("--open", str(self.folder))
        self.assertEqual(self.created, 0)
        self.assertTrue(self.items[-1]["focused"])

    def test_cancel_folder_selection_preserves_last_workspace(self):
        self.picker.LAST_WORKSPACE_PATH.parent.mkdir(parents=True)
        self.picker.LAST_WORKSPACE_PATH.write_text("previous\n")
        self.selections = [self.picker.OPEN_ENTRY, None]
        self.invoke()
        self.assertEqual(self.created, 0)
        self.assertEqual(self.picker.LAST_WORKSPACE_PATH.read_text(), "previous\n")

    def test_stale_mapping_does_not_block_recreation(self):
        self.invoke("--open", str(self.folder))
        self.items = self.items[:1]
        self.panes = []
        self.invoke("--open", str(self.folder))
        self.assertEqual(self.created, 2)
        self.assertNotIn("new1", json.loads(self.picker.ROOTS_PATH.read_text()))

    def test_invalid_path_does_not_create_workspace(self):
        with self.assertRaisesRegex(SystemExit, "Not a directory"):
            self.invoke("--open", str(self.root / "missing"))
        self.assertEqual(self.created, 0)

    def test_browser_can_select_hidden_folder(self):
        self.selections = [str(self.folder), ". Open this folder"]
        self.assertEqual(self.picker.browse_folder(self.root), self.folder)


if __name__ == "__main__":
    unittest.main()
