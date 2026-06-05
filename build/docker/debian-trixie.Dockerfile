FROM debian:trixie-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    pkg-config \
    ca-certificates \
    cargo \
    rustc \
    libmpv-dev \
    qt6-base-dev \
    qt6-declarative-dev \
    libgl1-mesa-dev \
    libegl1-mesa-dev \
    libxkbcommon-dev \
    wayland-protocols \
    wget \
    file \
    patchelf \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*
