#!/usr/bin/env bash

set -e  # fail on error
set -x  # verbose mode

export IPHONEOS_DEPLOYMENT_TARGET=12.0

# 0. Install required Rust targets
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios

# Detect SDK paths
SIM_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
DEV_SDK=$(xcrun --sdk iphoneos --show-sdk-path)

# Detect correct clang tools
SIM_CLANG=$(xcrun --sdk iphonesimulator -f clang)
SIM_AR=$(xcrun --sdk iphonesimulator -f ar)
DEV_CLANG=$(xcrun --sdk iphoneos -f clang)
DEV_AR=$(xcrun --sdk iphoneos -f ar)

echo "=== Building iOS Device (arm64) ==="
export CC="$DEV_CLANG"
export AR="$DEV_AR"
export CFLAGS="-target aarch64-apple-ios -isysroot $DEV_SDK"
export LDFLAGS="-isysroot $DEV_SDK"
cargo build --target aarch64-apple-ios --features sqlcipher --release

echo "=== Building iOS Simulator (arm64) ==="
export CC="$SIM_CLANG"
export AR="$SIM_AR"
export CFLAGS="-target arm64-apple-ios-simulator -isysroot $SIM_SDK"
export BINDGEN_EXTRA_CLANG_ARGS="-target arm64-apple-ios-simulator -isysroot $SIM_SDK"
export LDFLAGS="-isysroot $SIM_SDK"
cargo build --target aarch64-apple-ios-sim --features sqlcipher --release

echo "=== Building iOS Simulator (x86_64, optional) ==="
# Only needed if supporting Intel simulator
export CC="$SIM_CLANG"
export AR="$SIM_AR"
export CFLAGS="-target x86_64-apple-ios -isysroot $SIM_SDK"
cargo build --target x86_64-apple-ios --features sqlcipher --release

# Create universal simulator library
echo "=== Creating universal simulator binary ==="
mkdir -p target/universal-ios-sim
lipo \
    target/aarch64-apple-ios-sim/release/libisar.a \
    target/x86_64-apple-ios/release/libisar.a \
    -create -output target/universal-ios-sim/libisar.a


# Create XCFramework
echo "=== Building XCFramework ==="
FLUTTER_IOS_DIR="packages/isar_flutter_libs/ios"
rm -rf "$FLUTTER_IOS_DIR/isar.xcframework"
xcodebuild -create-xcframework \
    -library target/aarch64-apple-ios/release/libisar.a \
    -library target/universal-ios-sim/libisar.a \
    -output "$FLUTTER_IOS_DIR/isar.xcframework"

echo "=== Done ==="
echo "📦 Output: $FLUTTER_IOS_DIR/isar.xcframework"