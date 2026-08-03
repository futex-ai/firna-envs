#!/usr/bin/env python3
"""Build one immutable E2B template from a validated environment directory."""

from __future__ import annotations

import argparse
import os
import sys
from http import HTTPStatus
from pathlib import Path

from e2b import ApiClient, ConnectionConfig, Template, default_build_logger
from e2b.api.client.api.templates import get_templates_aliases_alias


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse the environment directory, immutable name, and resources."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--environment-dir", type=Path, required=True)
    parser.add_argument("--template", required=True)
    parser.add_argument("--cpu", type=int, required=True)
    parser.add_argument("--memory-mb", type=int, required=True)
    return parser.parse_args(argv)


def template_exists(template_name: str) -> bool:
    """Return whether the selected E2B team already owns the template name."""
    client = ApiClient(ConnectionConfig())
    response = get_templates_aliases_alias.sync_detailed(
        template_name,
        client=client,
    )
    if response.status_code == HTTPStatus.OK:
        return True
    if response.status_code == HTTPStatus.NOT_FOUND:
        return False
    raise RuntimeError(
        f"unexpected E2B response while checking template: {response.status_code}"
    )


def build_template(
    environment_dir: Path,
    template_name: str,
    cpu: int,
    memory_mb: int,
) -> None:
    """Build a Dockerfile into the selected E2B team under one immutable name."""
    dockerfile = environment_dir / "Dockerfile"
    definition = Template(file_context_path=environment_dir).from_dockerfile(
        str(dockerfile)
    )
    Template.build(
        definition,
        template_name,
        cpu_count=cpu,
        memory_mb=memory_mb,
        on_build_logs=default_build_logger(),
    )


def main(argv: list[str] | None = None) -> int:
    """Validate immutability and build the requested template."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    if not os.environ.get("E2B_API_KEY"):
        print("error: E2B_API_KEY must select the intended Firna team", file=sys.stderr)
        return 78
    if template_exists(args.template):
        print(
            f"error: template {args.template} already exists; "
            "increment the manifest version",
            file=sys.stderr,
        )
        return 73
    build_template(
        args.environment_dir,
        args.template,
        args.cpu,
        args.memory_mb,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
