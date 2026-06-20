#!/bin/sh
set -eu

BUILD_DIR="$(pwd)/.build/app"
APP_DIR=".build/andPaste.app"
BUILT_APP="$BUILD_DIR/Build/Products/Release/andPaste.app"

xcodebuild \
  -project andPaste.xcodeproj \
  -scheme andPaste \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  build >&2

rm -rf "$APP_DIR"
mkdir -p ".build"
cp -R "$BUILT_APP" "$APP_DIR"

echo "$APP_DIR"
