# Release Checklist

## Before Every Release

1. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`, or pass them into the release scripts.
2. Run tests:

   ```bash
   sh scripts/test.sh
   ```

3. Verify the app launches from a clean install and appears in the menu bar.
4. Verify Accessibility permission flow on first paste.
5. Verify text, image, file/folder, web link, and file link history items.
6. Verify encrypted history survives app restart.
7. Verify About includes the privacy policy link.

## Developer ID / Public DMG

Use this path for GitHub Releases and direct downloads:

```bash
SIGNING_ALLOWED=YES NOTARIZATION_ALLOWED=YES ./scripts/build-dmg.sh
```

Required secrets or local environment:

- Developer ID Application certificate
- Apple Developer Team ID
- App Store Connect API key with notarization access

The output DMG should be signed, notarized, stapled, and accompanied by a SHA-256 checksum.

## Mac App Store / TestFlight

Use this path for App Store Connect:

```bash
DEVELOPMENT_TEAM_VALUE=<APPLE_TEAM_ID> ./scripts/build-appstore.sh
```

If the machine needs Xcode to create or download signing assets automatically, use:

```bash
DEVELOPMENT_TEAM_VALUE=<APPLE_TEAM_ID> APPSTORE_ALLOW_PROVISIONING_UPDATES=YES ./scripts/build-appstore.sh
```

For CI-style authentication, also provide:

- `ASC_API_KEY_PATH`
- `ASC_API_KEY_ID`
- `ASC_API_ISSUER_ID`

Prerequisites:

- App Store Connect app record for bundle ID `com.warrfie.andpaste`
- Apple Distribution certificate
- Mac App Store Connect provisioning profile, or Xcode automatic signing access
- App Store Connect metadata, screenshots, privacy policy URL, and review notes

After export, upload the generated package with Xcode Organizer or Transporter.

## App Store Connect Metadata

Minimum metadata to prepare:

- App name: `andPaste`
- Category: Utilities
- Privacy policy URL: `https://github.com/Warrfie/andPaste/blob/main/docs/PRIVACY.md`
- Review notes: use `docs/APP_REVIEW_NOTES.md`
- Screenshots showing the menu bar item, history window with text/image/file rows, Settings, and Accessibility prompt flow

## Privacy Manifest

The app bundle includes `PrivacyInfo.xcprivacy` because andPaste uses `UserDefaults` for app-only preferences. The manifest declares:

- `NSPrivacyAccessedAPICategoryUserDefaults`
- reason `CA92.1`
- no tracking
- no collected data
