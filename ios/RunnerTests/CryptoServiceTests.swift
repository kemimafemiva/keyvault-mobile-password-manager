//
//  CryptoServiceTests.swift
//  Runner
//
//  Created by Oluwakemi Mafe on 2026-08-17.
//

import XCTest

@testable import Runner

final class CryptoServiceTests: XCTestCase {
    private var cryptoService: CryptoService!

    override func setUpWithError() throws {
        cryptoService = CryptoService(
            requireAuthentication: false,
            service: "com.oluwakemimafe.keyvault.tests",
            account: "vault-encryption-key-tests"
        )

        // Each test starts with a fresh encryption key
        // and no active crypto session.
        try cryptoService.deleteKey()
    }

    override func tearDownWithError() throws {
        try cryptoService.deleteKey()
        cryptoService = nil
    }

    func testUnlockSessionAllowsEncryptionAndDecryption() throws {
        try cryptoService.unlockSession()

        let plainText = "TestPassword123!"

        let encrypted = try cryptoService.encrypt(
            plainText
        )

        guard
            let cipherText = encrypted["cipherText"] as? [UInt8],
            let nonce = encrypted["nonce"] as? [UInt8],
            let mac = encrypted["mac"] as? [UInt8]
        else {
            XCTFail("Invalid encrypted data.")
            return
        }

        let decrypted = try cryptoService.decrypt(
            cipherText: cipherText,
            nonce: nonce,
            mac: mac
        )

        XCTAssertEqual(
            decrypted,
            plainText
        )
    }

    func testEncryptRequiresUnlockedSession() throws {
        XCTAssertThrowsError(
            try cryptoService.encrypt(
                "TestPassword123!"
            )
        ) { error in
            guard case CryptoServiceError.authenticationRequired = error else {
                XCTFail(
                    "Expected authenticationRequired, got \(error)."
                )
                return
            }
        }
    }

    func testLockSessionPreventsFurtherEncryption() throws {
        try cryptoService.unlockSession()

        cryptoService.lockSession()

        XCTAssertThrowsError(
            try cryptoService.encrypt(
                "TestPassword123!"
            )
        ) { error in
            guard case CryptoServiceError.authenticationRequired = error else {
                XCTFail(
                    "Expected authenticationRequired, got \(error)."
                )
                return
            }
        }
    }

    func testLockSessionPreventsFurtherDecryption() throws {
        try cryptoService.unlockSession()

        let encrypted = try cryptoService.encrypt(
            "TestPassword123!"
        )

        guard
            let cipherText = encrypted["cipherText"] as? [UInt8],
            let nonce = encrypted["nonce"] as? [UInt8],
            let mac = encrypted["mac"] as? [UInt8]
        else {
            XCTFail("Invalid encrypted data.")
            return
        }

        cryptoService.lockSession()

        XCTAssertThrowsError(
            try cryptoService.decrypt(
                cipherText: cipherText,
                nonce: nonce,
                mac: mac
            )
        ) { error in
            guard case CryptoServiceError.authenticationRequired = error else {
                XCTFail(
                    "Expected authenticationRequired, got \(error)."
                )
                return
            }
        }
    }

    func testEncryptAndDecryptReturnsOriginalPlainText() throws {
        try cryptoService.unlockSession()

        let plainText = "TestPassword123!"

        let encrypted = try cryptoService.encrypt(
            plainText
        )

        guard
            let cipherText = encrypted["cipherText"] as? [UInt8],
            let nonce = encrypted["nonce"] as? [UInt8],
            let mac = encrypted["mac"] as? [UInt8]
        else {
            XCTFail("Invalid encrypted data.")
            return
        }

        let decrypted = try cryptoService.decrypt(
            cipherText: cipherText,
            nonce: nonce,
            mac: mac
        )

        XCTAssertEqual(
            decrypted,
            plainText
        )
    }

    func testDecryptRejectsModifiedCipherText() throws {
        try cryptoService.unlockSession()

        let encrypted = try cryptoService.encrypt(
            "TestPassword123!"
        )

        guard
            var cipherText = encrypted["cipherText"] as? [UInt8],
            let nonce = encrypted["nonce"] as? [UInt8],
            let mac = encrypted["mac"] as? [UInt8]
        else {
            XCTFail("Invalid encrypted data.")
            return
        }

        XCTAssertFalse(cipherText.isEmpty)

        cipherText[0] ^= 0x01

        XCTAssertThrowsError(
            try cryptoService.decrypt(
                cipherText: cipherText,
                nonce: nonce,
                mac: mac
            )
        )
    }

    func testDecryptRejectsModifiedAuthenticationTag() throws {
        try cryptoService.unlockSession()

        let encrypted = try cryptoService.encrypt(
            "TestPassword123!"
        )

        guard
            let cipherText = encrypted["cipherText"] as? [UInt8],
            let nonce = encrypted["nonce"] as? [UInt8],
            var mac = encrypted["mac"] as? [UInt8]
        else {
            XCTFail("Invalid encrypted data.")
            return
        }

        XCTAssertFalse(mac.isEmpty)

        mac[0] ^= 0x01

        XCTAssertThrowsError(
            try cryptoService.decrypt(
                cipherText: cipherText,
                nonce: nonce,
                mac: mac
            )
        )
    }

    func testDecryptRejectsModifiedNonce() throws {
        try cryptoService.unlockSession()

        let encrypted = try cryptoService.encrypt(
            "TestPassword123!"
        )

        guard
            let cipherText = encrypted["cipherText"] as? [UInt8],
            var nonce = encrypted["nonce"] as? [UInt8],
            let mac = encrypted["mac"] as? [UInt8]
        else {
            XCTFail("Invalid encrypted data.")
            return
        }

        XCTAssertFalse(nonce.isEmpty)

        nonce[0] ^= 0x01

        XCTAssertThrowsError(
            try cryptoService.decrypt(
                cipherText: cipherText,
                nonce: nonce,
                mac: mac
            )
        )
    }

    func testSessionRemainsValidBeforeAuthenticationTimeout() throws {
        var currentDate = Date(timeIntervalSince1970: 1_000)

        cryptoService = CryptoService(
            requireAuthentication: false,
            currentDate: {currentDate},
            service: "com.oluwakemimafe.keyvault.tests",
            account: "vault-encryption-key-tests"
        )

        try cryptoService.deleteKey()
        try cryptoService.unlockSession()

        currentDate = currentDate.addingTimeInterval(299)

        XCTAssertNoThrow(
            try cryptoService.encrypt(
                "TestPassword123!"
            )
        )
    }

    func testRenewSessionExtendsAuthenticationWindow() throws {
        var currentDate = Date(timeIntervalSince1970: 1_000)

        cryptoService = CryptoService(
            requireAuthentication: false,
            currentDate: {currentDate},
            service: "com.oluwakemimafe.keyvault.tests",
            account: "vault-encryption-key-tests"
        )

        try cryptoService.deleteKey()
        try cryptoService.unlockSession()

        currentDate = currentDate.addingTimeInterval(250)

        cryptoService.renewSession()

        currentDate = currentDate.addingTimeInterval(250)

        XCTAssertNoThrow(
            try cryptoService.encrypt(
                "TestPassword123!"
            )
        )
    }

    func testRenewSessionDoesNotUnlockLockedSession() throws {
        try cryptoService.unlockSession()

        cryptoService.lockSession()
        cryptoService.renewSession()

        XCTAssertThrowsError(
            try cryptoService.encrypt(
                "TestPassword123!"
            )
        ) { error in
            guard case CryptoServiceError.authenticationRequired = error else {
                XCTFail(
                    "Expected authenticationRequired, got \(error)."
                )
                return
            }
        }
    }

    func testSessionExpiresAtAuthenticationTimeout() throws {
        var currentDate = Date(timeIntervalSince1970: 1_000)

        cryptoService = CryptoService(
            requireAuthentication: false,
            currentDate: {currentDate},
            service: "com.oluwakemimafe.keyvault.tests",
            account: "vault-encryption-key-tests"
        )

        try cryptoService.deleteKey()
        try cryptoService.unlockSession()

        currentDate = currentDate.addingTimeInterval(300)

        XCTAssertThrowsError(
            try cryptoService.encrypt(
                "TestPassword123!"
            )
        ) { error in
            guard case CryptoServiceError.authenticationRequired = error else {
                XCTFail(
                    "Expected authenticationRequired, got \(error)."
                )
                return
            }
        }
    }

    func testUnlockSessionStartsNewAuthenticationWindowAfterExpiry() throws {
        var currentDate = Date(timeIntervalSince1970: 1_000)

        cryptoService = CryptoService(
            requireAuthentication: false,
            currentDate: {currentDate},
            service: "com.oluwakemimafe.keyvault.tests",
            account: "vault-encryption-key-tests"
        )

        try cryptoService.deleteKey()
        try cryptoService.unlockSession()

        currentDate = currentDate.addingTimeInterval(300)

        XCTAssertThrowsError(
            try cryptoService.encrypt(
                "TestPassword123!"
            )
        ) { error in
            guard case CryptoServiceError.authenticationRequired = error else {
                XCTFail(
                    "Expected authenticationRequired, got \(error)."
                )
                return
            }
        }

        try cryptoService.unlockSession()

        XCTAssertNoThrow(
            try cryptoService.encrypt(
                "TestPassword123!"
            )
        )
    }
}