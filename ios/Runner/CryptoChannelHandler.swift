//
//  CryptoChannelHandler.swift
//  Runner
//
//  Created by Oluwakemi Mafe on 2026-08-16.
//

import Flutter
import Foundation

final class CryptoChannelHandler {
    private let cryptoService: CryptoServicing
    
    init( cryptoService: CryptoServicing = CryptoService()) {
        self.cryptoService = cryptoService
    }

    func handle(
        call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        do {
            switch call.method {
            case "encrypt":
                try encrypt(call: call, result: result)

            case "decrypt":
                try decrypt(call: call, result: result)

            case "deleteKey":
                try cryptoService.deleteKey()
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        } catch CryptoServiceError.authenticationRequired {
            result(
                FlutterError(
                    code: "AUTHENTICATION_REQUIRED",
                    message: "User authentication is required to use the vault encryption key.",
                    details: nil
                )
            )
        } catch {
            result(
                FlutterError(
                    code: "CRYPTO_ERROR",
                    message: error.localizedDescription,
                    details: nil
                )
            )
        }
    }

    private func encrypt(
        call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) throws {
        guard
            let arguments = call.arguments as? [String: Any],
            let plainText = arguments["plainText"] as? String
        else {
            throw ChannelError.invalidArguments
        }

        result(
            try cryptoService.encrypt(plainText)
        )
    }

    private func decrypt(
        call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) throws {
        guard
            let arguments = call.arguments as? [String: Any],
            let cipherText = arguments["cipherText"] as? [UInt8],
            let nonce = arguments["nonce"] as? [UInt8],
            let mac = arguments["mac"] as? [UInt8]
        else {
            throw ChannelError.invalidArguments
        }

        result(
            try cryptoService.decrypt(
                cipherText: cipherText,
                nonce: nonce,
                mac: mac
            )
        )
    }
}

enum ChannelError: Error {
    case invalidArguments
}
