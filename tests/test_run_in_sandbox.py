"""Unit tests for running environment verification inside E2B."""

from __future__ import annotations

import sys
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import run_in_sandbox  # noqa: E402


class RunInSandboxTests(unittest.TestCase):
    """Exercise verification command lifetime and cleanup behavior."""

    def test_verification_has_time_for_the_full_browser_smoke(self) -> None:
        with TemporaryDirectory() as temporary_directory:
            script_path = Path(temporary_directory) / "verify.sh"
            script_path.write_text("printf 'verified\\n'\n", encoding="utf-8")
            sandbox = Mock()
            sandbox.commands.run.return_value = Mock(
                stdout="verified\n",
                stderr="",
                exit_code=0,
            )

            with (
                patch("run_in_sandbox.Sandbox.create", return_value=sandbox) as create,
                redirect_stdout(StringIO()),
            ):
                result = run_in_sandbox.run_script("firna-browser-v14", script_path)

            self.assertEqual(result, 0)
            create.assert_called_once_with("firna-browser-v14", timeout=900)
            sandbox.commands.run.assert_called_once_with(
                "bash /tmp/firna-env-verify.sh",
                timeout=840,
            )
            sandbox.kill.assert_called_once_with()


if __name__ == "__main__":
    unittest.main()
