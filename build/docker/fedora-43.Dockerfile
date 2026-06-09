FROM fedora:latest

RUN dnf install -y \
    gcc-c++ \
    cmake \
    pkgconfig \
    cargo \
    rust \
    mpv-libs-devel \
    qt6-qtbase-devel \
    qt6-qtdeclarative-devel \
    qt6-qtquickcontrols2-devel \
    qt6-qtmultimedia-devel \
    mesa-libGL-devel \
    libglvnd-devel \
    libxkbcommon-devel \
    wayland-devel \
    && dnf clean all
