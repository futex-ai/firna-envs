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

if ! yq -e '.concurrency["cancel-in-progress"] == false' \
  "$workflow" >/dev/null \
  || ! grep -Fq "group: release-\${{ github.event_name == 'workflow_dispatch' && inputs.tag || github.ref_name }}" \
    "$workflow"; then
  printf 'releases of the same immutable tag must be serialized\n' >&2
  exit 1
fi

resolve_line="$(grep -n 'name: Resolve requested tag' "$workflow" | cut -d: -f1)"
tooling_checkout_line="$(grep -n 'name: Check out trusted release tooling' "$workflow" | cut -d: -f1)"
source_checkout_line="$(grep -n 'name: Check out requested source tag' "$workflow" | cut -d: -f1)"
verify_line="$(grep -n 'name: Verify checked-out tag and manifest' "$workflow" | cut -d: -f1)"
if [[ -z "$resolve_line" || -z "$tooling_checkout_line" \
  || -z "$source_checkout_line" || -z "$verify_line" \
  || "$resolve_line" -ge "$tooling_checkout_line" \
  || "$tooling_checkout_line" -ge "$source_checkout_line" \
  || "$source_checkout_line" -ge "$verify_line" ]]; then
  printf 'release must validate, isolate tooling and source, then verify the source\n' >&2
  exit 1
fi

grep -Fq "ref: \${{ github.event_name == 'workflow_dispatch' && 'refs/heads/main' || github.sha }}" \
  "$workflow"
grep -Fq "ref: refs/tags/\${{ steps.release.outputs.tag }}" "$workflow"
grep -Fq 'path: release-source' "$workflow"
grep -Fq 'fetch-depth: 0' "$workflow"
grep -Fq "SOURCE_ROOT: \${{ github.workspace }}/release-source" "$workflow"
grep -Fq "git -C \"\$SOURCE_ROOT\" rev-parse \"refs/tags/\${REQUESTED_TAG}^{commit}\"" \
  "$workflow"
grep -Fq "git -C \"\$SOURCE_ROOT\" rev-parse HEAD" "$workflow"
grep -Fq "head_commit\" != \"\$EXPECTED_PUSH_COMMIT" "$workflow"
grep -Fq "./scripts/build_template.sh \"\${source_options[@]}\" \"\$ENV_NAME\"" \
  "$workflow"
grep -Fq "source_options=(--source-root \"\$SOURCE_ROOT\")" "$workflow"
grep -Fq 'source_options+=(--allow-legacy-manifest)' "$workflow"
grep -Fq "\"\${SOURCE_ROOT}/envs/\${ENV_NAME}/verify.sh\"" "$workflow"
if grep -Fq "python3 \"\${SOURCE_ROOT}/scripts/" "$workflow" \
  || grep -Fq "\"\${SOURCE_ROOT}/scripts/build_template" "$workflow"; then
  printf 'release executes helper tooling from the immutable source checkout\n' >&2
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
