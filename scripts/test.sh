#!/bin/sh
set -eu

ROOT_DIR="$(pwd)"
SWIFTPM_CACHE_DIR="$ROOT_DIR/.build/swiftpm-cache"
SWIFTPM_SCRATCH_DIR="$ROOT_DIR/.build/swiftpm-scratch"
CLANG_CACHE_DIR="$ROOT_DIR/.build/clang-module-cache"
PACKAGE_BACKUP="$ROOT_DIR/.build/Package.swift.test-backup"

cleanup() {
  if [ -f "$PACKAGE_BACKUP" ]; then
    mv "$PACKAGE_BACKUP" Package.swift
  else
    rm -f Package.swift
  fi
}
trap cleanup EXIT INT TERM

mkdir -p "$ROOT_DIR/.build"
if [ -e Package.swift ]; then
  cp Package.swift "$PACKAGE_BACKUP"
fi

cat > Package.swift <<'SWIFTPM'
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
  --disable-sandbox \
  --cache-path "$SWIFTPM_CACHE_DIR" \
  --scratch-path "$SWIFTPM_SCRATCH_DIR" \
  --manifest-cache local \
  "$@"
