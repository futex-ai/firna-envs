FROM e2bdev/base@sha256:197ad15124a51884aea5a629b96045cd8300bdbbb6df648647004fad99fc59ec

ENV DEBIAN_FRONTEND=noninteractive
ENV GCSFUSE_VERSION=3.11.2
ENV GOOGLE_CLOUD_APT_CHECKSUM=3ecc63922b7795eb23fdc449ff9396f9114cb3cf186d6f5b53ad4cc3ebfbb11f

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        fuse3 \
        git \
        gnupg \
        jq \
        lsb-release \
        pkg-config \
        python3-pip \
        python3-venv \
        ripgrep \
        unzip \
        wget \
        zip \
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
