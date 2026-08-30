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
    var unlockSessionCallCount = 0
    var lockSessionCallCount = 0
    var encryptCallCount = 0
    var decryptCallCount = 0
    var deleteKeyCallCount = 0

    func unlockSession() throws {
        unlockSessionCallCount += 1

        if let errorToThrow {
            throw errorToThrow
        }
    }

    func lockSession() {
        lockSessionCallCount += 1
    }

    func encrypt(
        _ plainText: String
    ) throws -> [String: Any] {
        encryptCallCount += 1

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
        decryptCallCount += 1

        if let errorToThrow {
            throw errorToThrow
        }

        return "decrypted-value"
    }

    func deleteKey() throws {
        deleteKeyCallCount += 1

        if let errorToThrow {
            throw errorToThrow
        }
    }
}

final class CryptoChannelHandlerTests: XCTestCase {
    func testUnlockSessionDelegatesToCryptoService() {
        let cryptoService = FakeCryptoService()

        let handler = CryptoChannelHandler(
            cryptoService: cryptoService
        )

        let call = FlutterMethodCall(
            methodName: "unlockSession",
            arguments: nil
        )

        let expectation = expectation(
            description: "Method channel result returned"
        )

        handler.handle(
            call: call
        ) { result in
            XCTAssertNil(result)

            XCTAssertEqual(
                cryptoService.unlockSessionCallCount,
                1
            )

            XCTAssertEqual(
                cryptoService.lockSessionCallCount,
                0
            )

            expectation.fulfill()
        }

        wait(
            for: [expectation],
            timeout: 1.0
        )
    }

    func testLockSessionDelegatesToCryptoService() {
        let cryptoService = FakeCryptoService()

        let handler = CryptoChannelHandler(
            cryptoService: cryptoService
        )

        let call = FlutterMethodCall(
            methodName: "lockSession",
            arguments: nil
        )

        let expectation = expectation(
            description: "Method channel result returned"
        )

        handler.handle(
            call: call
        ) { result in
            XCTAssertNil(result)

            XCTAssertEqual(
                cryptoService.lockSessionCallCount,
                1
            )

            XCTAssertEqual(
                cryptoService.unlockSessionCallCount,
                0
            )

            expectation.fulfill()
        }

        wait(
            for: [expectation],
            timeout: 1.0
        )
    }

    func testUnlockSessionAuthenticationRequiredReturnsCorrectErrorCode() {
        let cryptoService = FakeCryptoService()

        cryptoService.errorToThrow =
            CryptoServiceError.authenticationRequired

        let handler = CryptoChannelHandler(
            cryptoService: cryptoService
        )

        let call = FlutterMethodCall(
            methodName: "unlockSession",
            arguments: nil
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

            XCTAssertEqual(
                cryptoService.unlockSessionCallCount,
                1
            )

            expectation.fulfill()
        }

        wait(
            for: [expectation],
            timeout: 1.0
        )
    }

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

            XCTAssertEqual(
                cryptoService.encryptCallCount,
                1
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

            XCTAssertEqual(
                cryptoService.encryptCallCount,
                1
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
                    FlutterMethodNotImplemented as AnyObject
            )

            XCTAssertEqual(
                cryptoService.unlockSessionCallCount,
                0
            )

            XCTAssertEqual(
                cryptoService.lockSessionCallCount,
                0
            )

            XCTAssertEqual(
                cryptoService.encryptCallCount,
                0
            )

            XCTAssertEqual(
                cryptoService.decryptCallCount,
                0
            )

            XCTAssertEqual(
                cryptoService.deleteKeyCallCount,
                0
            )

            expectation.fulfill()
        }

        wait(
            for: [expectation],
            timeout: 1.0
        )
    }
}
