#!/usr/bin/env bash

set -e  # fail on error
set -x  # verbose mode

# Auto-detect Android NDK
if [[ -n "$ANDROID_NDK_HOME" && -d "$ANDROID_NDK_HOME" ]]; then
    NDK="$ANDROID_NDK_HOME"
elif [[ -n "$ANDROID_SDK_ROOT" && -d "$ANDROID_SDK_ROOT/ndk" ]]; then
    NDK=$(ls -d "$ANDROID_SDK_ROOT/ndk/"* | sort -V | tail -n 1)
elif [[ -d "$HOME/Library/Android/sdk/ndk" ]]; then
    NDK=$(ls -d "$HOME/Library/Android/sdk/ndk/"* | sort -V | tail -n 1)
else
    echo "❌ Android NDK not found. Install via Android Studio > SDK Manager."
    exit 1
fi

# Required by isar build.rs
export ANDROID_NDK_HOME="$NDK"

# Detect host system
case "$(uname -s)" in
    Darwin) HOST_TAG="darwin-x86_64" ;;
    Linux)  HOST_TAG="linux-x86_64" ;;
    *) echo "❌ Unsupported OS"; exit 1 ;;
esac

TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$HOST_TAG/bin"
export PATH="$TOOLCHAIN:$PATH"

# Build arm64-v8a only
echo "=== Building Android (arm64-v8a) ==="
TARGET="aarch64-linux-android"
API=21

export CC="$TOOLCHAIN/${TARGET}${API}-clang"
export AR="$TOOLCHAIN/llvm-ar"

# Normalize env key
TARGET_ENV=$(echo "$TARGET" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
export CARGO_TARGET_${TARGET_ENV}_LINKER="$CC"
export CARGO_TARGET_${TARGET_ENV}_AR="$AR"

# Required for bindgen/mdbx
export BINDGEN_EXTRA_CLANG_ARGS="--sysroot=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$HOST_TAG/sysroot"

rustup target add "$TARGET"

# Clean previous build to ensure fresh compilation
echo "=== Cleaning previous build ==="
cargo clean --target "$TARGET"

# Build
echo "=== Compiling ==="
cargo build --target "$TARGET" --release --features sqlcipher-vendored

# Copy to Flutter plugin final location (overwrite if exists)
FLUTTER_ANDROID_DIR="packages/isar_flutter_libs/android/src/main/jniLibs/arm64-v8a"
mkdir -p "$FLUTTER_ANDROID_DIR"
cp -f "target/$TARGET/release/libisar.so" "$FLUTTER_ANDROID_DIR/libisar.so"

echo "=== Done ==="
echo "📦 Output: $FLUTTER_ANDROID_DIR/libisar.so"