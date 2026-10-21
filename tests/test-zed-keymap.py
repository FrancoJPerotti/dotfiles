#!/usr/bin/env python3
"""Static checks for the active Zed keymap, not the reverted migration draft."""
from collections import defaultdict
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
KEYMAP = ROOT / "common/zed/.config/zed/keymap.json"


def parse_jsonc(text):
    # Preserve strings containing URLs, comment delimiters or trailing commas.
    tokens = re.findall(
        r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*[\s\S]*?\*/|[^"/]+|/', text
    )
    stripped = "".join(
        " " if token.startswith(("//", "/*")) else token for token in tokens
    )
    stripped = re.sub(
        r'("(?:\\.|[^"\\])*")|,(\s*[}\]])',
        lambda match: match[1] if match[1] is not None else match[2],
        stripped,
    )

    def unique_object(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"Duplicate JSON key: {key}")
            result[key] = value
        return result

    return json.loads(stripped, object_pairs_hook=unique_object)


class JsoncTests(unittest.TestCase):
    def test_comments_strings_and_trailing_commas(self):
        self.assertEqual(
            parse_jsonc('/* header */ {"url": "https://x/*y*/,}", // note\n "x": [1,],}'),
            {"url": "https://x/*y*/,}", "x": [1]},
        )

    def test_duplicate_keys_are_rejected(self):
        with self.assertRaises(ValueError):
            parse_jsonc('{"s": 1, "s": 2}')


class KeymapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.groups = parse_jsonc(KEYMAP.read_text())

    def bindings(self, context):
        result = {}
        for group in self.groups:
            if group.get("context") == context:
                result.update(group["bindings"])
        self.assertTrue(result, f"Missing context: {context}")
        return result

    def test_groups_are_well_formed(self):
        self.assertIsInstance(self.groups, list)
        for group in self.groups:
            self.assertIsInstance(group["bindings"], dict)
            for key, action in group["bindings"].items():
                self.assertTrue(key)
                self.assertTrue(action is None or isinstance(action, (str, list)))
                if isinstance(action, list):
                    self.assertEqual(len(action), 2)
                    self.assertIsInstance(action[0], str)

    def test_no_repeated_keystrokes_in_identical_contexts(self):
        # Different contexts intentionally reuse keys (editor, terminal, menus).
        # Even identical actions in identical contexts are redundant/conflicting
        # entries in Zed's keymap editor and should only be declared once.
        occurrences = defaultdict(list)
        for index, group in enumerate(self.groups):
            for key, action in group["bindings"].items():
                occurrences[(group.get("context"), key)].append((index, action))
        duplicates = {
            pair: entries for pair, entries in occurrences.items() if len(entries) > 1
        }
        self.assertEqual(duplicates, {})

    def test_full_editor_keeps_previously_winning_actions(self):
        bindings = self.bindings("Editor && mode == full")
        for key, action in {
            "ctrl-enter": "assistant::InlineAssist",
            "shift-enter": "editor::ExpandExcerpts",
            "alt-enter": "editor::OpenExcerpts",
            "enter": "editor::Newline",
            "ctrl-shift-enter": "editor::NewlineBelow",
        }.items():
            self.assertEqual(bindings[key], action)

    def test_prediction_tab_is_retained_after_vim_bindings(self):
        matching = [
            i for i, group in enumerate(self.groups)
            if group.get("context") == "Editor && edit_prediction"
            and "tab" in group["bindings"]
        ]
        self.assertEqual(len(matching), 1)
        self.assertEqual(
            self.groups[matching[0]]["bindings"]["tab"], "editor::AcceptEditPrediction"
        )
        vim_tab = max(
            i for i, group in enumerate(self.groups)
            if group["bindings"].get("tab") == "vim::Tab"
        )
        self.assertGreater(matching[0], vim_tab)

    def test_original_visual_ai_bindings_are_preserved(self):
        self.assertEqual(self.bindings("vim_mode == visual"), {
            "space a e": "assistant::InlineAssist",
            "space a c": "agent::AddSelectionToThread",
            "space a a": "assistant::QuoteSelection",
        })

    def test_other_contexts_keep_their_enter_actions(self):
        self.assertEqual(
            self.bindings("Editor && mode == auto_height")["ctrl-enter"],
            "editor::Newline",
        )
        self.assertEqual(
            self.bindings("MessageEditor > Editor")["ctrl-enter"],
            "agent::ChatWithFollow",
        )
        self.assertEqual(
            self.bindings("Editor && showing_completions")["shift-enter"],
            "editor::ConfirmCompletionReplace",
        )


if __name__ == "__main__":
    unittest.main()
