#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repo_root
dockerfile="${repo_root}/envs/browser/Dockerfile"
manifest="${repo_root}/envs/browser/manifest.yaml"
verify_script="${repo_root}/envs/browser/verify.sh"
test_root="$(mktemp -d)"
readonly test_root
trap 'rm -rf "$test_root"' EXIT

if grep -Fq -- '-screen 0 1280x800x24' "$dockerfile"; then
  printf '%s\n' 'browser display is still fixed at 1280x800' >&2
  exit 1
fi

grep -Fxq 'version: 8' "$manifest"
grep -Fq 'tigervnc-standalone-server' "$dockerfile"
grep -Fq 'capabilities)' "$dockerfile"
grep -Fq 'resize)' "$dockerfile"
grep -Eq 'XVNC_PID_FILE=.*xvnc[.]pid' "$dockerfile"
grep -Eq 'WATCH_VNC_PID_FILE=.*x11vnc-watch[.]pid' "$dockerfile"
grep -Eq 'CONTROL_VNC_PID_FILE=.*x11vnc-control[.]pid' "$dockerfile"
[[ "$(grep -Fc -- '-xrandr resize' "$dockerfile")" == '2' ]]

helper="${test_root}/firna-screen"
python3 - "$dockerfile" "$helper" <<'PY'
import shlex
import sys
from pathlib import Path

dockerfile, helper = map(Path, sys.argv[1:])
capturing = False
lines = []
for raw_line in dockerfile.read_text(encoding="utf-8").splitlines():
    stripped = raw_line.strip()
    if not stripped.endswith("\\"):
        continue
    words = shlex.split(stripped[:-1].strip())
    if len(words) != 1:
        continue
    line = words[0]
    if line == "#!/bin/sh":
        capturing = True
    if capturing:
        lines.append(line)
    if line == "# END FIRNA_SCREEN_HELPER":
        break
assert lines[0] == "#!/bin/sh"
assert lines[-1] == "# END FIRNA_SCREEN_HELPER"
helper.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
chmod +x "$helper"
shellcheck "$helper"

capabilities="$($helper capabilities)"
python3 - "$capabilities" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
assert payload == {
    "version": 1,
    "features": {"dynamic_resize": True},
    "viewport": {
        "min_width": 320,
        "max_width": 3840,
        "min_height": 240,
        "max_height": 2160,
        "max_pixels": 8_294_400,
    },
}
PY

invalid_sizes=(
  '319 800'
  '3841 800'
  '1280 239'
  '1280 2161'
  '0320 800'
  'wide 800'
)
for size in "${invalid_sizes[@]}"; do
  read -r width height <<<"$size"
  if "$helper" resize "$width" "$height" >/dev/null 2>&1; then
    printf 'invalid viewport was accepted: %s\n' "$size" >&2
    exit 1
  elif [[ "$?" -ne 2 ]]; then
    printf 'invalid viewport returned wrong status: %s\n' "$size" >&2
    exit 1
  fi
done

for size in '320 240' '390 700' '1280 800' '2560 1080' '3840 2160'; do
  grep -Fq "assert_runtime_size $size" "$verify_script"
done
grep -Fq 'browser-screen-capabilities' "$verify_script"
grep -Fq 'browser-vnc-framebuffer' "$verify_script"
grep -Fq 'browser-responsive-reflow' "$verify_script"
grep -Fq 'assert_owned_process' "$verify_script"
grep -Fq 'owned_process_loopback_listening' "$verify_script"
grep -Fq 'browser screen-stack diagnostics' "$verify_script"
