# CopyPaste

Simple macOS clipboard history, close to Windows `Win+V`.

- `Fn + V` opens the history window. If macOS does not expose `Fn` as a hotkey modifier on your keyboard, the app falls back to `Control + Option + V`.
- Click any item to paste it into the app that was active before the history window opened.
- Text, images, and file URLs are tracked while the app is running.
- iPhone handoff works through Apple's Universal Clipboard: copy an item from history on the Mac, then paste on iPhone with Handoff enabled and the same Apple ID.
- The app uses SwiftUI lifecycle, `MenuBarExtra`, and a SwiftUI history window. Small AppKit/Carbon bridges remain for macOS-only system APIs: global hotkeys, pasteboard access, window placement, and simulated `Command+V`.

## Native Run

```sh
sh scripts/run-app.sh
```

This builds and opens `.build/CopyPaste.app` through LaunchServices, so the app runs as a native menu bar app instead of a console-launched executable.

## Build Only

```sh
sh scripts/build-app.sh
```

Avoid launching `.build/release/CopyPaste` directly. That is the raw SwiftPM executable and macOS treats it like a console program.

## Release DMG

```sh
./scripts/build-dmg.sh
```

GitHub Actions builds CI on push/PR and creates DMG release artifacts from tags named `v*`. Signed and notarized release builds use repository secrets only; no Team ID, certificates, or App Store Connect credentials are stored in the repo.
