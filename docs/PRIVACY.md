# CopyPaste Privacy

CopyPaste stores clipboard history locally on your Mac. History is encrypted before it is written to disk.

The app does not send clipboard contents, images, file paths, settings, or usage data to external servers.

Clipboard history is stored at:

- Sandboxed app: `~/Library/Containers/com.warrfie.copypaste/Data/Library/Application Support/CopyPaste/history.cphistory`
- Older unsandboxed development builds: `~/Library/Application Support/CopyPaste/history.cphistory`

The encryption key is stored in the macOS Keychain as a generic password for CopyPaste. The key is marked device-local, so it is intended to stay on this Mac rather than migrate to another device.

Files and folders copied through Finder are stored as file URLs. CopyPaste does not copy the file contents into its history. Images are stored as image data so they can be previewed and restored after the app restarts.

You can clear non-pinned clipboard history from the menu. Pinned items remain until you unpin or remove them.
