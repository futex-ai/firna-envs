#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'usage: %s [--source-root PATH] [--allow-legacy-manifest] <environment-name> [build options]\n' \
    "$0" >&2
}

if [[ "$#" -lt 1 ]]; then
  usage
  exit 64
fi
if [[ -z "${E2B_API_KEY:-}" ]]; then
  printf '%s\n' 'error: E2B_API_KEY must select the intended Firna team' >&2
  exit 78
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repo_root
source_root="$repo_root"
allow_legacy_manifest=false
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --source-root)
      if [[ "$#" -lt 2 ]]; then
        usage
        exit 64
      fi
      source_root="$2"
      shift 2
      ;;
    --allow-legacy-manifest)
      allow_legacy_manifest=true
      shift
      ;;
    *) break ;;
  esac
done
if [[ "$#" -lt 1 ]]; then
  usage
  exit 64
fi
if ! source_root="$(cd "$source_root" 2>/dev/null && pwd -P)"; then
  printf '%s\n' 'error: source root is not an accessible directory' >&2
  exit 66
fi
readonly source_root allow_legacy_manifest
env_name="$1"
shift
env_dir="${source_root}/envs/${env_name}"
manifest="${env_dir}/manifest.yaml"

if [[ ! -f "$manifest" ]]; then
  printf 'error: environment manifest not found: %s\n' "$manifest" >&2
  exit 66
fi
if [[ "$allow_legacy_manifest" == true ]]; then
  recovery_requested=false
  for option in "$@"; do
    if [[ "$option" == '--recover-existing' ]]; then
      recovery_requested=true
      break
    fi
  done
  if [[ "$recovery_requested" != true ]]; then
    printf '%s\n' 'error: legacy manifest compatibility requires --recover-existing' >&2
    exit 64
  fi
fi

validation_args=(--source-root "$source_root")
if [[ "$allow_legacy_manifest" == true ]]; then
  validation_args+=(--allow-legacy-manifest)
fi
"${repo_root}/scripts/validate_manifests.sh" "${validation_args[@]}"

name="$(yq -r '.name' "$manifest")"
version="$(yq -r '.version' "$manifest")"
cpu="$(yq -r '.resources.cpu' "$manifest")"
memory_mb="$(yq -r '.resources.memory_mb' "$manifest")"
template="firna-${name}-v${version}"
python_command="${FIRNA_ENVS_PYTHON:-python3}"
python_args=(
  --source-root "$source_root"
  --environment-dir "envs/${env_name}"
  --template "$template"
  --cpu "$cpu"
  --memory-mb "$memory_mb"
)
python_args+=("$@")

if ! "$python_command" -c 'import e2b' >/dev/null 2>&1; then
  printf 'error: %s cannot import e2b; install requirements.txt\n' \
    "$python_command" >&2
  exit 69
fi

printf 'building immutable template %s\n' "$template"
"$python_command" "${repo_root}/scripts/build_template.py" "${python_args[@]}"
