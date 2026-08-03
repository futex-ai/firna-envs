"""Unit tests for the immutable E2B template builder."""

from __future__ import annotations

import os
import sys
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import build_template  # noqa: E402


class BuildTemplateTests(unittest.TestCase):
    """Exercise credential, immutability, and SDK build behavior."""

    def test_missing_api_key_fails(self) -> None:
        with patch.dict(os.environ, {}, clear=True), redirect_stderr(StringIO()):
            result = build_template.main(
                [
                    "--environment-dir",
                    "envs/general",
                    "--template",
                    "firna-general-v2",
                    "--cpu",
                    "2",
                    "--memory-mb",
                    "2048",
                ]
            )

        self.assertEqual(result, 78)

    @patch("build_template.template_exists", return_value=True)
    def test_existing_template_is_not_rebuilt(self, exists: Mock) -> None:
        with (
            patch.dict(os.environ, {"E2B_API_KEY": "test-key"}, clear=True),
            patch("build_template.build_template") as build,
            redirect_stderr(StringIO()),
        ):
            result = build_template.main(
                [
                    "--environment-dir",
                    "envs/general",
                    "--template",
                    "firna-general-v2",
                    "--cpu",
                    "2",
                    "--memory-mb",
                    "2048",
                ]
            )

        self.assertEqual(result, 73)
        exists.assert_called_once_with("firna-general-v2")
        build.assert_not_called()

    def test_build_uses_dockerfile_and_resources(self) -> None:
        with TemporaryDirectory() as temporary_directory:
            environment_dir = Path(temporary_directory)
            (environment_dir / "Dockerfile").write_text(
                "FROM debian:bookworm\n",
                encoding="utf-8",
            )
            definition = Mock()
            template_instance = Mock()
            template_instance.from_dockerfile.return_value = definition

            with (
                patch("build_template.Template") as template,
                patch("build_template.default_build_logger") as logger,
            ):
                template.return_value = template_instance
                build_template.build_template(
                    environment_dir,
                    "firna-general-v2",
                    2,
                    2048,
                )

            template.assert_called_once_with(file_context_path=environment_dir)
            template_instance.from_dockerfile.assert_called_once_with(
                str(environment_dir / "Dockerfile")
            )
            template.build.assert_called_once_with(
                definition,
                "firna-general-v2",
                cpu_count=2,
                memory_mb=2048,
                on_build_logs=logger.return_value,
            )

    @patch("build_template.template_exists", return_value=True)
    def test_release_can_leave_existing_template_unchanged(self, exists: Mock) -> None:
        with (
            patch.dict(os.environ, {"E2B_API_KEY": "test-key"}, clear=True),
            patch("build_template.build_template") as build,
            redirect_stdout(StringIO()),
        ):
            result = build_template.main(
                [
                    "--environment-dir",
                    "envs/general",
                    "--template",
                    "firna-general-v2",
                    "--cpu",
                    "2",
                    "--memory-mb",
                    "2048",
                    "--skip-existing",
                ]
            )

        self.assertEqual(result, 0)
        exists.assert_called_once_with("firna-general-v2")
        build.assert_not_called()


if __name__ == "__main__":
    unittest.main()
