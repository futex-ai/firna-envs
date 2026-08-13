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
        libasound2t64 \
        lsb-release \
        fluxbox \
        procps \
        python3 \
        websockify \
        x11-utils \
        x11vnc \
        xvfb \
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

ENV CHROME_VERSION=151.0.7922.137-1
ENV CHROME_SHA256=e6dabf044cf9cd0279cfe86efa431682c18bfc06d06339ce055aaa87ae871727

RUN curl --fail --silent --show-error --location --retry 5 \
        https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
        --output /tmp/chrome.deb \
    && printf '%s  %s\n' "$CHROME_SHA256" /tmp/chrome.deb > /tmp/chrome.sha256 \
    && sha256sum --check /tmp/chrome.sha256 \
    && test "$(dpkg-deb --field /tmp/chrome.deb Version)" = "$CHROME_VERSION" \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/chrome.deb \
    && rm -f /tmp/chrome.deb /tmp/chrome.sha256 \
    && rm -rf /var/lib/apt/lists/*

ENV BOWSER_VERSION=0.2.0
ENV BOWSER_SHA256=92458946103fe16e16e1a8eb07398b6d21903d66286776a90c151e5c9823c7d9

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

# hadolint ignore=SC2016
RUN mkdir -p /etc/firna-screen \
    && printf '%s\n' \
        'session.screen0.toolbar.visible: false' \
        '# firna-screen-wm' \
        > /etc/firna-screen/fluxbox-rc \
    && printf '%s\n' \
        '#!/bin/sh' \
        'set -eu' \
        '' \
        'DISPLAY_ID=":0"' \
        'WATCH_VNC_PORT=5900' \
        'CONTROL_VNC_PORT=5901' \
        'WATCH_BRIDGE_PORT=6080' \
        'CONTROL_BRIDGE_PORT=6081' \
        'LOG_DIR="/tmp/firna-screen"' \
        'READY_TIMEOUT_SECONDS=30' \
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
        'ensure() {' \
        '    if port_listening "$WATCH_BRIDGE_PORT" && port_listening "$CONTROL_BRIDGE_PORT"; then' \
        '        exit 0' \
        '    fi' \
        '    mkdir -p "$LOG_DIR"' \
        '    if ! xdpyinfo -display "$DISPLAY_ID" >/dev/null 2>&1; then' \
        '        nohup Xvfb "$DISPLAY_ID" -screen 0 1280x800x24 -nolisten tcp \' \
        '            >"$LOG_DIR/xvfb.log" 2>&1 &' \
        '        wait_for_display' \
        '    fi' \
        '    if ! pgrep -f "fluxbox.*firna-screen" >/dev/null 2>&1; then' \
        '        DISPLAY="$DISPLAY_ID" nohup fluxbox -rc /etc/firna-screen/fluxbox-rc \' \
        '            -display "$DISPLAY_ID" >"$LOG_DIR/fluxbox.log" 2>&1 &' \
        '    fi' \
        '    if ! port_listening "$WATCH_VNC_PORT"; then' \
        '        x11vnc -display "$DISPLAY_ID" -viewonly -shared -forever -nopw \' \
        '            -localhost -rfbport "$WATCH_VNC_PORT" -desktop firna-watch \' \
        '            -o "$LOG_DIR/x11vnc-watch.log" -bg >/dev/null 2>&1 || true' \
        '        wait_for_port "$WATCH_VNC_PORT"' \
        '    fi' \
        '    if ! port_listening "$CONTROL_VNC_PORT"; then' \
        '        x11vnc -display "$DISPLAY_ID" -shared -forever -nopw \' \
        '            -localhost -rfbport "$CONTROL_VNC_PORT" -desktop firna-control \' \
        '            -o "$LOG_DIR/x11vnc-control.log" -bg >/dev/null 2>&1 || true' \
        '        wait_for_port "$CONTROL_VNC_PORT"' \
        '    fi' \
        '    if ! port_listening "$WATCH_BRIDGE_PORT"; then' \
        '        nohup websockify 127.0.0.1:"$WATCH_BRIDGE_PORT" \' \
        '            127.0.0.1:"$WATCH_VNC_PORT" >"$LOG_DIR/websockify-watch.log" 2>&1 &' \
        '    fi' \
        '    if ! port_listening "$CONTROL_BRIDGE_PORT"; then' \
        '        nohup websockify 127.0.0.1:"$CONTROL_BRIDGE_PORT" \' \
        '            127.0.0.1:"$CONTROL_VNC_PORT" >"$LOG_DIR/websockify-control.log" 2>&1 &' \
        '    fi' \
        '    wait_for_port "$WATCH_BRIDGE_PORT"' \
        '    wait_for_port "$CONTROL_BRIDGE_PORT"' \
        '    exit 0' \
        '}' \
        '' \
        'case "${1:-}" in' \
        'ensure)' \
        '    ensure' \
        '    ;;' \
        '*)' \
        '    echo "usage: firna-screen ensure" >&2' \
        '    exit 2' \
        '    ;;' \
        'esac' \
        > /usr/local/bin/firna-screen \
    && chmod 0755 /usr/local/bin/firna-screen
