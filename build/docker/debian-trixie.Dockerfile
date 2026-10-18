FROM debian:trixie-slim

# Temporary workaround: deb.debian.org index fetches were flaky on dind runners
# (partial update -> "Unable to locate package"), so pin a single mirror.
# TODO: switch back to deb.debian.org once the dind flakiness is resolved.
RUN sed -i 's/deb\.debian\.org/ftp.us.debian.org/' /etc/apt/sources.list.d/debian.sources \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    pkg-config \
    ca-certificates \
    cargo \
    rustc \
    libmpv-dev \
    qt6-base-dev \
    qt6-multimedia-dev \
    qt6-xdgdesktopportal-platformtheme \
    qml6-module-qtmultimedia \
    libqt6svg6 \
    libgl1-mesa-dev \
    libegl1-mesa-dev \
    libxkbcommon-dev \
    wayland-protocols \
    wget \
    file \
    patchelf \
    ffmpeg \
 && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    qt6-declarative-dev \
    qt6-tools-dev \
 && rm -rf /var/lib/apt/lists/*
