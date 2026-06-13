#!/bin/zsh
set -euo pipefail

APP_NAME="${APP_NAME:-CopyPaste.app}"
DMG_BASENAME="${DMG_BASENAME:-copypaste-macos}"
VOLUME_NAME="${VOLUME_NAME:-CopyPaste}"
OUTPUT_DIR="${OUTPUT_DIR:-$PWD/build/artifacts}"
DMG_WINDOW_WIDTH="${DMG_WINDOW_WIDTH:-660}"
DMG_WINDOW_HEIGHT="${DMG_WINDOW_HEIGHT:-430}"
DMG_ICON_SIZE="${DMG_ICON_SIZE:-96}"
DMG_APP_ICON_X="${DMG_APP_ICON_X:-165}"
DMG_APP_ICON_Y="${DMG_APP_ICON_Y:-185}"
DMG_APPLICATIONS_ICON_X="${DMG_APPLICATIONS_ICON_X:-495}"
DMG_APPLICATIONS_ICON_Y="${DMG_APPLICATIONS_ICON_Y:-185}"
SIGNING_ALLOWED="${SIGNING_ALLOWED:-NO}"
NOTARIZATION_ALLOWED="${NOTARIZATION_ALLOWED:-NO}"
DMG_LAYOUT_REQUIRED="${DMG_LAYOUT_REQUIRED:-$SIGNING_ALLOWED}"
CODE_SIGN_IDENTITY_VALUE="${CODE_SIGN_IDENTITY_VALUE:-}"
DMG_CODE_SIGN_IDENTITY="${DMG_CODE_SIGN_IDENTITY:-$CODE_SIGN_IDENTITY_VALUE}"
KEYCHAIN_PATH="${KEYCHAIN_PATH:-}"
ASC_API_KEY_ID="${ASC_API_KEY_ID:-}"
ASC_API_ISSUER_ID="${ASC_API_ISSUER_ID:-}"
ASC_API_KEY_P8_BASE64="${ASC_API_KEY_P8_BASE64:-}"

STAGING_DIR="$OUTPUT_DIR/dmg-root"
DMG_MOUNT_ROOT="${DMG_MOUNT_ROOT:-/Volumes}"
EXPECTED_DMG_MOUNT_DIR="$DMG_MOUNT_ROOT/$VOLUME_NAME"
DMG_MOUNT_DIR=""
DMG_BACKGROUND_DIR="$STAGING_DIR/.background"
DMG_BACKGROUND_PATH="$DMG_BACKGROUND_DIR/background.png"
DMG_BACKGROUND_RENDERER="$PWD/scripts/render-dmg-background.swift"
DMG_SWIFT_MODULE_CACHE="$OUTPUT_DIR/swift-module-cache"
DMG_PATH="$OUTPUT_DIR/$DMG_BASENAME.dmg"
DMG_RW_PATH="$OUTPUT_DIR/$DMG_BASENAME-rw.dmg"
SHA_PATH="$OUTPUT_DIR/$DMG_BASENAME.sha256"
NOTARY_RESULT_PATH="$OUTPUT_DIR/$DMG_BASENAME.notary.json"
NOTARY_KEY_PATH=""
ATTACHED_DMG=""

cleanup() {
  if [[ -n "$ATTACHED_DMG" ]]; then
    hdiutil detach "$ATTACHED_DMG" -quiet || true
  fi
  if [[ -n "$NOTARY_KEY_PATH" ]]; then
    rm -f "$NOTARY_KEY_PATH"
  fi
}
trap cleanup EXIT

resolve_developer_id_identity() {
  if [[ -z "$KEYCHAIN_PATH" ]]; then
    echo "KEYCHAIN_PATH is required when code signing identity is AUTO" >&2
    exit 1
  fi
  security find-identity -v -p codesigning "$KEYCHAIN_PATH" \
    | sed -n 's/.*"\(Developer ID Application: .*\)".*/\1/p' \
    | head -n 1
}

handle_dmg_layout_failure() {
  local message="$1"

  if [[ "$DMG_LAYOUT_REQUIRED" == "YES" ]]; then
    echo "$message" >&2
    echo "DMG Finder layout is required for this build. Set DMG_LAYOUT_REQUIRED=NO only for local/dev packaging." >&2
    exit 1
  fi

  echo "Warning: $message; continuing with default layout." >&2
}

prepare_dmg_mountpoint() {
  if [[ -e "$EXPECTED_DMG_MOUNT_DIR" ]]; then
    echo "DMG mountpoint already exists: $EXPECTED_DMG_MOUNT_DIR" >&2
    echo "Unmount the existing '$VOLUME_NAME' volume first, or set DMG_MOUNT_ROOT to another path." >&2
    exit 1
  fi
}

mkdir -p "$OUTPUT_DIR"

APP_PATH="$(sh scripts/build-app.sh)"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app bundle not found at $APP_PATH" >&2
  exit 1
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
mkdir -p "$DMG_BACKGROUND_DIR"
ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME"
ln -s /Applications "$STAGING_DIR/Applications"

if [[ ! -f "$DMG_BACKGROUND_RENDERER" ]]; then
  echo "Expected DMG background renderer not found at $DMG_BACKGROUND_RENDERER" >&2
  exit 1
fi
mkdir -p "$DMG_SWIFT_MODULE_CACHE"
swift -module-cache-path "$DMG_SWIFT_MODULE_CACHE" "$DMG_BACKGROUND_RENDERER" "$DMG_BACKGROUND_PATH"

if [[ "$SIGNING_ALLOWED" == "YES" ]]; then
  if [[ -z "$CODE_SIGN_IDENTITY_VALUE" || "$CODE_SIGN_IDENTITY_VALUE" == "AUTO" ]]; then
    CODE_SIGN_IDENTITY_VALUE="$(resolve_developer_id_identity)"
  fi
  if [[ -z "$DMG_CODE_SIGN_IDENTITY" || "$DMG_CODE_SIGN_IDENTITY" == "AUTO" ]]; then
    DMG_CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY_VALUE"
  fi
  : "${CODE_SIGN_IDENTITY_VALUE:?Set CODE_SIGN_IDENTITY_VALUE for signed builds}"

  APP_CODESIGN_ARGS=(
    --force
    --timestamp
    --options runtime
    --sign "$CODE_SIGN_IDENTITY_VALUE"
  )
  if [[ -n "$KEYCHAIN_PATH" ]]; then
    APP_CODESIGN_ARGS+=(--keychain "$KEYCHAIN_PATH")
  fi
  codesign "${APP_CODESIGN_ARGS[@]}" "$STAGING_DIR/$APP_NAME"
fi

rm -f "$DMG_PATH" "$DMG_RW_PATH" "$SHA_PATH" "$NOTARY_RESULT_PATH"
prepare_dmg_mountpoint
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDRW \
  -fs HFS+ \
  "$DMG_RW_PATH" \
  -quiet

ATTACH_OUTPUT="$(hdiutil attach "$DMG_RW_PATH" \
  -readwrite \
  -noautoopen \
  -mountroot "$DMG_MOUNT_ROOT")"
DMG_MOUNT_DIR="$(printf '%s\n' "$ATTACH_OUTPUT" | awk '/Apple_HFS/ {print $NF; exit}')"
if [[ -z "$DMG_MOUNT_DIR" || ! -d "$DMG_MOUNT_DIR" ]]; then
  echo "Failed to resolve DMG mountpoint from hdiutil output:" >&2
  printf '%s\n' "$ATTACH_OUTPUT" >&2
  exit 1
fi
ATTACHED_DMG="$DMG_MOUNT_DIR"

if command -v SetFile >/dev/null 2>&1; then
  SetFile -a V "$DMG_MOUNT_DIR/.background" || true
fi

if command -v osascript >/dev/null 2>&1; then
  if ! osascript <<APPLESCRIPT
set mountedFolder to POSIX file "$DMG_MOUNT_DIR" as alias
set backgroundImage to POSIX file "$DMG_MOUNT_DIR/.background/background.png" as alias

tell application "Finder"
  tell folder mountedFolder
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {120, 120, 120 + $DMG_WINDOW_WIDTH, 120 + $DMG_WINDOW_HEIGHT}

    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to $DMG_ICON_SIZE
    set label position of theViewOptions to bottom
    set text size of theViewOptions to 12
    set background picture of theViewOptions to backgroundImage

    set position of item "$APP_NAME" of container window to {$DMG_APP_ICON_X, $DMG_APP_ICON_Y}
    set position of item "Applications" of container window to {$DMG_APPLICATIONS_ICON_X, $DMG_APPLICATIONS_ICON_Y}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
APPLESCRIPT
  then
    handle_dmg_layout_failure "failed to apply Finder DMG layout"
  fi
else
  handle_dmg_layout_failure "osascript is unavailable; skipping Finder DMG layout"
fi

rm -rf "$DMG_MOUNT_DIR/.fseventsd" "$DMG_MOUNT_DIR/.Spotlight-V100" "$DMG_MOUNT_DIR/.Trashes"
bless --folder "$DMG_MOUNT_DIR" --openfolder "$DMG_MOUNT_DIR" 2>/dev/null || true
sync
hdiutil detach "$DMG_MOUNT_DIR" -quiet
ATTACHED_DMG=""

hdiutil convert "$DMG_RW_PATH" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH" \
  -quiet
rm -f "$DMG_RW_PATH"

if [[ "$SIGNING_ALLOWED" == "YES" && -n "$DMG_CODE_SIGN_IDENTITY" ]]; then
  DMG_CODESIGN_ARGS=(
    --force
    --timestamp
    --sign "$DMG_CODE_SIGN_IDENTITY"
  )
  if [[ -n "$KEYCHAIN_PATH" ]]; then
    DMG_CODESIGN_ARGS+=(--keychain "$KEYCHAIN_PATH")
  fi
  codesign "${DMG_CODESIGN_ARGS[@]}" "$DMG_PATH"
fi

if [[ "$NOTARIZATION_ALLOWED" == "YES" ]]; then
  if [[ "$SIGNING_ALLOWED" != "YES" ]]; then
    echo "NOTARIZATION_ALLOWED=YES requires SIGNING_ALLOWED=YES" >&2
    exit 1
  fi
  : "${ASC_API_KEY_ID:?Set ASC_API_KEY_ID for notarization}"
  : "${ASC_API_ISSUER_ID:?Set ASC_API_ISSUER_ID for notarization}"
  : "${ASC_API_KEY_P8_BASE64:?Set ASC_API_KEY_P8_BASE64 for notarization}"

  umask 077
  NOTARY_KEY_PATH="$(mktemp "${TMPDIR:-/tmp}/copypaste-notary-key.XXXXXX")"
  printf '%s' "$ASC_API_KEY_P8_BASE64" | base64 --decode > "$NOTARY_KEY_PATH"

  xcrun notarytool submit "$DMG_PATH" \
    --key "$NOTARY_KEY_PATH" \
    --key-id "$ASC_API_KEY_ID" \
    --issuer "$ASC_API_ISSUER_ID" \
    --wait \
    --output-format json \
    | tee "$NOTARY_RESULT_PATH"

  NOTARY_STATUS="$(/usr/bin/plutil -extract status raw -o - "$NOTARY_RESULT_PATH")"
  NOTARY_ID="$(/usr/bin/plutil -extract id raw -o - "$NOTARY_RESULT_PATH")"

  if [[ "$NOTARY_STATUS" != "Accepted" ]]; then
    echo "Notarization failed with status: $NOTARY_STATUS" >&2
    if [[ -n "$NOTARY_ID" ]]; then
      xcrun notarytool log "$NOTARY_ID" \
        --key "$NOTARY_KEY_PATH" \
        --key-id "$ASC_API_KEY_ID" \
        --issuer "$ASC_API_ISSUER_ID" || true
    fi
    exit 1
  fi

  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --type open --verbose "$DMG_PATH" || {
    echo "Gatekeeper assessment did not pass in CI; notarization and stapler validation succeeded." >&2
  }
fi

shasum -a 256 "$DMG_PATH" > "$SHA_PATH"

echo
echo "Created artifacts:"
echo "  $DMG_PATH"
echo "  $SHA_PATH"
