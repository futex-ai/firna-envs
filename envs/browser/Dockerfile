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
        python3 \
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
