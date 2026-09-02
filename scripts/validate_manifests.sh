#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'usage: %s [--source-root PATH] [--allow-legacy-manifest]\n' "$0" >&2
}

tool_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly tool_root
source_root="$tool_root"
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
    *)
      usage
      exit 64
      ;;
  esac
done
if ! source_root="$(cd "$source_root" 2>/dev/null && pwd -P)"; then
  printf '%s\n' 'error: source root is not an accessible directory' >&2
  exit 66
fi
if [[ "$allow_legacy_manifest" == true && "$source_root" == "$tool_root" ]]; then
  printf '%s\n' 'error: legacy compatibility requires a separate source root' >&2
  exit 64
fi
readonly source_root allow_legacy_manifest
envs_root="${source_root}/envs"
readonly envs_root
status=0

report_error() {
  printf 'error: %s\n' "$1" >&2
  status=1
}

validate_integer() {
  local label="$1"
  local value="$2"

  if [[ ! "$value" =~ ^[1-9][0-9]*$ ]]; then
    report_error "${label} must be a positive integer"
    return 1
  fi
}

if ! command -v yq >/dev/null 2>&1; then
  printf 'error: yq is required to validate manifests\n' >&2
  exit 127
fi

if [[ ! -d "$envs_root" ]]; then
  exit 0
fi

shopt -s nullglob
for dir in "$envs_root"/*/; do
  env_name="$(basename "$dir")"

  for required_file in manifest.yaml Dockerfile verify.sh; do
    if [[ ! -f "${dir}${required_file}" ]]; then
      report_error "${dir#"${source_root}/"}${required_file} is missing"
    fi
  done

  while IFS= read -r entry; do
    entry_name="$(basename "$entry")"
    case "$entry_name" in
      manifest.yaml | Dockerfile | verify.sh | INVENTORY.md) ;;
      *) report_error "${entry#"${source_root}/"} is not allowed in an environment directory" ;;
    esac
  done < <(find "$dir" -mindepth 1 -maxdepth 1 -print)

  manifest="${dir}manifest.yaml"
  if [[ ! -f "$manifest" ]]; then
    continue
  fi
  if ! yq -e '.' "$manifest" >/dev/null 2>&1; then
    report_error "${manifest#"${source_root}/"} is not valid YAML"
    continue
  fi

  name="$(yq -r '.name // ""' "$manifest")"
  version="$(yq -r '.version // ""' "$manifest")"
  description="$(yq -r '.description // ""' "$manifest")"
  cpu="$(yq -r '.resources.cpu // ""' "$manifest")"
  memory_mb="$(yq -r '.resources.memory_mb // ""' "$manifest")"

  if [[ "$name" != "$env_name" ]]; then
    report_error "${manifest#"${source_root}/"}: name '${name}' must equal directory '${env_name}'"
  fi
  if [[ ! "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    report_error "${manifest#"${source_root}/"}: name must use lowercase letters, numbers, and hyphens"
  fi
  validate_integer "${manifest#"${source_root}/"}: version" "$version" || true
  if [[ -z "$description" ]]; then
    report_error "${manifest#"${source_root}/"}: description must not be empty"
  fi
  validate_integer "${manifest#"${source_root}/"}: resources.cpu" "$cpu" || true
  if validate_integer "${manifest#"${source_root}/"}: resources.memory_mb" "$memory_mb"; then
    if ((memory_mb % 2 != 0)); then
      report_error "${manifest#"${source_root}/"}: resources.memory_mb must be even"
    fi
  fi

  has_gcsfuse=false
  if ! yq -e '.gcsfuse != null' "$manifest" >/dev/null 2>&1; then
    if [[ "$allow_legacy_manifest" != true ]]; then
      report_error "${manifest#"${source_root}/"}: gcsfuse is required"
    fi
  else
    has_gcsfuse=true
    gcsfuse_version="$(yq -r '.gcsfuse.version // ""' "$manifest")"
    gcsfuse_key_sha="$(yq -r '.gcsfuse.repository_key_sha256 // ""' "$manifest")"
    if [[ ! "$gcsfuse_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      report_error "${manifest#"${source_root}/"}: gcsfuse.version must be semantic x.y.z"
    fi
    if [[ ! "$gcsfuse_key_sha" =~ ^[0-9a-f]{64}$ ]]; then
      report_error "${manifest#"${source_root}/"}: gcsfuse.repository_key_sha256 must be a lowercase SHA-256 digest"
    fi
    dockerfile="${dir}Dockerfile"
    if [[ -f "$dockerfile" ]]; then
      if ! grep -Fqx "ENV GCSFUSE_VERSION=${gcsfuse_version}" "$dockerfile"; then
        report_error "${dockerfile#"${source_root}/"}: GCSFUSE_VERSION must match the manifest"
      fi
      if ! grep -Fqx "ENV GOOGLE_CLOUD_APT_CHECKSUM=${gcsfuse_key_sha}" "$dockerfile"; then
        report_error "${dockerfile#"${source_root}/"}: GOOGLE_CLOUD_APT_CHECKSUM must match the manifest"
      fi
      if ! grep -Fq "\"gcsfuse=\${GCSFUSE_VERSION}\"" "$dockerfile"; then
        report_error "${dockerfile#"${source_root}/"}: gcsfuse must install the exact manifest version"
      fi
    fi
  fi

  verify_script="${dir}verify.sh"
  if [[ -f "$verify_script" ]]; then
    if [[ ! -x "$verify_script" ]]; then
      report_error "${verify_script#"${source_root}/"} must be executable"
    fi
    if [[ "$(head -n 1 "$verify_script")" != '#!/usr/bin/env bash' ]]; then
      report_error "${verify_script#"${source_root}/"} must use the repository Bash shebang"
    fi
    if ! grep -Fxq 'set -euo pipefail' "$verify_script"; then
      report_error "${verify_script#"${source_root}/"} must enable Bash strict mode"
    fi
    if [[ "$has_gcsfuse" == true ]] \
      && ! grep -Fq 'gcsfuse --version' "$verify_script"; then
      report_error "${verify_script#"${source_root}/"} must verify gcsfuse"
    fi
    if [[ "$has_gcsfuse" == true ]] \
      && ! grep -Fq '[[ -c /dev/fuse ]]' "$verify_script"; then
      report_error "${verify_script#"${source_root}/"} must verify the FUSE device"
    fi
  fi

  if yq -e '.bowser != null' "$manifest" >/dev/null 2>&1; then
    bowser_version="$(yq -r '.bowser.version // ""' "$manifest")"
    bowser_contract="$(yq -r '.bowser.contract // ""' "$manifest")"
    bowser_sha="$(yq -r '.bowser.sha256 // ""' "$manifest")"
    if [[ ! "$bowser_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      report_error "${manifest#"${source_root}/"}: bowser.version must be semantic x.y.z"
    fi
    if [[ ! "$bowser_sha" =~ ^[0-9a-f]{64}$ ]]; then
      report_error "${manifest#"${source_root}/"}: bowser.sha256 must be a lowercase SHA-256 digest"
    fi
    contract_file=''
    if [[ -z "$bowser_contract" && "$allow_legacy_manifest" == true ]]; then
      :
    elif [[ ! "$bowser_contract" =~ ^contracts/[a-z0-9][a-z0-9-]*\.json$ ]]; then
      report_error "${manifest#"${source_root}/"}: bowser.contract must name a JSON file under contracts"
    else
      contract_file="${source_root}/${bowser_contract}"
      if [[ ! -f "$contract_file" ]]; then
        report_error "${bowser_contract} is missing"
      elif ! python3 "${tool_root}/scripts/verify_bowser_contract.py" \
        "$contract_file" --contract-only; then
        report_error "${bowser_contract} does not satisfy the Bowser contract schema"
      else
        contract_bowser_version="$(yq -r '.bowser_version // ""' "$contract_file")"
        if [[ "$contract_bowser_version" != "$bowser_version" ]]; then
          report_error "${manifest#"${source_root}/"}: bowser.version must match ${bowser_contract}"
        fi
      fi
    fi
    dockerfile="${dir}Dockerfile"
    if [[ -f "$dockerfile" ]]; then
      if ! grep -Fqx "ENV BOWSER_VERSION=${bowser_version}" "$dockerfile"; then
        report_error "${dockerfile#"${source_root}/"}: BOWSER_VERSION must match the manifest"
      fi
      if ! grep -Fqx "ENV BOWSER_SHA256=${bowser_sha}" "$dockerfile"; then
        report_error "${dockerfile#"${source_root}/"}: BOWSER_SHA256 must match the manifest"
      fi
      if [[ -n "$contract_file" ]] \
        && ! grep -Fqx "COPY ${bowser_contract} /etc/firna/browser-bowser.json" "$dockerfile"; then
        report_error "${dockerfile#"${source_root}/"}: Bowser contract must be installed from the manifest path"
      fi
      if [[ -n "$contract_file" ]] && ! grep -Fqx \
        'COPY scripts/verify_bowser_contract.py /usr/local/libexec/firna-verify-bowser-contract' \
        "$dockerfile"; then
        report_error "${dockerfile#"${source_root}/"}: Bowser contract verifier must be installed"
      fi
    fi
    if [[ -n "$contract_file" && -f "$verify_script" ]]; then
      if ! grep -Fq \
        'bowser --json-envelope capabilities' \
        "$verify_script" \
        || ! grep -Fq "\"\$bowser_contract_verifier\" \"\$bowser_contract\"" \
        "$verify_script"; then
        report_error "${verify_script#"${source_root}/"} must validate Bowser against the installed contract"
      fi
    fi
  fi

  if yq -e '.chrome != null' "$manifest" >/dev/null 2>&1; then
    chrome_version="$(yq -r '.chrome.version // ""' "$manifest")"
    chrome_url="$(yq -r '.chrome.url // ""' "$manifest")"
    chrome_sha="$(yq -r '.chrome.sha256 // ""' "$manifest")"
    if [[ ! "$chrome_version" =~ ^[0-9]+(\.[0-9]+){3}-[0-9]+$ ]]; then
      report_error "${manifest#"${source_root}/"}: chrome.version must be a four-part Debian package version"
    fi
    if [[ ! "$chrome_sha" =~ ^[0-9a-f]{64}$ ]]; then
      report_error "${manifest#"${source_root}/"}: chrome.sha256 must be a lowercase SHA-256 digest"
    fi
    expected_chrome_url="https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_${chrome_version}_amd64.deb"
    if [[ -z "$chrome_url" && "$allow_legacy_manifest" == true ]]; then
      :
    elif [[ "$chrome_url" != "$expected_chrome_url" ]]; then
      report_error "${manifest#"${source_root}/"}: chrome.url must be the exact versioned Google package URL"
    fi
    dockerfile="${dir}Dockerfile"
    if [[ -f "$dockerfile" ]]; then
      if ! grep -Fqx "ENV CHROME_VERSION=${chrome_version}" "$dockerfile"; then
        report_error "${dockerfile#"${source_root}/"}: CHROME_VERSION must match the manifest"
      fi
      if ! grep -Fqx "ENV CHROME_SHA256=${chrome_sha}" "$dockerfile"; then
        report_error "${dockerfile#"${source_root}/"}: CHROME_SHA256 must match the manifest"
      fi
      if [[ -n "$chrome_url" ]] \
        && ! grep -Fqx "ENV CHROME_URL=${chrome_url}" "$dockerfile"; then
        report_error "${dockerfile#"${source_root}/"}: CHROME_URL must match the manifest"
      fi
      if [[ -n "$chrome_url" ]] \
        && ! grep -Fq "\"\$CHROME_URL\"" "$dockerfile"; then
        report_error "${dockerfile#"${source_root}/"}: Chrome download must use CHROME_URL"
      fi
    fi
  fi
done

exit "$status"
