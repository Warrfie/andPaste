import CryptoKit
import Foundation
import XCTest
@testable import CopyPasteCore

final class ClipboardHistoryEncryptionTests: XCTestCase {
    func testEncryptDecryptRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let plainData = Data(#"{"text":"secret clipboard value"}"#.utf8)

        let encryptedData = try ClipboardHistoryEncryption.encrypt(plainData, using: key)
        let decryptedData = try ClipboardHistoryEncryption.decrypt(encryptedData, using: key)

        XCTAssertEqual(decryptedData, plainData)
    }

    func testEncryptedPayloadDoesNotContainPlainText() throws {
        let key = SymmetricKey(size: .bits256)
        let secret = "secret clipboard value"
        let plainData = Data(#"{"text":"\#(secret)"}"#.utf8)

        let encryptedData = try ClipboardHistoryEncryption.encrypt(plainData, using: key)
        let encryptedString = String(decoding: encryptedData, as: UTF8.self)

        XCTAssertFalse(encryptedString.contains(secret))
    }
}
