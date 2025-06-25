import Foundation
import CryptoKit

/// Handles encryption and decryption of the event queue
enum QueueEncryption {
    
    /// Generate a key for queue encryption (stored in Keychain)
    static func generateKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }
    
    /// Get or create the encryption key
    static func getOrCreateKey() -> SymmetricKey? {
        // Try to retrieve existing key from Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.luxardolabs.LuxAnalytics",
            kSecAttrAccount as String: "EncryptionKey",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let keyData = result as? Data {
            return SymmetricKey(data: keyData)
        }
        
        // Generate new key
        let newKey = generateKey()
        let keyData = newKey.withUnsafeBytes { Data($0) }
        
        // Store in Keychain
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.luxardolabs.LuxAnalytics",
            kSecAttrAccount as String: "EncryptionKey",
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return newKey
        }
        
        // If we can't store the key, encryption is not available
        return nil
    }
    
    /// Encrypt data
    static func encrypt(_ data: Data) -> Data? {
        guard let key = getOrCreateKey() else { return nil }
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined
        } catch {
            SecureLogger.log("Encryption failed: \(error)", category: .error, level: .error)
            return nil
        }
    }
    
    /// Decrypt data
    static func decrypt(_ data: Data) -> Data? {
        guard let key = getOrCreateKey() else { return nil }
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            SecureLogger.log("Decryption failed: \(error)", category: .error, level: .error)
            return nil
        }
    }
    
    /// Delete the encryption key (for testing or reset)
    static func deleteKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.luxardolabs.LuxAnalytics",
            kSecAttrAccount as String: "EncryptionKey"
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}