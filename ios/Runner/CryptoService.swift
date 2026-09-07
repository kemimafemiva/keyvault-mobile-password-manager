//
//  CryptoService.swift
//  Runner
//
//  Created by Oluwakemi Mafe on 2026-08-16.
//

import Foundation
import CryptoKit
import Security
import LocalAuthentication

protocol CryptoServicing {
    func unlockSession() throws

    func lockSession()

    func renewSession()

    func encrypt(
        _ plainText: String
    ) throws -> [String: Any]

    func decrypt(
        cipherText: [UInt8],
        nonce: [UInt8],
        mac: [UInt8]
    ) throws -> String

    func deleteKey() throws
}

final class CryptoService: CryptoServicing {
    private static let authenticationValidityInterval: TimeInterval = 300

    private let requireAuthentication: Bool
    private let currentDate: () -> Date
    private let service: String
    private let account: String

    private var sessionKey: SymmetricKey?
    private var sessionAuthenticatedAt: Date?

    private var isSessionValid: Bool {
        guard sessionKey != nil, let sessionAuthenticatedAt else {
            return false
        }

        return currentDate().timeIntervalSince(sessionAuthenticatedAt)
            < Self.authenticationValidityInterval
    }

    init(
        requireAuthentication: Bool = true,
        currentDate: @escaping () -> Date = Date.init,
        service: String = "com.oluwakemimafe.keyvault",
        account: String = "vault-encryption-key"
    ) {
        self.requireAuthentication = requireAuthentication
        self.currentDate = currentDate
        self.service = service
        self.account = account
    }

    // MARK: - Encryption

    func encrypt(
        _ plainText: String
    ) throws -> [String: Any] {
        let key = try getSessionKey()

        let data = Data(plainText.utf8)

        let sealedBox = try AES.GCM.seal(
            data,
            using: key
        )

        guard let nonceData = sealedBox.nonce.withUnsafeBytes({
            Data($0)
        }) as Data? else {
            throw CryptoServiceError.encryptionFailed
        }

        return [
            "cipherText": Array(sealedBox.ciphertext),
            "nonce": Array(nonceData),
            "mac": Array(sealedBox.tag)
        ]
    }

    // MARK: - Decryption

    func decrypt(
        cipherText: [UInt8],
        nonce: [UInt8],
        mac: [UInt8]
    ) throws -> String {
        let key = try getSessionKey()

        let sealedBox = try AES.GCM.SealedBox(
            nonce: AES.GCM.Nonce(
                data: Data(nonce)
            ),
            ciphertext: Data(cipherText),
            tag: Data(mac)
        )

        let decryptedData = try AES.GCM.open(
            sealedBox,
            using: key
        )

        guard let plainText = String(
            data: decryptedData,
            encoding: .utf8
        ) else {
            throw CryptoServiceError.decryptionFailed
        }

        return plainText
    }

    // MARK: - Session Management

    func unlockSession() throws {
        if sessionKey != nil && isSessionValid {
            return
        }

        lockSession()
        sessionKey = try getOrCreateKey()
        sessionAuthenticatedAt = currentDate()
    }

    func renewSession() {
        guard sessionKey != nil else {
            return
        }
        sessionAuthenticatedAt = currentDate()
    }

    func lockSession() {
        sessionKey = nil
        sessionAuthenticatedAt = nil
    }

    private func getSessionKey() throws -> SymmetricKey {
        guard let sessionKey, isSessionValid else {
            lockSession()
            throw CryptoServiceError.authenticationRequired
        }

        return sessionKey
    }

    // MARK: - Key Management

    private func getOrCreateKey() throws -> SymmetricKey {
        do {
            return try getExistingKey()
        } catch CryptoServiceError.keyNotFound {
            _ = try createKey()
            return try getExistingKey()
        }
    }

    private func getExistingKey() throws -> SymmetricKey {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if requireAuthentication {
            let context = LAContext()

            context.localizedReason =
                "Authenticate to access your KeyVault encryption key."

            query[kSecUseAuthenticationContext as String] =
                context
        }

        var result: CFTypeRef?

        let status = SecItemCopyMatching(
            query as CFDictionary,
            &result
        )

        if status == errSecItemNotFound {
            throw CryptoServiceError.keyNotFound
        }

        if status == errSecUserCanceled ||
            status == errSecAuthFailed ||
            status == errSecInteractionNotAllowed {
            throw CryptoServiceError.authenticationRequired
        }

        guard status == errSecSuccess else {
            throw CryptoServiceError.keychainError(
                status
            )
        }

        guard let keyData = result as? Data else {
            throw CryptoServiceError.invalidKeyData
        }

        return SymmetricKey(
            data: keyData
        )
    }

    private func createKey() throws -> SymmetricKey {
        let key = SymmetricKey(
            size: .bits256
        )

        let keyData = key.withUnsafeBytes {
            Data($0)
        }

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData
        ]

        if requireAuthentication {

            var error: Unmanaged<CFError>?

            guard let accessControl =
                SecAccessControlCreateWithFlags(
                    nil,
                    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                    .userPresence,
                    &error
                )
            else {
                throw CryptoServiceError
                    .accessControlCreationFailed
            }

            query[kSecAttrAccessControl as String] =
                accessControl

        } else {

            query[kSecAttrAccessible as String] =
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }

        let status = SecItemAdd(
            query as CFDictionary,
            nil
        )

        guard status == errSecSuccess else {
            throw CryptoServiceError.keychainError(
                status
            )
        }

        return key
    }

    // MARK: - Key Deletion

    func deleteKey() throws {
        lockSession()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(
            query as CFDictionary
        )

        guard status == errSecSuccess ||
              status == errSecItemNotFound else {

            throw CryptoServiceError.keychainError(
                status
            )
        }
    }
}

enum CryptoServiceError: Error {
    case keyNotFound
    case invalidKeyData
    case encryptionFailed
    case decryptionFailed
    case accessControlCreationFailed
    case authenticationRequired
    case keychainError(OSStatus)
}
