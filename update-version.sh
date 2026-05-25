#!/bin/bash
# Update version string across the project.
# Usage: ./update-version.sh 0.2.1

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

VERSION="$1"
ROOT="$(cd "$(dirname "$0")" && pwd)"

# rust/Cargo.toml
sed -i "s/^version = \".*\"/version = \"$VERSION\"/" "$ROOT/rust/Cargo.toml"

# qml/main.qml — About dialog
sed -i "s/Version [0-9.]*/Version $VERSION/" "$ROOT/qml/main.qml"

echo "Version updated to $VERSION in:"
echo "  rust/Cargo.toml"
echo "  qml/main.qml"
