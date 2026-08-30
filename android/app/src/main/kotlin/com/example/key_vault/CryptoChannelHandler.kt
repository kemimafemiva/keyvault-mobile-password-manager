package com.oluwakemimafe.key_vault

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class CryptoChannelHandler(
    private val cryptoService: CryptoService =
        CryptoService()
) {

    fun handle(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        try {
            when (call.method) {
                "unlockSession" -> {
                    cryptoService.unlockSession()
                    result.success(null)
                }

                "lockSession" -> {
                    cryptoService.lockSession()
                    result.success(null)
                }

                "encrypt" -> {
                    encrypt(
                        call,
                        result
                    )
                }

                "decrypt" -> {
                    decrypt(
                        call,
                        result
                    )
                }

                "deleteKey" -> {
                    cryptoService.deleteKey()
                    result.success(null)
                }

                else -> {
                    result.notImplemented()
                }
            }
        } catch (
            exception: AuthenticationRequiredException
        ) {
            result.error(
                "AUTHENTICATION_REQUIRED",
                exception.message,
                null
            )
        } catch (exception: Exception) {
            result.error(
                "CRYPTO_ERROR",
                exception.message
                    ?: "Native cryptographic operation failed.",
                null
            )
        }
    }

    private fun encrypt(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        val plainText =
            call.argument<String>(
                "plainText"
            )
                ?: throw IllegalArgumentException(
                    "plainText is required."
                )

        result.success(
            cryptoService.encrypt(
                plainText
            )
        )
    }

    private fun decrypt(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        val cipherText =
            call.argument<List<Int>>(
                "cipherText"
            )
                ?: throw IllegalArgumentException(
                    "cipherText is required."
                )

        val nonce =
            call.argument<List<Int>>(
                "nonce"
            )
                ?: throw IllegalArgumentException(
                    "nonce is required."
                )

        val mac =
            call.argument<List<Int>>(
                "mac"
            )
                ?: throw IllegalArgumentException(
                    "mac is required."
                )

        result.success(
            cryptoService.decrypt(
                cipherText.toByteArray(),
                nonce.toByteArray(),
                mac.toByteArray()
            )
        )
    }

    private fun List<Int>.toByteArray(): ByteArray =
        ByteArray(size) { index ->
            this[index].toByte()
        }
}