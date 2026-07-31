FROM archlinux:latest

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
    base-devel \
    cmake \
    pkgconf \
    cargo \
    rust \
    mpv \
    qt6-base \
    qt6-multimedia \
    qt6-declarative \
    qt6-tools \
    && pacman -Scc --noconfirm
