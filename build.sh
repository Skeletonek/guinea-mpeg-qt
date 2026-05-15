#!/usr/bin/env bash
set -e
mkdir -p build
cd build
cmake ..
cmake --build .
echo "Build complete! Run ./build/appguinea_mpeg"
