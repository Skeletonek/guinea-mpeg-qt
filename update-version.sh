#!/bin/bash
# Update version string across the project.
# Usage: ./update-version.sh 0.2.1

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

VERSION="$1"
ROOT="$(cd "$(dirname "$0")" && pwd)"

# rust/Cargo.toml — canonical source
sed -i "s/^version = \".*\"/version = \"$VERSION\"/" "$ROOT/rust/Cargo.toml"

# CMakeLists.txt
sed -i "s/^project(guinea_mpeg VERSION [0-9.]*/project(guinea_mpeg VERSION $VERSION/" "$ROOT/CMakeLists.txt"

echo "Version updated to $VERSION in:"
echo "  rust/Cargo.toml"
echo "  CMakeLists.txt"
