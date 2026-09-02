"""Unit tests for smoke-gated E2B template promotion."""

from __future__ import annotations

import os
import sys
import unittest
from contextlib import redirect_stderr
from io import StringIO
from pathlib import Path
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import promote_template  # noqa: E402


class PromoteTemplateTests(unittest.TestCase):
    """Exercise exact-id promotion and explicit recovery behavior."""

    def test_missing_api_key_fails(self) -> None:
        with patch.dict(os.environ, {}, clear=True), redirect_stderr(StringIO()):
            result = promote_template.main(self.args())

        self.assertEqual(result, 78)

    @patch("promote_template.resolve_template_id")
    def test_promotion_assigns_default_then_verifies_identity(self, resolve: Mock) -> None:
        resolve.side_effect = ["tmpl_staged", None, "tmpl_staged"]
        with (
            patch.dict(os.environ, {"E2B_API_KEY": "test-key"}, clear=True),
            patch("promote_template.Template.assign_tags") as assign,
        ):
            result = promote_template.main(self.args())

        self.assertEqual(result, 0)
        assign.assert_called_once_with("firna-browser-v11:stage-run", "default")

    @patch("promote_template.resolve_template_id")
    def test_different_final_alias_requires_explicit_recovery(self, resolve: Mock) -> None:
        resolve.side_effect = ["tmpl_staged", "tmpl_other"]
        with (
            patch.dict(os.environ, {"E2B_API_KEY": "test-key"}, clear=True),
            patch("promote_template.Template.assign_tags") as assign,
            redirect_stderr(StringIO()),
        ):
            result = promote_template.main(self.args())

        self.assertEqual(result, 73)
        assign.assert_not_called()

    @patch("promote_template.resolve_template_id")
    def test_explicit_recovery_can_reassign_then_verify_default(self, resolve: Mock) -> None:
        resolve.side_effect = ["tmpl_staged", "tmpl_other", "tmpl_staged"]
        with (
            patch.dict(os.environ, {"E2B_API_KEY": "test-key"}, clear=True),
            patch("promote_template.Template.assign_tags") as assign,
        ):
            result = promote_template.main(self.args() + ["--allow-reassign"])

        self.assertEqual(result, 0)
        assign.assert_called_once_with("firna-browser-v11:stage-run", "default")

    @staticmethod
    def args() -> list[str]:
        return [
            "--staging-template",
            "firna-browser-v11:stage-run",
            "--final-template",
            "firna-browser-v11",
            "--expected-template-id",
            "tmpl_staged",
        ]


if __name__ == "__main__":
    unittest.main()
