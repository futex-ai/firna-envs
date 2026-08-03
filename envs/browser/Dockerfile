FROM ubuntu:24.04@sha256:52df9b1ee71626e0088f7d400d5c6b5f7bb916f8f0c82b474289a4ece6cf3faf

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dbus \
        fonts-liberation \
        fonts-noto-color-emoji \
        libasound2t64 \
        python3 \
        xvfb \
    && rm -rf /var/lib/apt/lists/*

ENV CHROME_VERSION=151.0.7922.71-1
ENV CHROME_SHA256=c86cafc697ecdb88259312cef47e464d1278643610500a7c9104e6bb1af3ba5c

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
