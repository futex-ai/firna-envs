#!/usr/bin/env python3
"""Build or reuse one E2B template and export its exact identity."""

from __future__ import annotations

import argparse
import os
import re
import sys
from http import HTTPStatus
from pathlib import Path

from e2b import ApiClient, ConnectionConfig, Template, default_build_logger
from e2b.api.client.api.templates import get_templates_aliases_alias

REPO_ROOT = Path(__file__).resolve().parents[1]
STAGING_TAG_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse immutable identity, resources, and release-mode controls."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--environment-dir", type=Path, required=True)
    parser.add_argument("--template", required=True)
    parser.add_argument("--cpu", type=int, required=True)
    parser.add_argument("--memory-mb", type=int, required=True)
    parser.add_argument("--skip-existing", action="store_true")
    parser.add_argument("--recover-existing", action="store_true")
    parser.add_argument("--stage-tag")
    parser.add_argument("--result-file", type=Path)
    return parser.parse_args(argv)


def resolve_template_id(
    template_name: str,
    client: ApiClient | None = None,
) -> str | None:
    """Resolve one alias to its exact E2B template id, or report absence."""
    active_client = client if client is not None else ApiClient(ConnectionConfig())
    response = get_templates_aliases_alias.sync_detailed(
        template_name,
        client=active_client,
    )
    if response.status_code == HTTPStatus.NOT_FOUND:
        return None
    if response.status_code != HTTPStatus.OK:
        raise RuntimeError(
            f"unexpected E2B response while resolving template: {response.status_code}"
        )
    template_id = getattr(response.parsed, "template_id", None)
    if not isinstance(template_id, str) or not template_id:
        raise RuntimeError("successful E2B alias response contained no template id")
    return template_id


def build_template(
    environment_dir: Path,
    template_name: str,
    cpu: int,
    memory_mb: int,
) -> str:
    """Build from repository context and return the resulting template id."""
    dockerfile = (REPO_ROOT / environment_dir / "Dockerfile").resolve()
    definition = Template(file_context_path=REPO_ROOT).from_dockerfile(str(dockerfile))
    build = Template.build(
        definition,
        template_name,
        cpu_count=cpu,
        memory_mb=memory_mb,
        on_build_logs=default_build_logger(),
    )
    template_id = getattr(build, "template_id", None)
    if not isinstance(template_id, str) or not template_id:
        raise RuntimeError("successful E2B build returned no template id")
    return template_id


def write_result(
    path: Path | None,
    template_ref: str,
    template_id: str,
    needs_promotion: bool,
) -> None:
    """Append shell-safe release metadata for the workflow consumer."""
    if path is None:
        return
    with path.open("a", encoding="utf-8") as result:
        result.write(f"template_ref={template_ref}\n")
        result.write(f"template_id={template_id}\n")
        result.write(f"needs_promotion={str(needs_promotion).lower()}\n")


def validate_release_args(args: argparse.Namespace) -> None:
    """Reject recovery or staging combinations that cannot be made safe."""
    if args.stage_tag and not STAGING_TAG_PATTERN.fullmatch(args.stage_tag):
        raise ValueError("staging tag must use letters, numbers, dots, underscores, or hyphens")
    if args.recover_existing and (not args.skip_existing or not args.stage_tag):
        raise ValueError("recovery requires --skip-existing and --stage-tag")


def main(argv: list[str] | None = None) -> int:
    """Build a staging alias or reuse an identity that will still be smoked."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        validate_release_args(args)
    except ValueError as error:
        print(f"error: {error}", file=sys.stderr)
        return 64
    if not os.environ.get("E2B_API_KEY"):
        print("error: E2B_API_KEY must select the intended Firna team", file=sys.stderr)
        return 78

    final_id = resolve_template_id(args.template)
    if final_id and not args.recover_existing:
        if not args.skip_existing:
            print(
                f"error: template {args.template} already exists; "
                "increment the manifest version",
                file=sys.stderr,
            )
            return 73
        print(f"template {args.template} resolves to {final_id}; reusing for smoke")
        write_result(args.result_file, args.template, final_id, False)
        return 0

    template_ref = args.template
    needs_promotion = False
    if args.stage_tag:
        template_ref = f"{args.template}:{args.stage_tag}"
        needs_promotion = True
    template_id = resolve_template_id(template_ref)
    if template_id is None:
        template_id = build_template(
            args.environment_dir,
            template_ref,
            args.cpu,
            args.memory_mb,
        )
    else:
        print(f"staging template {template_ref} resolves to {template_id}; reusing for smoke")
    write_result(args.result_file, template_ref, template_id, needs_promotion)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
