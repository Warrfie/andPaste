# CopyPaste

Simple macOS clipboard history, close to Windows `Win+V`.

## Download

Download the latest signed DMG from the [latest GitHub release](https://github.com/Warrfie/CopyPaste/releases/latest).

1. Download `copypaste-<version>.dmg`.
2. Open the DMG and drag `CopyPaste.app` to `Applications`.
3. Launch CopyPaste from Applications.
4. Grant Accessibility access when macOS asks. CopyPaste needs it to paste selected history items into the app you were using.

If macOS warns that the app was downloaded from the internet, choose **Open**. Release DMGs are built from `v*` tags by GitHub Actions.

## Features

- `Fn + V` opens the history window. If macOS does not expose `Fn` as a hotkey modifier on your keyboard, the app falls back to `Control + Option + V`.
- Click any item to paste it into the app that was active before the history window opened.
- Text, images, file/folder URLs, web links, and file links are tracked while the app is running.
- Clipboard history is stored locally and encrypted before being written to disk.
- The app runs in the macOS App Sandbox.
- Files and folders are stored as file URLs, not copied into the history database.
- Images are stored as image data so previews survive app restarts.
- iPhone handoff works through Apple's Universal Clipboard: copy an item from history on the Mac, then paste on iPhone with Handoff enabled and the same Apple ID.
- The app uses an AppKit lifecycle with a native status item. SwiftUI renders the history/settings/about windows, with AppKit/Carbon bridges for macOS-only system APIs: global hotkeys, pasteboard access, window placement, and simulated `Command+V`.

## Privacy

CopyPaste does not send clipboard contents, images, file paths, settings, or usage data to external servers. See [docs/PRIVACY.md](docs/PRIVACY.md).

## Local Development

### Native Run

```sh
sh scripts/run-app.sh
```

This builds and opens `.build/CopyPaste.app` through LaunchServices, so the app runs as a native menu bar app instead of a console-launched executable.

### Build Only

```sh
sh scripts/build-app.sh
```

Avoid launching `.build/release/CopyPaste` directly. That is the raw SwiftPM executable and macOS treats it like a console program.

### Local Signing

For Accessibility permissions to persist between Xcode runs, Debug builds must be signed with a stable Apple Development identity. Create an ignored local config:

```sh
cp Config/Signing.local.xcconfig.example Config/Signing.local.xcconfig
```

Then replace `YOUR_TEAM_ID` with your Apple Developer Team ID. Without this file the app falls back to ad-hoc `Sign to Run Locally`, and macOS may ask for Accessibility access again after rebuilds.

### Tests

```sh
sh scripts/test.sh
```

The script creates a temporary SwiftPM manifest only for the test run, then removes it so Xcode does not show package targets.

### Release DMG

```sh
./scripts/build-dmg.sh
```

GitHub Actions builds CI on push/PR and creates DMG release artifacts from tags named `v*`. Signed and notarized release builds use repository secrets only; no Team ID, certificates, or App Store Connect credentials are stored in the repo.

See [docs/RELEASE.md](docs/RELEASE.md) for the release checklist.
