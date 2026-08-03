#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'usage: %s <environment-name> [--skip-existing]\n' "$0" >&2
}

if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
  usage
  exit 64
fi
if [[ "$#" -eq 2 && "$2" != "--skip-existing" ]]; then
  usage
  exit 64
fi
if [[ -z "${E2B_API_KEY:-}" ]]; then
  printf '%s\n' 'error: E2B_API_KEY must select the intended Firna team' >&2
  exit 78
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repo_root
env_name="$1"
env_dir="${repo_root}/envs/${env_name}"
manifest="${env_dir}/manifest.yaml"

if [[ ! -f "$manifest" ]]; then
  printf 'error: environment manifest not found: %s\n' "$manifest" >&2
  exit 66
fi

"${repo_root}/scripts/validate_manifests.sh"

name="$(yq -r '.name' "$manifest")"
version="$(yq -r '.version' "$manifest")"
cpu="$(yq -r '.resources.cpu' "$manifest")"
memory_mb="$(yq -r '.resources.memory_mb' "$manifest")"
template="firna-${name}-v${version}"
python_command="${FIRNA_ENVS_PYTHON:-python3}"
python_args=(
  --environment-dir "$env_dir"
  --template "$template"
  --cpu "$cpu"
  --memory-mb "$memory_mb"
)
if [[ "${2:-}" == "--skip-existing" ]]; then
  python_args+=(--skip-existing)
fi

if ! "$python_command" -c 'import e2b' >/dev/null 2>&1; then
  printf 'error: %s cannot import e2b; install requirements.txt\n' \
    "$python_command" >&2
  exit 69
fi

printf 'building immutable template %s\n' "$template"
"$python_command" "${repo_root}/scripts/build_template.py" "${python_args[@]}"
