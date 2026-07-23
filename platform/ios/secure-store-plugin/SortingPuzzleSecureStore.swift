import Foundation
import Security

@objcMembers
public final class SortingPuzzleSecureStore: NSObject {
    public static let shared = SortingPuzzleSecureStore()

    private let service = "com.sortingpuzzle.securestore"
    private let signatureDomain = Data("sorting-puzzle:save-operation:2\0".utf8)

    public func ensureInstallationKey(_ installationID: String) -> Bool {
        guard isUUID(installationID) else { return false }
        if privateKey(installationID) != nil { return true }

        let tag = signingTag(installationID)
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            ],
        ]
        var error: Unmanaged<CFError>?
        return SecKeyCreateRandomKey(attributes as CFDictionary, &error) != nil
    }

    public func installationPublicKeyDER(_ installationID: String) -> String {
        guard
            ensureInstallationKey(installationID),
            let privateKey = privateKey(installationID),
            let publicKey = SecKeyCopyPublicKey(privateKey),
            let raw = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?
        else { return "" }

        // SubjectPublicKeyInfo prefix for id-ecPublicKey + prime256v1, followed by X9.63 point.
        let spkiPrefix = Data([
            0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d,
            0x02, 0x01, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01,
            0x07, 0x03, 0x42, 0x00,
        ])
        return (spkiPrefix + raw).base64EncodedString()
    }

    public func setInstallationID(_ installationID: String) -> Bool {
        guard ensureInstallationKey(installationID) else { return false }
        return storeSecret(account: "installation_id", data: Data(installationID.utf8))
    }

    public func signSaveOperationHash(_ operationHash: String) -> String {
        guard
            operationHash.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil,
            let installationData = loadSecret(account: "installation_id"),
            let installationID = String(data: installationData, encoding: .utf8),
            let key = privateKey(installationID)
        else { return "" }

        let message = signatureDomain + Data(operationHash.utf8)
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            key,
            .ecdsaSignatureMessageX962SHA256,
            message as CFData,
            &error
        ) as Data? else { return "" }
        return signature.base64EncodedString()
    }

    public func signInstallationPayload(_ payload: String) -> String {
        guard
            !payload.isEmpty,
            let installationData = loadSecret(account: "installation_id"),
            let installationID = String(data: installationData, encoding: .utf8),
            let key = privateKey(installationID)
        else { return "" }

        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            key,
            .ecdsaSignatureMessageX962SHA256,
            Data(payload.utf8) as CFData,
            &error
        ) as Data? else { return "" }
        return signature.base64EncodedString()
    }

    public func storePlayerSession(_ playerID: String, sessionJSON: String) -> Bool {
        guard isUUID(playerID), !sessionJSON.isEmpty else { return false }
        return storeSecret(
            account: sessionAccount(playerID),
            data: Data(sessionJSON.utf8)
        )
    }

    public func loadPlayerSession(_ playerID: String) -> String {
        guard
            isUUID(playerID),
            let data = loadSecret(account: sessionAccount(playerID))
        else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    public func clearPlayerSession(_ playerID: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: sessionAccount(playerID),
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private func privateKey(_ installationID: String) -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: signingTag(installationID),
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return (result as! SecKey)
    }

    private func storeSecret(account: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let update: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }
        var insertion = query
        insertion.merge(update) { _, new in new }
        return SecItemAdd(insertion as CFDictionary, nil) == errSecSuccess
    }

    private func loadSecret(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    private func signingTag(_ installationID: String) -> Data {
        Data("com.sortingpuzzle.signing.\(installationID)".utf8)
    }

    private func sessionAccount(_ playerID: String) -> String {
        "player_session.\(playerID)"
    }

    private func isUUID(_ value: String) -> Bool {
        UUID(uuidString: value) != nil && value == value.lowercased()
    }
}
