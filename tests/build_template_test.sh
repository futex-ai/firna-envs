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
  printf '%s\n' 'expected a missing API key to fail' >&2
  exit 1
elif [[ "$?" -ne 78 ]]; then
  printf '%s\n' 'missing API key returned the wrong status' >&2
  exit 1
fi

E2B_API_KEY=test-key \
  FIRNA_ENVS_PYTHON="${test_root}/bin/python3" \
  MOCK_PYTHON_CALLS="$calls_path" \
  "${repo_root}/scripts/build_template.sh" general

expected_call="${repo_root}/scripts/build_template.py --source-root ${repo_root} --environment-dir envs/general --template firna-general-v3 --cpu 2 --memory-mb 2048"
if [[ "$(<"$calls_path")" != "$expected_call" ]]; then
  printf 'unexpected create call: %s\n' "$(<"$calls_path")" >&2
  exit 1
fi

E2B_API_KEY=test-key \
  FIRNA_ENVS_PYTHON="${test_root}/bin/python3" \
  MOCK_PYTHON_CALLS="$calls_path" \
  "${repo_root}/scripts/build_template.sh" general --skip-existing

if [[ "$(<"$calls_path")" != "${expected_call} --skip-existing" ]]; then
  printf 'unexpected idempotent release call: %s\n' "$(<"$calls_path")" >&2
  exit 1
fi

E2B_API_KEY=test-key \
  FIRNA_ENVS_PYTHON="${test_root}/bin/python3" \
  MOCK_PYTHON_CALLS="$calls_path" \
  "${repo_root}/scripts/build_template.sh" general --skip-existing \
    --stage-tag stage-run --result-file "${test_root}/result"

if [[ "$(<"$calls_path")" != "${expected_call} --skip-existing --stage-tag stage-run --result-file ${test_root}/result" ]]; then
  printf 'unexpected staged release call: %s\n' "$(<"$calls_path")" >&2
  exit 1
fi

legacy_source="${test_root}/legacy-source"
mkdir -p "${legacy_source}/envs/browser"
cat >"${legacy_source}/envs/browser/manifest.yaml" <<'YAML'
name: browser
version: 1
description: Historical browser source fixture
resources:
  cpu: 2
  memory_mb: 4096
chrome:
  version: 151.0.7922.71-1
  sha256: c86cafc697ecdb88259312cef47e464d1278643610500a7c9104e6bb1af3ba5c
bowser:
  version: 0.2.0
  sha256: 92458946103fe16e16e1a8eb07398b6d21903d66286776a90c151e5c9823c7d9
YAML
cat >"${legacy_source}/envs/browser/Dockerfile" <<'DOCKERFILE'
FROM debian:bookworm-slim
ENV CHROME_VERSION=151.0.7922.71-1
ENV CHROME_SHA256=c86cafc697ecdb88259312cef47e464d1278643610500a7c9104e6bb1af3ba5c
ENV BOWSER_VERSION=0.2.0
ENV BOWSER_SHA256=92458946103fe16e16e1a8eb07398b6d21903d66286776a90c151e5c9823c7d9
DOCKERFILE
cat >"${legacy_source}/envs/browser/verify.sh" <<'VERIFY'
#!/usr/bin/env bash
set -euo pipefail
true
VERIFY
chmod +x "${legacy_source}/envs/browser/verify.sh"

if E2B_API_KEY=test-key \
  FIRNA_ENVS_PYTHON="${test_root}/bin/python3" \
  MOCK_PYTHON_CALLS="$calls_path" \
  "${repo_root}/scripts/build_template.sh" --source-root "$legacy_source" browser \
  >"${test_root}/strict-legacy.out" 2>"${test_root}/strict-legacy.err"; then
  printf '%s\n' 'expected strict validation to reject a historical manifest' >&2
  exit 1
fi

if E2B_API_KEY=test-key \
  FIRNA_ENVS_PYTHON="${test_root}/bin/python3" \
  MOCK_PYTHON_CALLS="$calls_path" \
  "${repo_root}/scripts/build_template.sh" --source-root "$legacy_source" \
    --allow-legacy-manifest browser --skip-existing \
  >"${test_root}/legacy-without-recovery.out" \
  2>"${test_root}/legacy-without-recovery.err"; then
  printf '%s\n' 'legacy compatibility was accepted without explicit recovery' >&2
  exit 1
fi

E2B_API_KEY=test-key \
  FIRNA_ENVS_PYTHON="${test_root}/bin/python3" \
  MOCK_PYTHON_CALLS="$calls_path" \
  "${repo_root}/scripts/build_template.sh" --source-root "$legacy_source" \
    --allow-legacy-manifest browser --skip-existing --recover-existing

legacy_call="${repo_root}/scripts/build_template.py --source-root ${legacy_source} --environment-dir envs/browser --template firna-browser-v1 --cpu 2 --memory-mb 4096 --skip-existing --recover-existing"
if [[ "$(<"$calls_path")" != "$legacy_call" ]]; then
  printf 'unexpected historical-source build call: %s\n' "$(<"$calls_path")" >&2
  exit 1
fi
if [[ -e "${legacy_source}/scripts" ]]; then
  printf '%s\n' 'historical source unexpectedly needed its own helper scripts' >&2
  exit 1
fi
