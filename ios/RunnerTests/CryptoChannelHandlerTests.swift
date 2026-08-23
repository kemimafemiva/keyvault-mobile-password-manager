//
//  CryptoChannelHandlerTests.swift
//  Runner
//
//  Created by Oluwakemi Mafe on 2026-08-23.
//

import XCTest
import Flutter
@testable import Runner

private final class FakeCryptoService: CryptoServicing {

    var errorToThrow: Error?

    func encrypt(
        _ plainText: String
    ) throws -> [String: Any] {
        if let errorToThrow {
            throw errorToThrow
        }

        return [
            "cipherText": [1, 2, 3],
            "nonce": [4, 5, 6],
            "mac": [7, 8, 9]
        ]
    }

    func decrypt(
        cipherText: [UInt8],
        nonce: [UInt8],
        mac: [UInt8]
    ) throws -> String {
        if let errorToThrow {
            throw errorToThrow
        }

        return "decrypted-value"
    }

    func deleteKey() throws {
        if let errorToThrow {
            throw errorToThrow
        }
    }
}

final class CryptoChannelHandlerTests: XCTestCase {

    func testAuthenticationRequiredReturnsCorrectErrorCode() {
        let cryptoService = FakeCryptoService()
        cryptoService.errorToThrow =
            CryptoServiceError.authenticationRequired

        let handler = CryptoChannelHandler(
            cryptoService: cryptoService
        )

        let call = FlutterMethodCall(
            methodName: "encrypt",
            arguments: [
                "plainText": "TestPassword123!"
            ]
        )

        let expectation = expectation(
            description: "Method channel result returned"
        )

        handler.handle(
            call: call
        ) { result in
            guard let error = result as? FlutterError else {
                XCTFail(
                    "Expected FlutterError but received \(String(describing: result))"
                )
                expectation.fulfill()
                return
            }

            XCTAssertEqual(
                error.code,
                "AUTHENTICATION_REQUIRED"
            )

            XCTAssertEqual(
                error.message,
                "User authentication is required to use the vault encryption key."
            )

            expectation.fulfill()
        }

        wait(
            for: [expectation],
            timeout: 1.0
        )
    }
    
    func testGeneralCryptoFailureReturnsCryptoError() {
        let cryptoService = FakeCryptoService()
        cryptoService.errorToThrow =
            CryptoServiceError.encryptionFailed

        let handler = CryptoChannelHandler(
            cryptoService: cryptoService
        )

        let call = FlutterMethodCall(
            methodName: "encrypt",
            arguments: [
                "plainText": "TestPassword123!"
            ]
        )

        let expectation = expectation(
            description: "Method channel result returned"
        )

        handler.handle(
            call: call
        ) { result in
            guard let error = result as? FlutterError else {
                XCTFail("Expected FlutterError")
                expectation.fulfill()
                return
            }

            XCTAssertEqual(
                error.code,
                "CRYPTO_ERROR"
            )

            expectation.fulfill()
        }

        wait(
            for: [expectation],
            timeout: 1.0
        )
    }
    
    func testUnknownMethodReturnsNotImplemented() {
        let cryptoService = FakeCryptoService()

        let handler = CryptoChannelHandler(
            cryptoService: cryptoService
        )

        let call = FlutterMethodCall(
            methodName: "unknownMethod",
            arguments: nil
        )

        let expectation = expectation(
            description: "Method channel result returned"
        )

        handler.handle(
            call: call
        ) { result in
            XCTAssertTrue(
                result as AnyObject ===
                    FlutterMethodNotImplemented
                        as AnyObject
            )

            expectation.fulfill()
        }

        wait(
            for: [expectation],
            timeout: 1.0
        )
    }
}
