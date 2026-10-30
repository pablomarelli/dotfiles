"""Exercise the workspace focus watcher against recorded Herdr event lines."""
import importlib.machinery
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "private_dot_config/herdr/bin/executable_herdr-workspace-history.tmpl"


def focused(workspace_id):
    return json.dumps({"data": {"type": "workspace_focused", "workspace_id": workspace_id}, "event": "workspace_focused"})


def tab_focused(workspace_id, tab_id):
    return json.dumps({"data": {"type": "tab_focused", "workspace_id": workspace_id, "tab_id": tab_id}, "event": "tab_focused"})


class WorkspaceHistoryTests(unittest.TestCase):
    def setUp(self):
        loader = importlib.machinery.SourceFileLoader("history", str(SOURCE))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        self.history = importlib.util.module_from_spec(spec)
        loader.exec_module(self.history)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.history.PREVIOUS_PATH = root / "workspace"
        self.history.MRU_PATH = root / "workspace-mru.json"
        self.history.LOCK_PATH = root / "workspace-history.lock"
        self.history.CACHE = root

    def run_events(self, current, *workspace_ids, tabs=None, events=()):
        lines = [json.dumps({"id": "workspace-history", "result": {"type": "subscription_started"}})]
        lines += [focused(workspace_id) for workspace_id in workspace_ids]
        lines += list(events)
        state = self.history.FocusState(current, dict(tabs or {}))
        self.history.follow(lines, state)
        return state

    def test_agent_tab_switches_update_previous_workspace(self):
        self.run_events("w1", "w2", "w3")
        self.assertEqual(self.history.PREVIOUS_PATH.read_text(), "w2\n")
        self.assertEqual(json.loads(self.history.MRU_PATH.read_text()), ["w3", "w2", "w1"])

    def test_repeated_focus_events_do_not_erase_history(self):
        self.run_events("w1", "w1", "w2", "w2", "w2")
        self.assertEqual(self.history.PREVIOUS_PATH.read_text(), "w1\n")

    def test_toggle_back_and_forth(self):
        self.run_events("w1", "w2", "w1")
        self.assertEqual(self.history.PREVIOUS_PATH.read_text(), "w2\n")
        self.assertEqual(json.loads(self.history.MRU_PATH.read_text()), ["w1", "w2"])

    def test_unknown_start_focus_waits_for_first_switch(self):
        self.run_events(None, "w2")
        self.assertFalse(self.history.PREVIOUS_PATH.exists())
        self.run_events("w2", "w3")
        self.assertEqual(self.history.PREVIOUS_PATH.read_text(), "w2\n")

    def test_existing_mru_keeps_older_entries(self):
        self.history.MRU_PATH.write_text(json.dumps(["w9", "w2", "w8"]))
        self.run_events("w9", "w2")
        self.assertEqual(json.loads(self.history.MRU_PATH.read_text()), ["w2", "w9", "w8"])

    def test_subscription_error_is_reported(self):
        with self.assertRaises(SystemExit):
            self.history.follow([json.dumps({"id": "x", "error": {"code": "bad"}})], self.history.FocusState("w1", {}))

    def test_tab_switch_records_previous_tab_per_workspace(self):
        self.run_events("w1", tabs={"w1": "t1"}, events=[tab_focused("w1", "t2"), tab_focused("w1", "t3")])
        self.assertEqual(self.history.tab_state_path("w1").read_text(), "t2\n")
        self.assertFalse(self.history.PREVIOUS_PATH.exists())

    def test_repeated_tab_focus_does_not_erase_history(self):
        self.run_events("w1", tabs={"w1": "t1"}, events=[tab_focused("w1", "t2"), tab_focused("w1", "t2")])
        self.assertEqual(self.history.tab_state_path("w1").read_text(), "t1\n")

    def test_unknown_start_tab_waits_for_first_switch(self):
        self.run_events("w1", events=[tab_focused("w1", "t2")])
        self.assertFalse(self.history.tab_state_path("w1").exists())

    def test_snapshot_seeds_focused_workspace_and_tabs(self):
        state = self.history.FocusState.from_snapshot([
            {"workspace_id": "w1", "focused": True, "active_tab_id": "t1"},
            {"workspace_id": "w2", "focused": False, "active_tab_id": "t9"},
            {"workspace_id": "w3", "focused": False},
        ])
        self.assertEqual(state.workspace, "w1")
        self.assertEqual(state.tabs, {"w1": "t1", "w2": "t9"})

    def test_only_one_watcher_holds_the_lock(self):
        first = self.history.acquire_lock()
        self.addCleanup(first.close)
        self.assertIsNotNone(first)
        self.assertIsNone(self.history.acquire_lock())


if __name__ == "__main__":
    unittest.main()
