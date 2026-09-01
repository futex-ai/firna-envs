FROM ubuntu:24.04@sha256:52df9b1ee71626e0088f7d400d5c6b5f7bb916f8f0c82b474289a4ece6cf3faf

ENV DEBIAN_FRONTEND=noninteractive
ENV GCSFUSE_VERSION=3.11.2
ENV GOOGLE_CLOUD_APT_CHECKSUM=3ecc63922b7795eb23fdc449ff9396f9114cb3cf186d6f5b53ad4cc3ebfbb11f

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dbus \
        fonts-liberation \
        fonts-noto-color-emoji \
        fuse3 \
        gnupg \
        iproute2 \
        libasound2t64 \
        lsb-release \
        fluxbox \
        procps \
        python3 \
        tigervnc-standalone-server \
        util-linux \
        websockify \
        x11-utils \
        x11-xserver-utils \
        x11vnc \
    && curl --fail --silent --show-error --location --retry 5 \
        https://packages.cloud.google.com/apt/doc/apt-key.gpg \
        --output /tmp/google-cloud-apt-key.gpg \
    && printf '%s  %s\n' "$GOOGLE_CLOUD_APT_CHECKSUM" \
        /tmp/google-cloud-apt-key.gpg > /tmp/google-cloud-apt-key.sha256 \
    && sha256sum --check /tmp/google-cloud-apt-key.sha256 \
    && gpg --dearmor --yes --output /usr/share/keyrings/cloud.google.gpg \
        /tmp/google-cloud-apt-key.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt gcsfuse-$(lsb_release --codename --short) main" \
        > /etc/apt/sources.list.d/gcsfuse.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends "gcsfuse=${GCSFUSE_VERSION}" \
    && test "$(dpkg-query --show --showformat='${Version}' gcsfuse)" = "$GCSFUSE_VERSION" \
    && rm /tmp/google-cloud-apt-key.gpg /tmp/google-cloud-apt-key.sha256 \
    && rm -rf /var/lib/apt/lists/*

ENV CHROME_VERSION=152.0.7977.64-1
ENV CHROME_URL=https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_152.0.7977.64-1_amd64.deb
ENV CHROME_SHA256=4eae0736a812d9bc851cd2937f7af00e47dbaf8305845eed452703ff009873c7

RUN curl --fail --silent --show-error --location --retry 5 \
        "$CHROME_URL" \
        --output /tmp/chrome.deb \
    && printf '%s  %s\n' "$CHROME_SHA256" /tmp/chrome.deb > /tmp/chrome.sha256 \
    && sha256sum --check /tmp/chrome.sha256 \
    && test "$(dpkg-deb --field /tmp/chrome.deb Version)" = "$CHROME_VERSION" \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/chrome.deb \
    && rm -f /tmp/chrome.deb /tmp/chrome.sha256 \
    && rm -rf /var/lib/apt/lists/*

ENV BOWSER_VERSION=0.3.0
ENV BOWSER_SHA256=3237484c0edfb3b230f264b43fa7b034a221cb2bd1c03f07e6e40e278d513070

RUN curl --fail --silent --show-error --location --retry 5 \
        "https://github.com/futex-ai/bowser/releases/download/v${BOWSER_VERSION}/bowser-${BOWSER_VERSION}-x86_64-unknown-linux-gnu.tar.gz" \
        --output /tmp/bowser.tar.gz \
    && printf '%s  %s\n' "$BOWSER_SHA256" /tmp/bowser.tar.gz > /tmp/bowser.sha256 \
    && sha256sum --check /tmp/bowser.sha256 \
    && mkdir -p /tmp/bowser \
    && tar --extract --gzip --file /tmp/bowser.tar.gz \
        --directory /tmp/bowser --strip-components 1 \
    && install --mode 0755 /tmp/bowser/bowser /usr/local/bin/bowser \
    && rm -rf /tmp/bowser /tmp/bowser.tar.gz /tmp/bowser.sha256

ENV BOWSER_CHROME_PATH=/usr/bin/google-chrome-stable

COPY contracts/browser-bowser.json /etc/firna/browser-bowser.json
COPY scripts/verify_bowser_contract.py /usr/local/libexec/firna-verify-bowser-contract

RUN chmod 0755 /usr/local/libexec/firna-verify-bowser-contract

# hadolint ignore=SC2016
RUN mkdir -p /etc/firna-screen \
    && printf '%s\n' \
        'session.screen0.toolbar.visible: false' \
        '# firna-screen-wm' \
        > /etc/firna-screen/fluxbox-rc \
    && printf '%s\n' \
        '#!/bin/sh' \
        '# BEGIN FIRNA_SCREEN_HELPER' \
        'set -eu' \
        '' \
        'DISPLAY_ID=":0"' \
        'DISPLAY_OUTPUT="VNC-0"' \
        'WATCH_VNC_PORT=5900' \
        'CONTROL_VNC_PORT=5901' \
        'WATCH_BRIDGE_PORT=6080' \
        'CONTROL_BRIDGE_PORT=6081' \
        'LOG_DIR="/tmp/firna-screen"' \
        'LOCK_FILE="/tmp/firna-screen.lock"' \
        'MODE_STATE_FILE="${LOG_DIR}/mode"' \
        'XVNC_SOCKET="${LOG_DIR}/xvnc.sock"' \
        'XVNC_PID_FILE="${LOG_DIR}/xvnc.pid"' \
        'WATCH_VNC_PID_FILE="${LOG_DIR}/x11vnc-watch.pid"' \
        'CONTROL_VNC_PID_FILE="${LOG_DIR}/x11vnc-control.pid"' \
        'WATCH_BRIDGE_PID_FILE="${LOG_DIR}/websockify-watch.pid"' \
        'CONTROL_BRIDGE_PID_FILE="${LOG_DIR}/websockify-control.pid"' \
        'WATCH_VNC_REMOTE="X11VNC_REMOTE_FIRNA_WATCH"' \
        'CONTROL_VNC_REMOTE="X11VNC_REMOTE_FIRNA_CONTROL"' \
        'READY_TIMEOUT_SECONDS=30' \
        'RESIZE_ATTEMPTS=150' \
        'MIN_WIDTH=320' \
        'MAX_WIDTH=3840' \
        'MIN_HEIGHT=240' \
        'MAX_HEIGHT=2160' \
        'MAX_PIXELS=8294400' \
        '' \
        'capabilities() {' \
        '    printf '\''%s\n'\'' '\''{"version":1,"features":{"dynamic_resize":true},"viewport":{"min_width":320,"max_width":3840,"min_height":240,"max_height":2160,"max_pixels":8294400}}'\''' \
        '}' \
        '' \
        'port_listening() {' \
        '    hex_port=$(printf '\''%04X'\'' "$1")' \
        '    awk -v suffix=":${hex_port}" \' \
        '        '\''$2 ~ suffix"$" && $4 == "0A" { found = 1 } END { exit found ? 0 : 1 }'\'' \' \
        '        /proc/net/tcp /proc/net/tcp6 2>/dev/null' \
        '}' \
        '' \
        'wait_for_port() {' \
        '    waited=0' \
        '    while ! port_listening "$1"; do' \
        '        if [ "$waited" -ge "$READY_TIMEOUT_SECONDS" ]; then' \
        '            echo "firna-screen: port $1 did not start listening" >&2' \
        '            exit 1' \
        '        fi' \
        '        sleep 1' \
        '        waited=$((waited + 1))' \
        '    done' \
        '}' \
        '' \
        'display_dimensions() {' \
        '    xdpyinfo -display "$DISPLAY_ID" | awk '\''/dimensions:/{print $2; exit}'\''' \
        '}' \
        '' \
        'wait_for_display() {' \
        '    waited=0' \
        '    while ! xdpyinfo -display "$DISPLAY_ID" >/dev/null 2>&1; do' \
        '        if [ "$waited" -ge "$READY_TIMEOUT_SECONDS" ]; then' \
        '            echo "firna-screen: display $DISPLAY_ID did not become ready" >&2' \
        '            exit 1' \
        '        fi' \
        '        sleep 1' \
        '        waited=$((waited + 1))' \
        '    done' \
        '}' \
        '' \
        'wait_for_geometry() {' \
        '    target="$1"' \
        '    waited=0' \
        '    while [ "$(display_dimensions)" != "$target" ]; do' \
        '        if [ "$waited" -ge "$RESIZE_ATTEMPTS" ]; then' \
        '            echo "firna-screen: display did not apply requested geometry" >&2' \
        '            exit 1' \
        '        fi' \
        '        sleep 0.1' \
        '        waited=$((waited + 1))' \
        '    done' \
        '}' \
        '' \
        'vnc_dimensions() {' \
        '    DISPLAY="$DISPLAY_ID" X11VNC_REMOTE="$1" x11vnc -Q dpy_x,dpy_y 2>/dev/null | sed -n "s/.*dpy_x:\([0-9][0-9]*\).*dpy_y:\([0-9][0-9]*\).*/\1x\2/p"' \
        '}' \
        '' \
        'wait_for_vnc_geometry() {' \
        '    remote="$1"' \
        '    target="$2"' \
        '    waited=0' \
        '    while [ "$(vnc_dimensions "$remote")" != "$target" ]; do' \
        '        if [ "$waited" -ge "$RESIZE_ATTEMPTS" ]; then' \
        '            echo "firna-screen: VNC did not apply requested geometry" >&2' \
        '            exit 1' \
        '        fi' \
        '        sleep 0.1' \
        '        waited=$((waited + 1))' \
        '    done' \
        '}' \
        '' \
        'refresh_vnc_geometry() {' \
        '    target="$1"' \
        '    DISPLAY="$DISPLAY_ID" X11VNC_REMOTE="$WATCH_VNC_REMOTE" x11vnc -R reset >/dev/null 2>&1' \
        '    wait_for_vnc_geometry "$WATCH_VNC_REMOTE" "$target"' \
        '    DISPLAY="$DISPLAY_ID" X11VNC_REMOTE="$CONTROL_VNC_REMOTE" x11vnc -R reset >/dev/null 2>&1' \
        '    wait_for_vnc_geometry "$CONTROL_VNC_REMOTE" "$target"' \
        '}' \
        '' \
        'ensure_locked() {' \
        '    mkdir -p "$LOG_DIR"' \
        '    chmod 0700 "$LOG_DIR"' \
        '    if ! xdpyinfo -display "$DISPLAY_ID" >/dev/null 2>&1; then' \
        '        unlink "$XVNC_SOCKET" >/dev/null 2>&1 || true' \
        '        unlink "$XVNC_PID_FILE" >/dev/null 2>&1 || true' \
        '        nohup Xtigervnc "$DISPLAY_ID" -ac -geometry 1280x800 -depth 24 \' \
        '            -rfbport -1 -rfbunixpath "$XVNC_SOCKET" -rfbunixmode 0600 \' \
        '            -SecurityTypes None -desktop firna-display -noreset -nolisten tcp \' \
        '            >"$LOG_DIR/xvnc.log" 2>&1 9>&- &' \
        '        printf '\''%s\n'\'' "$!" > "$XVNC_PID_FILE"' \
        '        wait_for_display' \
        '    fi' \
        '    if ! pgrep -f "fluxbox.*firna-screen" >/dev/null 2>&1; then' \
        '        DISPLAY="$DISPLAY_ID" nohup fluxbox -rc /etc/firna-screen/fluxbox-rc \' \
        '            -display "$DISPLAY_ID" >"$LOG_DIR/fluxbox.log" 2>&1 9>&- &' \
        '    fi' \
        '    if ! port_listening "$WATCH_VNC_PORT"; then' \
        '        unlink "$WATCH_VNC_PID_FILE" >/dev/null 2>&1 || true' \
        '        X11VNC_REMOTE="$WATCH_VNC_REMOTE" nohup x11vnc \' \
        '            -display "$DISPLAY_ID" -viewonly -shared -forever -nopw \' \
        '            -xrandr resize -localhost -rfbport "$WATCH_VNC_PORT" \' \
        '            -desktop firna-watch -o "$LOG_DIR/x11vnc-watch.log" \' \
        '            >/dev/null 2>&1 9>&- &' \
        '        printf '\''%s\n'\'' "$!" > "$WATCH_VNC_PID_FILE"' \
        '        wait_for_port "$WATCH_VNC_PORT"' \
        '    fi' \
        '    if ! port_listening "$CONTROL_VNC_PORT"; then' \
        '        unlink "$CONTROL_VNC_PID_FILE" >/dev/null 2>&1 || true' \
        '        X11VNC_REMOTE="$CONTROL_VNC_REMOTE" nohup x11vnc \' \
        '            -display "$DISPLAY_ID" -shared -forever -nopw \' \
        '            -xrandr resize \' \
        '            -localhost -rfbport "$CONTROL_VNC_PORT" -desktop firna-control \' \
        '            -o "$LOG_DIR/x11vnc-control.log" >/dev/null 2>&1 9>&- &' \
        '        printf '\''%s\n'\'' "$!" > "$CONTROL_VNC_PID_FILE"' \
        '        wait_for_port "$CONTROL_VNC_PORT"' \
        '    fi' \
        '    if ! port_listening "$WATCH_BRIDGE_PORT"; then' \
        '        unlink "$WATCH_BRIDGE_PID_FILE" >/dev/null 2>&1 || true' \
        '        nohup websockify 127.0.0.1:"$WATCH_BRIDGE_PORT" \' \
        '            127.0.0.1:"$WATCH_VNC_PORT" >"$LOG_DIR/websockify-watch.log" 2>&1 9>&- &' \
        '        printf '\''%s\n'\'' "$!" > "$WATCH_BRIDGE_PID_FILE"' \
        '    fi' \
        '    if ! port_listening "$CONTROL_BRIDGE_PORT"; then' \
        '        unlink "$CONTROL_BRIDGE_PID_FILE" >/dev/null 2>&1 || true' \
        '        nohup websockify 127.0.0.1:"$CONTROL_BRIDGE_PORT" \' \
        '            127.0.0.1:"$CONTROL_VNC_PORT" >"$LOG_DIR/websockify-control.log" 2>&1 9>&- &' \
        '        printf '\''%s\n'\'' "$!" > "$CONTROL_BRIDGE_PID_FILE"' \
        '    fi' \
        '    wait_for_port "$WATCH_BRIDGE_PORT"' \
        '    wait_for_port "$CONTROL_BRIDGE_PORT"' \
        '}' \
        '' \
        'is_unsigned_integer() {' \
        '    case "$1" in' \
        '        '\'''\''|*[!0-9]*) return 1 ;;' \
        '        0|[1-9]*) return 0 ;;' \
        '        *) return 1 ;;' \
        '    esac' \
        '}' \
        '' \
        'validate_size() {' \
        '    width="$1"' \
        '    height="$2"' \
        '    if ! is_unsigned_integer "$width" \' \
        '        || ! is_unsigned_integer "$height" \' \
        '        || [ "$width" -lt "$MIN_WIDTH" ] \' \
        '        || [ "$width" -gt "$MAX_WIDTH" ] \' \
        '        || [ "$height" -lt "$MIN_HEIGHT" ] \' \
        '        || [ "$height" -gt "$MAX_HEIGHT" ] \' \
        '        || [ "$((width * height))" -gt "$MAX_PIXELS" ]; then' \
        '        echo "firna-screen: invalid viewport" >&2' \
        '        return 2' \
        '    fi' \
        '}' \
        '' \
        'resize_locked() {' \
        '    width="$1"' \
        '    height="$2"' \
        '    validate_size "$width" "$height"' \
        '    ensure_locked' \
        '    target="${width}x${height}"' \
        '    if [ "$(display_dimensions)" = "$target" ]; then' \
        '        refresh_vnc_geometry "$target"' \
        '        printf '\''{"version":1,"width":%s,"height":%s}\n'\'' "$width" "$height"' \
        '        return' \
        '    fi' \
        '' \
        '    hsync_start=$((width + 16))' \
        '    hsync_end=$((hsync_start + 32))' \
        '    htotal=$((hsync_end + 48))' \
        '    vsync_start=$((height + 3))' \
        '    vsync_end=$((vsync_start + 5))' \
        '    vtotal=$((vsync_end + 10))' \
        '    clock=$(awk -v h="$htotal" -v v="$vtotal" \' \
        '        '\''BEGIN { printf "%.3f", h * v * 60 / 1000000 }'\'')' \
        '    mode="firna_${width}x${height}_$$"' \
        '    DISPLAY="$DISPLAY_ID" xrandr --newmode "$mode" "$clock" \' \
        '        "$width" "$hsync_start" "$hsync_end" "$htotal" \' \
        '        "$height" "$vsync_start" "$vsync_end" "$vtotal"' \
        '    DISPLAY="$DISPLAY_ID" xrandr --addmode "$DISPLAY_OUTPUT" "$mode"' \
        '    DISPLAY="$DISPLAY_ID" xrandr --output "$DISPLAY_OUTPUT" --mode "$mode"' \
        '    wait_for_geometry "$target"' \
        '    refresh_vnc_geometry "$target"' \
        '' \
        '    previous=""' \
        '    if [ -f "$MODE_STATE_FILE" ]; then' \
        '        IFS= read -r previous < "$MODE_STATE_FILE" || previous=""' \
        '    fi' \
        '    printf '\''%s\n'\'' "$mode" > "$MODE_STATE_FILE"' \
        '    case "$previous" in' \
        '        firna_*)' \
        '            DISPLAY="$DISPLAY_ID" xrandr --delmode "$DISPLAY_OUTPUT" \' \
        '                "$previous" >/dev/null 2>&1 || true' \
        '            DISPLAY="$DISPLAY_ID" xrandr --rmmode "$previous" \' \
        '                >/dev/null 2>&1 || true' \
        '            ;;' \
        '    esac' \
        '    printf '\''{"version":1,"width":%s,"height":%s}\n'\'' "$width" "$height"' \
        '}' \
        '' \
        'run_locked() {' \
        '    exec 9>"$LOCK_FILE"' \
        '    flock -x 9' \
        '    "$@"' \
        '}' \
        '' \
        'usage() {' \
        '    echo "usage: firna-screen ensure|capabilities|resize <width> <height>" >&2' \
        '    exit 2' \
        '}' \
        '' \
        'case "${1:-}" in' \
        '    ensure)' \
        '        [ "$#" -eq 1 ] || usage' \
        '        run_locked ensure_locked' \
        '        ;;' \
        '    capabilities)' \
        '        [ "$#" -eq 1 ] || usage' \
        '        capabilities' \
        '        ;;' \
        '    resize)' \
        '        [ "$#" -eq 3 ] || usage' \
        '        run_locked resize_locked "$2" "$3"' \
        '        ;;' \
        '    *)' \
        '        usage' \
        '        ;;' \
        'esac' \
        '# END FIRNA_SCREEN_HELPER' \
        > /usr/local/bin/firna-screen \
    && chmod 0755 /usr/local/bin/firna-screen
