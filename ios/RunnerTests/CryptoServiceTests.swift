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
        cryptoService = CryptoService(requireAuthentication: false)

        // Each test starts with a fresh encryption key.
        try cryptoService.deleteKey()
    }

    override func tearDownWithError() throws {
        try cryptoService.deleteKey()
        cryptoService = nil
    }

    func testEncryptAndDecryptReturnsOriginalPlainText() throws {
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

        // Deliberately corrupt one byte.
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

        // Deliberately corrupt the authentication tag.
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

}
