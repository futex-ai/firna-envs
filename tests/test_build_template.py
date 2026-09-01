"""Unit tests for the staged E2B template builder."""

from __future__ import annotations

import os
import sys
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import build_template  # noqa: E402


class BuildTemplateTests(unittest.TestCase):
    """Exercise credentials, alias identity, staging, and build context."""

    def test_missing_api_key_fails(self) -> None:
        with patch.dict(os.environ, {}, clear=True), redirect_stderr(StringIO()):
            result = build_template.main(self.base_args())

        self.assertEqual(result, 78)

    @patch("build_template.resolve_template_id", return_value="tmpl_existing")
    def test_existing_template_is_not_rebuilt(self, resolve: Mock) -> None:
        with (
            patch.dict(os.environ, {"E2B_API_KEY": "test-key"}, clear=True),
            patch("build_template.build_template") as build,
            redirect_stderr(StringIO()),
        ):
            result = build_template.main(self.base_args())

        self.assertEqual(result, 73)
        resolve.assert_called_once_with("firna-general-v3")
        build.assert_not_called()

    def test_alias_resolution_returns_the_exact_template_id(self) -> None:
        response = SimpleNamespace(
            status_code=200,
            parsed=SimpleNamespace(template_id="tmpl_ready"),
        )
        with patch(
            "build_template.get_templates_aliases_alias.sync_detailed",
            return_value=response,
        ) as resolve:
            client = Mock()
            self.assertEqual(
                build_template.resolve_template_id("firna-general-v3", client),
                "tmpl_ready",
            )
        resolve.assert_called_once_with("firna-general-v3", client=client)

    def test_malformed_successful_alias_response_is_rejected(self) -> None:
        response = SimpleNamespace(status_code=200, parsed=None)
        with patch(
            "build_template.get_templates_aliases_alias.sync_detailed",
            return_value=response,
        ):
            with self.assertRaisesRegex(RuntimeError, "no template id"):
                build_template.resolve_template_id("firna-general-v3", Mock())

    def test_build_uses_repository_context_and_returns_template_id(self) -> None:
        definition = Mock()
        template_instance = Mock()
        template_instance.from_dockerfile.return_value = definition
        build_info = SimpleNamespace(template_id="tmpl_built")

        with (
            patch("build_template.Template") as template,
            patch("build_template.default_build_logger") as logger,
        ):
            template.return_value = template_instance
            template.build.return_value = build_info
            result = build_template.build_template(
                Path("envs/general"),
                "firna-general-v3:stage-1",
                2,
                2048,
            )

        template.assert_called_once_with(file_context_path=build_template.REPO_ROOT)
        template_instance.from_dockerfile.assert_called_once_with(
            str(build_template.REPO_ROOT / "envs/general/Dockerfile")
        )
        template.build.assert_called_once_with(
            definition,
            "firna-general-v3:stage-1",
            cpu_count=2,
            memory_mb=2048,
            on_build_logs=logger.return_value,
        )
        self.assertEqual(result, "tmpl_built")

    @patch("build_template.resolve_template_id", return_value="tmpl_existing")
    def test_release_reuses_existing_alias_but_exports_its_identity(self, resolve: Mock) -> None:
        with TemporaryDirectory() as temporary_directory:
            result_path = Path(temporary_directory) / "result"
            with (
                patch.dict(os.environ, {"E2B_API_KEY": "test-key"}, clear=True),
                patch("build_template.build_template") as build,
                redirect_stdout(StringIO()),
            ):
                result = build_template.main(
                    self.base_args()
                    + ["--skip-existing", "--result-file", str(result_path)]
                )

            self.assertEqual(result, 0)
            self.assertEqual(
                result_path.read_text(encoding="utf-8"),
                "template_ref=firna-general-v3\n"
                "template_id=tmpl_existing\n"
                "needs_promotion=false\n",
            )
            build.assert_not_called()
        resolve.assert_called_once_with("firna-general-v3")

    @patch("build_template.resolve_template_id")
    def test_release_builds_a_staging_alias_when_final_is_absent(
        self,
        resolve: Mock,
    ) -> None:
        resolve.side_effect = [None, None]
        with TemporaryDirectory() as temporary_directory:
            result_path = Path(temporary_directory) / "result"
            with (
                patch.dict(os.environ, {"E2B_API_KEY": "test-key"}, clear=True),
                patch(
                    "build_template.build_template",
                    return_value="tmpl_staged",
                ) as build,
            ):
                result = build_template.main(
                    self.base_args()
                    + [
                        "--skip-existing",
                        "--stage-tag",
                        "stage-run-1",
                        "--result-file",
                        str(result_path),
                    ]
                )

            self.assertEqual(result, 0)
            build.assert_called_once_with(
                Path("envs/general"),
                "firna-general-v3:stage-run-1",
                2,
                2048,
            )
            self.assertEqual(
                result_path.read_text(encoding="utf-8"),
                "template_ref=firna-general-v3:stage-run-1\n"
                "template_id=tmpl_staged\n"
                "needs_promotion=true\n",
            )

    @patch("build_template.resolve_template_id")
    def test_recovery_builds_a_staging_alias_instead_of_reusing_final(self, resolve: Mock) -> None:
        resolve.side_effect = ["tmpl_failed", None]
        with TemporaryDirectory() as temporary_directory:
            result_path = Path(temporary_directory) / "result"
            with (
                patch.dict(os.environ, {"E2B_API_KEY": "test-key"}, clear=True),
                patch("build_template.build_template", return_value="tmpl_staged") as build,
            ):
                result = build_template.main(
                    self.base_args()
                    + [
                        "--skip-existing",
                        "--recover-existing",
                        "--stage-tag",
                        "stage-run-1",
                        "--result-file",
                        str(result_path),
                    ]
                )

            self.assertEqual(result, 0)
            build.assert_called_once_with(
                Path("envs/general"),
                "firna-general-v3:stage-run-1",
                2,
                2048,
            )
            self.assertEqual(
                result_path.read_text(encoding="utf-8"),
                "template_ref=firna-general-v3:stage-run-1\n"
                "template_id=tmpl_staged\n"
                "needs_promotion=true\n",
            )

    @staticmethod
    def base_args() -> list[str]:
        return [
            "--environment-dir",
            "envs/general",
            "--template",
            "firna-general-v3",
            "--cpu",
            "2",
            "--memory-mb",
            "2048",
        ]


if __name__ == "__main__":
    unittest.main()
