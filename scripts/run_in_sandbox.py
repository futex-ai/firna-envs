#!/usr/bin/env python3
"""Boot an E2B sandbox from a template and run a local shell script inside."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from e2b import CommandExitException, Sandbox

SANDBOX_LIFETIME_SECONDS = 900
VERIFY_TIMEOUT_SECONDS = 840


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse the template name and local script path."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("template", help="immutable E2B template name")
    parser.add_argument("script", type=Path, help="local shell script to execute")
    return parser.parse_args(argv)


def emit_output(stdout: str, stderr: str) -> None:
    """Forward sandbox process output to the matching local streams."""
    sys.stdout.write(stdout)
    sys.stderr.write(stderr)


def run_script(template: str, script_path: Path) -> int:
    """Run one local script in a newly created sandbox and return its exit code."""
    script = script_path.read_text(encoding="utf-8")
    sandbox = Sandbox.create(template, timeout=SANDBOX_LIFETIME_SECONDS)
    try:
        sandbox.files.write("/tmp/firna-env-verify.sh", script)
        try:
            result = sandbox.commands.run(
                "bash /tmp/firna-env-verify.sh",
                timeout=VERIFY_TIMEOUT_SECONDS,
            )
        except CommandExitException as error:
            emit_output(error.stdout, error.stderr)
            return error.exit_code
        emit_output(result.stdout, result.stderr)
        return result.exit_code
    finally:
        sandbox.kill()


def main(argv: list[str] | None = None) -> int:
    """Run the requested script in a new sandbox."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    return run_script(args.template, args.script)


if __name__ == "__main__":
    raise SystemExit(main())
