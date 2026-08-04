#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="${repo_root}/.github/workflows/release.yml"

if ! yq -e '.jobs.publish.strategy.max-parallel == 1' "$workflow" >/dev/null; then
  printf 'release matrix must publish one account at a time\n' >&2
  exit 1
fi
