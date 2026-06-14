#!/bin/sh
set -eu

ROOT_DIR="$(pwd)"
SWIFTPM_CACHE_DIR="$ROOT_DIR/.build/swiftpm-cache"
SWIFTPM_SCRATCH_DIR="$ROOT_DIR/.build/swiftpm-scratch"
CLANG_CACHE_DIR="$ROOT_DIR/.build/clang-module-cache"
PACKAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/copypaste-tests.XXXXXX")"

cleanup() {
  rm -rf "$PACKAGE_DIR"
}
trap cleanup EXIT INT TERM

mkdir -p "$ROOT_DIR/.build"

ln -s "$ROOT_DIR/Sources" "$PACKAGE_DIR/Sources"
ln -s "$ROOT_DIR/Tests" "$PACKAGE_DIR/Tests"

cat > "$PACKAGE_DIR/Package.swift" <<'SWIFTPM'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CopyPasteTests",
    platforms: [
        .macOS(.v13)
    ],
    products: [],
    targets: [
        .target(
            name: "CopyPasteCore",
            path: "Sources/CopyPaste"
        ),
        .testTarget(
            name: "CopyPasteTests",
            dependencies: ["CopyPasteCore"],
            path: "Tests/CopyPasteTests"
        )
    ]
)
SWIFTPM

mkdir -p "$SWIFTPM_CACHE_DIR" "$SWIFTPM_SCRATCH_DIR" "$CLANG_CACHE_DIR"
export CLANG_MODULE_CACHE_PATH="$CLANG_CACHE_DIR"

swift test \
  --package-path "$PACKAGE_DIR" \
  --disable-sandbox \
  --cache-path "$SWIFTPM_CACHE_DIR" \
  --scratch-path "$SWIFTPM_SCRATCH_DIR" \
  --manifest-cache local \
  "$@"
