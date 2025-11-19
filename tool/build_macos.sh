#!/usr/bin/env bash

set -e  # fail on error
set -x  # verbose mode

export MACOSX_DEPLOYMENT_TARGET=10.11

FLUTTER_MACOS_DIR="packages/isar_flutter_libs/macos"

# Install required Rust targets
rustup target add aarch64-apple-darwin x86_64-apple-darwin

echo "=== Building macOS (arm64) ==="
cargo build --target aarch64-apple-darwin --features sqlcipher --release

echo "=== Building macOS (x86_64) ==="
cargo build --target x86_64-apple-darwin --features sqlcipher --release

echo "=== Creating universal binary ==="
lipo \
    target/aarch64-apple-darwin/release/libisar.dylib \
    target/x86_64-apple-darwin/release/libisar.dylib \
    -create -output "$FLUTTER_MACOS_DIR/libisar.dylib"
install_name_tool -id @rpath/libisar.dylib "$FLUTTER_MACOS_DIR/libisar.dylib"

echo "=== Done ==="
echo "📦 Output: $FLUTTER_MACOS_DIR/libisar.dylib"