#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="${repo_root}/.github/workflows/release.yml"

if ! yq -e '.jobs.publish.strategy.max-parallel == 1' "$workflow" >/dev/null; then
  printf 'release matrix must publish one account at a time\n' >&2
  exit 1
fi

if ! yq -e '.on.workflow_dispatch.inputs.recover_existing.type == "boolean"' \
  "$workflow" >/dev/null; then
  printf 'release recovery must require an explicit boolean input\n' >&2
  exit 1
fi

stage_line="$(grep -n 'name: Stage or reuse template' "$workflow" | cut -d: -f1)"
smoke_line="$(grep -n 'name: Smoke-test staged or published template' "$workflow" | cut -d: -f1)"
promote_line="$(grep -n 'name: Promote smoke-tested template' "$workflow" | cut -d: -f1)"
if [[ -z "$stage_line" || -z "$smoke_line" || -z "$promote_line" \
  || "$stage_line" -ge "$smoke_line" || "$smoke_line" -ge "$promote_line" ]]; then
  printf 'release must stage, smoke the exact result, then promote\n' >&2
  exit 1
fi

grep -Fq 'steps.template.outputs.template_ref' "$workflow"
grep -Fq 'steps.template.outputs.template_id' "$workflow"
grep -Fq 'steps.template.outputs.needs_promotion' "$workflow"
