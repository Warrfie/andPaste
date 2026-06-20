import CryptoKit
import Foundation
import Security

enum ClipboardHistoryEncryption {
    private static let magic = Data("andPasteHistory.v1\n".utf8)

    static func encrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw ClipboardHistoryEncryptionError.unableToCombineSealedBox
        }
        return magic + combined
    }

    static func decrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        guard data.starts(with: magic) else {
            throw ClipboardHistoryEncryptionError.invalidHeader
        }
        let combined = data.dropFirst(magic.count)
        let sealedBox = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(sealedBox, using: key)
    }
}

enum ClipboardHistoryEncryptionError: Error {
    case invalidHeader
    case unableToCombineSealedBox
    case keychainReadFailed(OSStatus)
    case keychainWriteFailed(OSStatus)
}

enum ClipboardHistoryKeychain {
    private static let service = "com.warrfie.andPaste.clipboard-history"
    private static let account = "history-encryption-key"
    private static let keyByteCount = 32

    static func loadOrCreateKey() throws -> SymmetricKey {
        if let existingKey = try loadKey() {
            return existingKey
        }

        var keyData = Data(count: keyByteCount)
        let status = keyData.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return errSecParam
            }
            return SecRandomCopyBytes(kSecRandomDefault, keyByteCount, baseAddress)
        }
        guard status == errSecSuccess else {
            throw ClipboardHistoryEncryptionError.keychainWriteFailed(status)
        }

        try saveKeyData(keyData)
        return SymmetricKey(data: keyData)
    }

    private static func loadKey() throws -> SymmetricKey? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw ClipboardHistoryEncryptionError.keychainReadFailed(status)
        }
        return SymmetricKey(data: data)
    }

    private static func saveKeyData(_ data: Data) throws {
        var query = baseQuery()
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw ClipboardHistoryEncryptionError.keychainWriteFailed(status)
        }
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
