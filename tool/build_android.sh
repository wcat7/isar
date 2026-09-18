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
elif [[ -d "/opt/homebrew/share/android-commandlinetools/ndk" ]]; then
    # Homebrew's android-commandlinetools, which is where the SDK lives on a
    # machine that never installed Android Studio.
    NDK=$(ls -d /opt/homebrew/share/android-commandlinetools/ndk/* | sort -V | tail -n 1)
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

# isar-core declares #![feature(...)], which the stable channel rejects
# outright. Named here rather than left to whatever `rustup default` happens to
# be, because the failure is a compile error 90 seconds in, not a clear one.
TOOLCHAIN_NAME=nightly
rustup toolchain list | grep -q "^$TOOLCHAIN_NAME" || rustup toolchain install "$TOOLCHAIN_NAME"

# Every ABI the Flutter plugin ships. They are committed binaries, so one that
# is not rebuilt here keeps whatever it was built with years ago — which is how
# x86_64 stayed linked for 4 KB pages while arm64 was fixed.
API=21
build() {
    local TARGET="$1" ABI="$2" CLANG="$3"
    echo "=== Building $ABI ($TARGET) ==="

    # The NDK's wrapper is usually named after the target triple, but not for
    # 32-bit arm: rust says armv7-linux-androideabi, the NDK ships
    # armv7a-linux-androideabi21-clang. Hence the separate argument.
    export CC="$TOOLCHAIN/${CLANG}${API}-clang"
    export AR="$TOOLCHAIN/llvm-ar"

    # Normalize env key
    TARGET_ENV=$(echo "$TARGET" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
    export CARGO_TARGET_${TARGET_ENV}_LINKER="$CC"
    export CARGO_TARGET_${TARGET_ENV}_AR="$AR"

    # Required for bindgen/mdbx
    export BINDGEN_EXTRA_CLANG_ARGS="--sysroot=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$HOST_TAG/sysroot"

    # rustc resolves clang_rt.builtins-<arch>-android itself for the x86
    # targets and does not find it without being told where the NDK keeps it.
    # aarch64 happens not to need this, which is why building only arm64 hid it.
    local RT
    RT=$(dirname "$(find "$TOOLCHAIN/../lib/clang" -name 'libclang_rt.builtins-*-android.a' | head -n 1)")

    # Android 15 runs 64-bit devices on 16 KB memory pages, and Play requires
    # the alignment from 2027-02-01. NDK r28 links that way by default, but
    # these binaries are committed and outlive the toolchain that produced
    # them, so the flag is explicit. Set here rather than in a .cargo/config
    # file: cargo reads those from the working directory upward, so one sitting
    # in a package subdirectory is silently never read.
    local FLAGS=("-C" "link-arg=-Wl,--hash-style=both" "-L" "$RT")
    case "$TARGET" in
        aarch64-*|x86_64-*) FLAGS+=("-C" "link-arg=-Wl,-z,max-page-size=16384") ;;
    esac
    # Encoded rather than space-separated, so an NDK path with a space in it
    # does not turn into two flags.
    export CARGO_ENCODED_RUSTFLAGS
    CARGO_ENCODED_RUSTFLAGS=$(printf '%s\x1f' "${FLAGS[@]}")
    CARGO_ENCODED_RUSTFLAGS=${CARGO_ENCODED_RUSTFLAGS%$'\x1f'}

    rustup target add --toolchain "$TOOLCHAIN_NAME" "$TARGET"

    # Clean previous build to ensure fresh compilation
    cargo "+$TOOLCHAIN_NAME" clean --target "$TARGET"
    cargo "+$TOOLCHAIN_NAME" build --target "$TARGET" --release --features sqlcipher-vendored

    # Copy to Flutter plugin final location (overwrite if exists)
    local OUT="packages/isar_flutter_libs/android/src/main/jniLibs/$ABI"
    mkdir -p "$OUT"
    cp -f "target/$TARGET/release/libisar.so" "$OUT/libisar.so"
    echo "📦 $OUT/libisar.so"
}

# armv7 is here for completeness; 32-bit has no 16 KB devices to align for.
# Named ABIs can be passed as arguments to rebuild just those.
WANTED=("$@")
wanted() {
    [ ${#WANTED[@]} -eq 0 ] && return 0
    local a
    for a in "${WANTED[@]}"; do [ "$a" = "$1" ] && return 0; done
    return 1
}
if wanted arm64-v8a;   then build aarch64-linux-android   arm64-v8a   aarch64-linux-android; fi
if wanted x86_64;      then build x86_64-linux-android    x86_64      x86_64-linux-android; fi
if wanted armeabi-v7a; then build armv7-linux-androideabi armeabi-v7a armv7a-linux-androideabi; fi

echo "=== Done ==="
