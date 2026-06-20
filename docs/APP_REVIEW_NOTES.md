# App Review Notes

Use this text in App Store Connect Review Notes.

```text
andPaste is a menu bar-only macOS clipboard history utility. After launch, the app appears in the macOS menu bar and does not show a Dock icon.

How to review the core flow:

1. Launch andPaste.
2. Copy text in any app.
3. Open clipboard history with Fn+V, or Control+Option+V if Fn is unavailable as a hotkey modifier on the review keyboard.
4. Select the copied item in the history window.
5. Grant Accessibility access if macOS prompts for it.
6. andPaste activates the previously used app and simulates Command+V to paste the selected item.
7. Repeat with an image and a file/folder copied from Finder to verify preview and file URL handling.

Privacy-sensitive behavior:

- Clipboard history is stored locally on the Mac.
- History is encrypted before it is written to disk.
- Files and folders are stored as file URLs; andPaste does not copy file contents into its history.
- Images are stored locally as image data so previews survive app restarts.
- Accessibility access is used only to paste the selected history item into the active app.
- The app does not upload clipboard contents, images, file paths, settings, diagnostics, analytics, or usage data to a server.

No login, account, subscription, in-app purchase, or external service is required.
```

## App Store Connect Privacy Answers

Use these answers as the basis for App Privacy metadata:

- Tracking: No.
- Third-party advertising: No.
- Analytics collection: No.
- Data linked to user: No.
- Data used to track user: No.
- User content: The app processes clipboard contents locally only. Do not mark this as collected unless App Store Connect asks about local-only processing separately.
- Files and folders: The app stores copied Finder items as local file URLs only. It does not upload file paths or file contents.

The public privacy policy URL should point to:

```text
https://github.com/Warrfie/andPaste/blob/main/docs/PRIVACY.md
```
