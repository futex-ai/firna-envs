#!/usr/bin/env bash
set -euo pipefail

readonly expected_bowser_version='0.2.0'
readonly expected_chrome_version='151.0.7922.137'
readonly expected_gcsfuse_version='3.11.2'

command -v bowser >/dev/null
command -v fusermount3 >/dev/null
command -v gcsfuse >/dev/null
command -v google-chrome-stable >/dev/null
command -v mountpoint >/dev/null
command -v Xvfb >/dev/null
command -v firna-screen >/dev/null
command -v fluxbox >/dev/null
command -v websockify >/dev/null
command -v x11vnc >/dev/null
command -v xdpyinfo >/dev/null
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

loopback_listening() {
  local hex_port
  hex_port="$(printf '%04X' "$1")"
  local addresses
  addresses="$(awk -v suffix=":${hex_port}" \
    '$2 ~ suffix"$" && $4 == "0A" { split($2, parts, ":"); print parts[1] }' \
    /proc/net/tcp /proc/net/tcp6 2>/dev/null | sort -u)"
  [[ -n "$addresses" ]]
  while IFS= read -r address; do
    [[ "$address" == '0100007F' \
      || "$address" == '00000000000000000000000001000000' ]]
  done <<<"$addresses"
}

firna-screen ensure
loopback_listening 6080
loopback_listening 6081
pgrep -af x11vnc | grep -F -- '-viewonly' | grep -Fq 'firna-watch'
firna-screen ensure
watch_count="$(pgrep -cf 'x11vnc.*firna-watch')"
[[ "$watch_count" == '1' ]]
printf 'firna-screen watch bridge %s\n' 6080
printf 'firna-screen control bridge %s\n' 6081
