#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repo_root
test_root="$(mktemp -d)"
readonly test_root
trap 'rm -rf "$test_root"' EXIT
mkdir -p "${test_root}/bin"

cat >"${test_root}/bin/python3" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" == "-c" && "$2" == "import e2b" ]]; then
  exit 0
fi
printf '%s\n' "$*" >"$MOCK_PYTHON_CALLS"
MOCK
chmod +x "${test_root}/bin/python3"

calls_path="${test_root}/calls"
if E2B_API_KEY='' "${repo_root}/scripts/build_template.sh" general \
  >"${test_root}/missing-token.out" 2>"${test_root}/missing-token.err"; then
  printf '%s\n' 'expected a missing access token to fail' >&2
  exit 1
elif [[ "$?" -ne 78 ]]; then
  printf '%s\n' 'missing access token returned the wrong status' >&2
  exit 1
fi

E2B_API_KEY=test-key \
  FIRNA_ENVS_PYTHON="${test_root}/bin/python3" \
  MOCK_PYTHON_CALLS="$calls_path" \
  "${repo_root}/scripts/build_template.sh" general

expected_call="${repo_root}/scripts/build_template.py --environment-dir ${repo_root}/envs/general --template firna-general-v2 --cpu 2 --memory-mb 2048"
if [[ "$(<"$calls_path")" != "$expected_call" ]]; then
  printf 'unexpected create call: %s\n' "$(<"$calls_path")" >&2
  exit 1
fi
