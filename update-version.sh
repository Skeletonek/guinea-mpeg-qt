#!/bin/bash
# Usage: ./update-version.sh <version>

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

VERSION="$1"
ROOT="$(cd "$(dirname "$0")" && pwd)"

# rust/Cargo.toml is canonical version source
sed -i "s/^version = \".*\"/version = \"$VERSION\"/" "$ROOT/rust/Cargo.toml"

# CMake project() requires plain numeric dotted form
CMAKE_VERSION="$(echo "$VERSION" | sed 's/[-+].*//')"
sed -i "s/^project(guinea_mpeg VERSION [0-9.]*/project(guinea_mpeg VERSION $CMAKE_VERSION/" "$ROOT/CMakeLists.txt"

# build/windows/installer.iss — AppVersion define (plain numeric only)
sed -i "s/^\([[:space:]]*\)#define AppVersion \".*\"/\1#define AppVersion \"$CMAKE_VERSION\"/" "$ROOT/build/windows/installer.iss"

echo "Version updated to $VERSION in:"
echo "  rust/Cargo.toml"
echo "  CMakeLists.txt"
echo "  build/windows/installer.iss"
