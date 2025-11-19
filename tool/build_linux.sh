#!/usr/bin/env bash

set -e  # fail on error
set -x  # verbose mode

FLUTTER_LINUX_DIR="packages/isar_flutter_libs/linux"

if [ "$1" = "x64" ]; then
    echo "=== Building Linux (x86_64) ==="
    rustup target add x86_64-unknown-linux-gnu
    cargo build --target x86_64-unknown-linux-gnu --features sqlcipher-vendored --release
    
    # Copy to Flutter plugin final location
    cp "target/x86_64-unknown-linux-gnu/release/libisar.so" "$FLUTTER_LINUX_DIR/libisar.so"
    
    echo "=== Done ==="
    echo "📦 Output: $FLUTTER_LINUX_DIR/libisar.so"
else
    echo "=== Building Linux (arm64) ==="
    rustup target add aarch64-unknown-linux-gnu
    cargo build --target aarch64-unknown-linux-gnu --features sqlcipher-vendored --release
    
    # Copy to Flutter plugin final location
    cp "target/aarch64-unknown-linux-gnu/release/libisar.so" "$FLUTTER_LINUX_DIR/libisar.so"
    
    echo "=== Done ==="
    echo "📦 Output: $FLUTTER_LINUX_DIR/libisar.so"
fi
