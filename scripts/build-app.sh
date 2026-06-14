#!/bin/sh
set -eu

BUILD_DIR="$(pwd)/.build/app"
APP_DIR=".build/CopyPaste.app"
BUILT_APP="$BUILD_DIR/Build/Products/Release/CopyPaste.app"

xcodebuild \
  -project CopyPaste.xcodeproj \
  -scheme CopyPaste \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY=- \
  build >&2

rm -rf "$APP_DIR"
mkdir -p ".build"
cp -R "$BUILT_APP" "$APP_DIR"

echo "$APP_DIR"
