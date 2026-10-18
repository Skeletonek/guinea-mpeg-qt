FROM debian:trixie-slim

# One big apt step previously OOM'd on dind runners; keep the heavy
# qt6-declarative-dev/qt6-tools-dev transaction in its own cached layer.
RUN apt-get update \
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
