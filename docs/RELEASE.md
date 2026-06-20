# andPaste Release Checklist

## Download Link

Users should download the latest build from:

https://github.com/Warrfie/andPaste/releases/latest

Release assets are published from tags named `v*`. The DMG asset is named `andpaste-<tag>.dmg`.

## Before Tagging

Run:

```sh
sh scripts/test.sh
sh scripts/build-app.sh
```

For a local unsigned DMG smoke test:

```sh
./scripts/build-dmg.sh
```

For a Mac App Store / TestFlight export:

```sh
DEVELOPMENT_TEAM_VALUE=<APPLE_TEAM_ID> ./scripts/build-appstore.sh
```

## Publish

Create and push a version tag:

```sh
git tag v0.3
git push origin v0.3
```

GitHub Actions will run tests, build the DMG, sign/notarize when release secrets are available, and upload the DMG plus SHA256 file to the GitHub release.

## Post-Release Smoke Test

1. Open the latest release page.
2. Download the DMG.
3. Install `andPaste.app` into `Applications`.
4. Launch it and grant Accessibility access.
5. Copy text, an image, and a file/folder.
6. Open history with `Fn + V` and paste one item into another app.

## Mac App Store

Use [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) for App Store Connect prerequisites, export commands, metadata, privacy answers, and review notes.
