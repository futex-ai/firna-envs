#!/usr/bin/env bash
set -euo pipefail

readonly expected_bowser_version='0.2.0'
readonly expected_chrome_version='151.0.7922.71'
readonly expected_gcsfuse_version='3.11.2'

command -v bowser >/dev/null
command -v fusermount3 >/dev/null
command -v gcsfuse >/dev/null
command -v google-chrome-stable >/dev/null
command -v mountpoint >/dev/null
command -v Xvfb >/dev/null
bowser_help="$(bowser --help)"
[[ "$bowser_help" == *'Render web pages into compact YAML'* ]]

chrome_version="$(google-chrome-stable --version | sed 's/[[:space:]]*$//')"
[[ "$chrome_version" == "Google Chrome ${expected_chrome_version}" ]]
printf 'bowser %s\n' "$expected_bowser_version"
printf '%s\n' "$chrome_version"
printf 'Xvfb %s\n' "$(command -v Xvfb)"
gcsfuse_version="$(gcsfuse --version)"
[[ "$gcsfuse_version" == "gcsfuse version ${expected_gcsfuse_version} "* ]]
[[ -c /dev/fuse ]]
printf '%s\n' "$gcsfuse_version"
printf 'FUSE device %s\n' /dev/fuse

site_root="$(mktemp -d)"
server_pid=''
cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" >/dev/null 2>&1 || true
  fi
  rm -rf "$site_root"
}
trap cleanup EXIT

printf '%s\n' \
  '<html><head><title>bowser-smoke</title></head><body><h1>ok</h1></body></html>' \
  >"${site_root}/index.html"
python3 -m http.server 8377 --directory "$site_root" >/dev/null 2>&1 &
server_pid="$!"

ready=0
for _ in {1..20}; do
  if curl --fail --silent http://127.0.0.1:8377/ >/dev/null; then
    ready=1
    break
  fi
  sleep 0.25
done
[[ "$ready" -eq 1 ]]

capture="$(
  bowser get http://127.0.0.1:8377/ \
    --chrome-path /usr/bin/google-chrome-stable \
    --format yaml
)"
[[ "$capture" == *'bowser-smoke'* ]]
printf '%s\n' 'OK browser capture'
