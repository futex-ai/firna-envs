FROM e2bdev/base@sha256:197ad15124a51884aea5a629b96045cd8300bdbbb6df648647004fad99fc59ec

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        git \
        jq \
        pkg-config \
        python3-pip \
        python3-venv \
        ripgrep \
        unzip \
        wget \
        zip \
    && rm -rf /var/lib/apt/lists/*
