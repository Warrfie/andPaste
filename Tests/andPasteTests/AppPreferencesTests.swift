import XCTest
@testable import andPasteCore

final class AppPreferencesTests: XCTestCase {
    private var directoryURL: URL!
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("andPaste-tests-\(UUID().uuidString)", isDirectory: true)
        fileURL = directoryURL.appendingPathComponent("preferences.plist")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directoryURL)
        fileURL = nil
        directoryURL = nil
        super.tearDown()
    }

    func testDefaultValues() {
        let preferences = AppPreferences(fileURL: fileURL)

        XCTAssertFalse(preferences.launchAtLogin)
        XCTAssertEqual(preferences.hotkeyShortcut, .fnV)
    }

    func testStoresLaunchAtLogin() {
        let preferences = AppPreferences(fileURL: fileURL)

        preferences.setLaunchAtLogin(true)

        XCTAssertTrue(preferences.launchAtLogin)
    }

    func testStoresHotkeyShortcut() {
        let preferences = AppPreferences(fileURL: fileURL)

        preferences.setHotkeyShortcut(.commandShiftV)

        XCTAssertEqual(preferences.hotkeyShortcut, .commandShiftV)
    }

    func testStoresPreferencesAsPlistFile() throws {
        let preferences = AppPreferences(fileURL: fileURL)

        preferences.setLaunchAtLogin(true)
        preferences.setHotkeyShortcut(.controlOptionV)

        let data = try Data(contentsOf: fileURL)
        let values = try PropertyListDecoder().decode(AppPreferences.Values.self, from: data)
        XCTAssertEqual(values, AppPreferences.Values(launchAtLogin: true, hotkeyShortcut: "controlOptionV"))
    }
}
