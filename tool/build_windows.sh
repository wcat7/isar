#!/usr/bin/env bash

set -e  # fail on error
set -x  # verbose mode

FLUTTER_WINDOWS_DIR="packages/isar_flutter_libs/windows"

if [ "$1" = "x64" ]; then
    echo "=== Building Windows (x86_64) ==="
    rustup target add x86_64-pc-windows-msvc
    cargo build --target x86_64-pc-windows-msvc --features sqlcipher-vendored --release
    
    # Copy to Flutter plugin final location
    cp "target/x86_64-pc-windows-msvc/release/isar.dll" "$FLUTTER_WINDOWS_DIR/isar.dll"
    
    echo "=== Done ==="
    echo "📦 Output: $FLUTTER_WINDOWS_DIR/isar.dll"
else
    echo "=== Building Windows (arm64) ==="
    rustup target add aarch64-pc-windows-msvc
    cargo build --target aarch64-pc-windows-msvc --features sqlcipher-vendored --release
    
    # Copy to Flutter plugin final location
    cp "target/aarch64-pc-windows-msvc/release/isar.dll" "$FLUTTER_WINDOWS_DIR/isar.dll"
    
    echo "=== Done ==="
    echo "📦 Output: $FLUTTER_WINDOWS_DIR/isar.dll"
fi