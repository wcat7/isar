#!/usr/bin/env bash

set -e  # fail on error
set -x  # verbose mode

echo "=== Building WebAssembly ==="
rustup target add wasm32-unknown-unknown
cargo build --target wasm32-unknown-unknown --features sqlite --no-default-features -p isar --release

echo "=== Done ==="
echo "📦 Output: target/wasm32-unknown-unknown/release/isar.wasm"