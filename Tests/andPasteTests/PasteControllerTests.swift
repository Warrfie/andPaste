import XCTest
@testable import andPasteCore

final class PasteControllerTests: XCTestCase {
    func testCanPasteWhenPostEventAccessIsTrusted() {
        XCTAssertTrue(PasteController.canPaste(postEventTrusted: true, accessibilityTrusted: false))
    }

    func testCanPasteWhenAccessibilityIsTrustedEvenIfPostEventPreflightIsFalse() {
        XCTAssertTrue(PasteController.canPaste(postEventTrusted: false, accessibilityTrusted: true))
    }

    func testCannotPasteWithoutPostEventOrAccessibilityTrust() {
        XCTAssertFalse(PasteController.canPaste(postEventTrusted: false, accessibilityTrusted: false))
    }
}
