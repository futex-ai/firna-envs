#!/usr/bin/env bash
set -euo pipefail

readonly expected_bowser_version='0.3.0'
readonly expected_chrome_version='152.0.7977.64'
readonly expected_gcsfuse_version='3.11.2'

for command in bowser firna-screen flock fluxbox fusermount3 gcsfuse \
  google-chrome-stable mountpoint websockify x11vnc xrandr xdpyinfo Xtigervnc; do
  command -v "$command" >/dev/null
done

bowser_help="$(bowser --help)"
[[ "$bowser_help" == *'Render web pages into compact YAML'* ]]
bowser_capabilities="$(bowser --json-envelope capabilities)"
python3 - "$expected_bowser_version" "$bowser_capabilities" <<'PY'
import json
import sys

expected_version, raw_capabilities = sys.argv[1:]
payload = json.loads(raw_capabilities)
assert payload.get("envelope") == 1
assert payload.get("ok") is True
result = payload.get("result")
assert isinstance(result, dict)
assert result.get("version") == expected_version
features = result.get("features")
assert isinstance(features, dict)
for required in ("history", "kiosk_launch", "live_inventory"):
    assert features.get(required) is True
PY

screen_capabilities="$(firna-screen capabilities)"
python3 - "$screen_capabilities" <<'PY'
import json
import sys

assert json.loads(sys.argv[1]) == {
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
printf '%s\n' 'OK browser-screen-capabilities'

chrome_version="$(google-chrome-stable --version | sed 's/[[:space:]]*$//')"
[[ "$chrome_version" == "Google Chrome ${expected_chrome_version}" ]]
gcsfuse_version="$(gcsfuse --version)"
[[ "$gcsfuse_version" == "gcsfuse version ${expected_gcsfuse_version} "* ]]
[[ -c /dev/fuse ]]
printf 'bowser %s\n' "$expected_bowser_version"
printf '%s\n' 'OK bowser native-chrome capabilities'
printf '%s\n' "$chrome_version"
printf 'Xtigervnc %s\n' "$(command -v Xtigervnc)"
printf '%s\n' "$gcsfuse_version"
printf 'FUSE device %s\n' /dev/fuse

site_root="$(mktemp -d)"
server_pid=''
browser_session_id=''
cleanup() {
  if [[ -n "$browser_session_id" ]]; then
    DISPLAY=:0 timeout 20 bowser --json-envelope --chrome-path \
      /usr/bin/google-chrome-stable --session-dir "${site_root}/session" \
      session close "$browser_session_id" >/dev/null 2>&1 || true
  fi
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" >/dev/null 2>&1 || true
  fi
  rm -rf "$site_root"
}

screen_failure_diagnostics() {
  printf '%s\n' 'browser screen-stack diagnostics:' >&2
  pgrep -af 'Xtigervnc|x11vnc|websockify|fluxbox' >&2 || true
  ss -ltnp '( sport = :5900 or sport = :5901 or sport = :6080 or sport = :6081 )' \
    >&2 || true
  local log
  for log in /tmp/firna-screen/*.log; do
    [[ -f "$log" ]] || continue
    printf '==> %s <==\n' "$log" >&2
    tail -40 "$log" >&2 || true
  done
}

finish() {
  local status="$?"
  trap - EXIT
  if [[ "$status" -ne 0 ]]; then
    screen_failure_diagnostics
  fi
  cleanup
  exit "$status"
}
trap finish EXIT

cat >"${site_root}/vnc_probe.py" <<'PY'
import json
import socket
import struct
import subprocess
import sys
import time


def receive(sock: socket.socket, length: int) -> bytes:
    chunks = bytearray()
    while len(chunks) < length:
        chunk = sock.recv(length - len(chunks))
        if not chunk:
            raise RuntimeError("VNC connection closed")
        chunks.extend(chunk)
    return bytes(chunks)


def connect(port: int) -> tuple[socket.socket, int, int, int]:
    sock = socket.create_connection(("127.0.0.1", port), timeout=10)
    version = receive(sock, 12)
    if not version.startswith(b"RFB 003."):
        raise RuntimeError(f"unexpected VNC version: {version!r}")
    sock.sendall(b"RFB 003.008\n")
    count = receive(sock, 1)[0]
    security_types = receive(sock, count)
    if 1 not in security_types:
        raise RuntimeError(f"VNC None security missing: {security_types!r}")
    sock.sendall(b"\x01")
    if struct.unpack("!I", receive(sock, 4))[0] != 0:
        raise RuntimeError("VNC security negotiation failed")
    sock.sendall(b"\x01")
    width, height, pixel_format, name_length = struct.unpack(
        "!HH16sI", receive(sock, 24)
    )
    receive(sock, name_length)
    return sock, width, height, pixel_format[0] // 8


def parse_size(raw: str) -> tuple[int, int]:
    width, height = raw.split("x", 1)
    return int(width), int(height)


def check(port: int, expected: tuple[int, int]) -> None:
    sock, width, height, _ = connect(port)
    sock.close()
    if (width, height) != expected:
        raise RuntimeError(f"VNC framebuffer {(width, height)} != {expected}")


def observe_resize(port: int, initial: tuple[int, int], target: tuple[int, int]) -> None:
    sock, width, height, bytes_per_pixel = connect(port)
    if (width, height) != initial:
        raise RuntimeError(f"initial VNC framebuffer {(width, height)} != {initial}")
    sock.sendall(struct.pack("!BBHii", 2, 0, 2, -223, 0))
    sock.sendall(struct.pack("!BBHHHH", 3, 1, 0, 0, width, height))
    result = subprocess.run(
        ["firna-screen", "resize", str(target[0]), str(target[1])],
        check=True,
        capture_output=True,
        text=True,
        timeout=20,
    )
    acknowledgment = json.loads(result.stdout)
    if (acknowledgment.get("width"), acknowledgment.get("height")) != target:
        raise RuntimeError(f"wrong resize acknowledgment: {acknowledgment!r}")
    sock.sendall(struct.pack("!BBHHHH", 3, 1, 0, 0, target[0], target[1]))
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        message_type = receive(sock, 1)[0]
        if message_type == 0:
            _, rectangle_count = struct.unpack("!BH", receive(sock, 3))
            for _ in range(rectangle_count):
                _, _, rect_width, rect_height, encoding = struct.unpack(
                    "!HHHHi", receive(sock, 12)
                )
                if encoding == -223 and (rect_width, rect_height) == target:
                    check(port, target)
                    sock.close()
                    return
                if encoding == 0:
                    receive(sock, rect_width * rect_height * bytes_per_pixel)
        elif message_type == 2:
            continue
        elif message_type == 3:
            receive(sock, 3)
            receive(sock, struct.unpack("!I", receive(sock, 4))[0])
        else:
            raise RuntimeError(f"unexpected VNC message type: {message_type}")
    raise RuntimeError(f"VNC resize notification not received for {target}")


mode = sys.argv[1]
port = int(sys.argv[2])
if mode == "check":
    check(port, parse_size(sys.argv[3]))
elif mode == "resize":
    observe_resize(port, parse_size(sys.argv[3]), parse_size(sys.argv[4]))
else:
    raise RuntimeError(f"unknown VNC probe mode: {mode}")
PY

assert_owned_process() {
  local label="$1"
  local pid_file="$2"
  shift 2
  [[ -s "$pid_file" ]] || {
    printf '%s process did not record a PID\n' "$label" >&2
    return 1
  }
  local pid
  IFS= read -r pid <"$pid_file"
  [[ "$pid" =~ ^[1-9][0-9]*$ && -r "/proc/${pid}/cmdline" ]] || {
    printf '%s process PID is not live: %s\n' "$label" "$pid" >&2
    return 1
  }
  local command_line
  command_line="$(tr '\0' ' ' <"/proc/${pid}/cmdline")"
  local expected
  for expected in "$@"; do
    [[ "$command_line" == *"$expected"* ]] || {
      printf '%s process is missing expected argument: %s\n' \
        "$label" "$expected" >&2
      return 1
    }
  done
}

owned_process_loopback_listening() {
  local label="$1"
  local pid_file="$2"
  local port="$3"
  local pid
  IFS= read -r pid <"$pid_file"
  local listeners
  listeners="$(ss -H -ltnp "sport = :${port}" | \
    awk -v marker="pid=${pid}," 'index($0, marker) { print }')"
  [[ -n "$listeners" ]] || {
    printf '%s process has no listener on port %s\n' "$label" "$port" >&2
    return 1
  }
  local listener
  while IFS= read -r listener; do
    local local_address
    read -r _ _ _ local_address _ <<<"$listener"
    case "$local_address" in
      "127.0.0.1:${port}"|"[::1]:${port}") ;;
      *)
        printf '%s process has a non-loopback listener: %s\n' \
          "$label" "$local_address" >&2
        return 1
        ;;
    esac
  done <<<"$listeners"
}

assert_resize_ack() {
  local width="$1"
  local height="$2"
  local acknowledgment
  acknowledgment="$(firna-screen resize "$width" "$height")"
  python3 - "$width" "$height" "$acknowledgment" <<'PY'
import json
import sys

width, height, raw = sys.argv[1:]
assert json.loads(raw) == {
    "version": 1,
    "width": int(width),
    "height": int(height),
}
PY
  [[ "$(xdpyinfo -display :0 | awk '/dimensions:/{print $2; exit}')" \
    == "${width}x${height}" ]]
}

firna-screen ensure
assert_owned_process display /tmp/firna-screen/xvnc.pid \
  Xtigervnc '-rfbport -1' '-rfbunixmode 0600'
[[ -S /tmp/firna-screen/xvnc.sock ]]
[[ "$(stat -c '%a' /tmp/firna-screen/xvnc.sock)" == '600' ]]
assert_owned_process watch-vnc /tmp/firna-screen/x11vnc-watch.pid \
  x11vnc -viewonly firna-watch
assert_owned_process control-vnc /tmp/firna-screen/x11vnc-control.pid \
  x11vnc firna-control
assert_owned_process watch-bridge /tmp/firna-screen/websockify-watch.pid \
  websockify 6080 5900
assert_owned_process control-bridge /tmp/firna-screen/websockify-control.pid \
  websockify 6081 5901
owned_process_loopback_listening watch-vnc \
  /tmp/firna-screen/x11vnc-watch.pid 5900
owned_process_loopback_listening control-vnc \
  /tmp/firna-screen/x11vnc-control.pid 5901
owned_process_loopback_listening watch-bridge \
  /tmp/firna-screen/websockify-watch.pid 6080
owned_process_loopback_listening control-bridge \
  /tmp/firna-screen/websockify-control.pid 6081
printf '%s\n' 'OK browser-screen-stack-security'

watch_pid="$(</tmp/firna-screen/x11vnc-watch.pid)"
control_pid="$(</tmp/firna-screen/x11vnc-control.pid)"
watch_bridge_pid="$(</tmp/firna-screen/websockify-watch.pid)"
control_bridge_pid="$(</tmp/firna-screen/websockify-control.pid)"

valid_contract_sizes=('320 240' '321 241' '3839 2159' '3840 2160')
for size in "${valid_contract_sizes[@]}"; do
  read -r width height <<<"$size"
  assert_resize_ack "$width" "$height"
  python3 "${site_root}/vnc_probe.py" check 5900 "${width}x${height}"
  python3 "${site_root}/vnc_probe.py" check 5901 "${width}x${height}"
done
assert_resize_ack 1280 800

invalid_contract_sizes=(
  '319 800'
  '3841 800'
  '1280 239'
  '1280 2161'
  '3841 2160'
  '3840 2161'
  '0320 800'
  'wide 800'
)
for size in "${invalid_contract_sizes[@]}"; do
  read -r width height <<<"$size"
  if firna-screen resize "$width" "$height" >/dev/null 2>&1; then
    printf 'invalid viewport was accepted: %s\n' "$size" >&2
    exit 1
  elif [[ "$?" -ne 2 ]]; then
    printf 'invalid viewport returned wrong status: %s\n' "$size" >&2
    exit 1
  fi
  [[ "$(xdpyinfo -display :0 | awk '/dimensions:/{print $2; exit}')" \
    == '1280x800' ]]
done

python3 "${site_root}/vnc_probe.py" resize 5900 1280x800 390x700
python3 "${site_root}/vnc_probe.py" resize 5901 390x700 1280x800
[[ "$(</tmp/firna-screen/x11vnc-watch.pid)" == "$watch_pid" ]]
[[ "$(</tmp/firna-screen/x11vnc-control.pid)" == "$control_pid" ]]
[[ "$(</tmp/firna-screen/websockify-watch.pid)" == "$watch_bridge_pid" ]]
[[ "$(</tmp/firna-screen/websockify-control.pid)" == "$control_bridge_pid" ]]
firna-screen ensure
assert_owned_process watch-vnc /tmp/firna-screen/x11vnc-watch.pid \
  x11vnc -viewonly firna-watch
printf '%s\n' 'OK browser-vnc-framebuffer'

cat >"${site_root}/server.py" <<'PY'
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

state = {}
page = b'''<!doctype html>
<meta charset="utf-8">
<title>viewport-smoke</title>
<style>
html, body { margin: 0; min-height: 100%; }
body { background: #eef8f3; font: 20px sans-serif; }
#layout { padding: 24px; }
@media (max-width: 599px) { body { background: #f3efff; } }
</style>
<main id="layout">waiting</main>
<script>
const report = () => {
  const breakpoint = innerWidth < 600 ? 'compact' : 'wide';
  document.querySelector('#layout').textContent =
    `${breakpoint}-layout-${innerWidth}x${innerHeight}`;
  const metrics = new URLSearchParams({
    screen_width: screen.width,
    screen_height: screen.height,
    inner_width: innerWidth,
    inner_height: innerHeight,
    outer_width: outerWidth,
    outer_height: outerHeight,
    breakpoint,
  });
  fetch(`/report?${metrics}`, {cache: 'no-store'}).catch(() => {});
};
addEventListener('resize', report);
report();
</script>'''


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/":
            body = page
            content_type = "text/html; charset=utf-8"
        elif parsed.path == "/report":
            state.update({key: values[-1] for key, values in parse_qs(parsed.query).items()})
            body = b"ok"
            content_type = "text/plain"
        elif parsed.path == "/last":
            body = json.dumps(state, sort_keys=True).encode()
            content_type = "application/json"
        else:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, _format, *_args):
        return


ThreadingHTTPServer(("127.0.0.1", 8377), Handler).serve_forever()
PY
python3 "${site_root}/server.py" >"${site_root}/server.log" 2>&1 &
server_pid="$!"
for _ in {1..40}; do
  curl --fail --silent http://127.0.0.1:8377/ >/dev/null && break
  sleep 0.25
done
curl --fail --silent http://127.0.0.1:8377/ >/dev/null

browser_open="$({
  DISPLAY=:0 bowser --json-envelope --headed --no-ai \
    --chrome-path /usr/bin/google-chrome-stable \
    --session-dir "${site_root}/session" --chrome-args=--kiosk --timeout 45 \
    get --format json http://127.0.0.1:8377/
} 2>"${site_root}/bowser-open.err")"
browser_session_id="$(python3 - "$browser_open" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
assert payload.get("envelope") == 1
assert payload.get("ok") is True
assert payload["result"]["capture"]["title"] == "viewport-smoke"
session = payload.get("session")
assert isinstance(session, str) and session.startswith("bsr_")
print(session)
PY
)"

wait_for_browser_metrics() {
  python3 - "$1" "$2" <<'PY'
import json
import sys
import time
from urllib.request import urlopen

width, height = map(int, sys.argv[1:])
expected_breakpoint = "compact" if width < 600 else "wide"
expected = {
    "screen_width": str(width),
    "screen_height": str(height),
    "inner_width": str(width),
    "inner_height": str(height),
    "outer_width": str(width),
    "outer_height": str(height),
    "breakpoint": expected_breakpoint,
}
deadline = time.monotonic() + 15
last = {}
while time.monotonic() < deadline:
    try:
        with urlopen("http://127.0.0.1:8377/last", timeout=1) as response:
            last = json.load(response)
    except Exception:
        time.sleep(0.1)
        continue
    if last == expected:
        break
    time.sleep(0.1)
else:
    raise RuntimeError(f"browser metrics {last!r} did not become {expected!r}")
PY
}

assert_bowser_layout() {
  local expected="$1"
  local capture_file="${site_root}/capture-envelope.json"
  DISPLAY=:0 bowser --json-envelope --headed --no-ai \
    --chrome-path /usr/bin/google-chrome-stable \
    --session-dir "${site_root}/session" --session "$browser_session_id" \
    --chrome-args=--kiosk --timeout 45 capture --format json >"$capture_file"
  python3 - "$expected" "$capture_file" <<'PY'
import json
import sys

expected, capture_file = sys.argv[1:]
with open(capture_file, encoding="utf-8") as source:
    payload = json.load(source)
assert payload.get("ok") is True
assert expected in json.dumps(payload["result"]["capture"])
PY
}

assert_runtime_size() {
  local width="$1"
  local height="$2"
  assert_resize_ack "$width" "$height"
  python3 "${site_root}/vnc_probe.py" check 5900 "${width}x${height}"
  python3 "${site_root}/vnc_probe.py" check 5901 "${width}x${height}"
  wait_for_browser_metrics "$width" "$height"
  [[ "$(pgrep -f 'x11vnc.*firna-watch')" == "$watch_pid" ]]
  [[ "$(pgrep -f 'x11vnc.*firna-control')" == "$control_pid" ]]
}

assert_runtime_size 320 240
assert_runtime_size 390 700
assert_bowser_layout 'compact-layout-390x700'
assert_runtime_size 1280 800
assert_bowser_layout 'wide-layout-1280x800'
assert_runtime_size 2560 1080
assert_runtime_size 3840 2160
printf '%s\n' 'OK browser-responsive-reflow'
