import Foundation

struct AppPreferences {
    struct Values: Codable, Equatable {
        var launchAtLogin = false
        var hotkeyShortcut = HotkeyShortcut.fnV.rawValue
    }

    private enum Key {
        static let fileName = "preferences.plist"
    }

    private let fileURL: URL
    private let fileManager: FileManager

    init(
        fileURL: URL = AppPreferences.defaultFileURL(),
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    var launchAtLogin: Bool {
        readValues().launchAtLogin
    }

    var hotkeyShortcut: HotkeyShortcut {
        HotkeyShortcut(rawValue: readValues().hotkeyShortcut) ?? .fnV
    }

    func setLaunchAtLogin(_ isEnabled: Bool) {
        updateValues { values in
            values.launchAtLogin = isEnabled
        }
    }

    func setHotkeyShortcut(_ shortcut: HotkeyShortcut) {
        updateValues { values in
            values.hotkeyShortcut = shortcut.rawValue
        }
    }

    private func readValues() -> Values {
        guard let data = try? Data(contentsOf: fileURL) else {
            return Values()
        }
        return (try? PropertyListDecoder().decode(Values.self, from: data)) ?? Values()
    }

    private func updateValues(_ update: (inout Values) -> Void) {
        var values = readValues()
        update(&values)

        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try PropertyListEncoder().encode(values)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            AppLog.write("Preferences save failed: \(error.localizedDescription)")
        }
    }

    private static func defaultFileURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL
            .appendingPathComponent("andPaste", isDirectory: true)
            .appendingPathComponent(Key.fileName)
    }
}
