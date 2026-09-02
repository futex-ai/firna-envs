#!/usr/bin/env python3
"""Promote one smoke-tested staging build to an immutable final alias."""

from __future__ import annotations

import argparse
import os
import sys

from e2b import Template

from build_template import resolve_template_id


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse exact source, destination, and recovery authority."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--staging-template", required=True)
    parser.add_argument("--final-template", required=True)
    parser.add_argument("--expected-template-id", required=True)
    parser.add_argument("--allow-reassign", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Verify both aliases around the single default-tag promotion."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    if not os.environ.get("E2B_API_KEY"):
        print("error: E2B_API_KEY must select the intended Firna team", file=sys.stderr)
        return 78
    if not args.staging_template.startswith(f"{args.final_template}:"):
        print("error: staging and final template names do not share a base", file=sys.stderr)
        return 64

    staging_id = resolve_template_id(args.staging_template)
    if staging_id != args.expected_template_id:
        print("error: staging alias identity changed before promotion", file=sys.stderr)
        return 73
    final_id = resolve_template_id(args.final_template)
    if final_id == args.expected_template_id:
        print(f"template {args.final_template} already has the smoke-tested identity")
        return 0
    if final_id is not None and not args.allow_reassign:
        print(
            f"error: template {args.final_template} already resolves to a different id; "
            "use explicit recovery only after its smoke fails",
            file=sys.stderr,
        )
        return 73

    Template.assign_tags(args.staging_template, "default")
    if resolve_template_id(args.final_template) != args.expected_template_id:
        print("error: promoted alias did not resolve to the smoke-tested id", file=sys.stderr)
        return 70
    print(f"promoted {args.staging_template} to {args.final_template}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
