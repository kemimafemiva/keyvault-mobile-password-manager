package com.oluwakemimafe.key_vault

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CryptoChannelHandlerTest {

    @Test
    fun authenticationRequiredIsReturnedWithCorrectErrorCode() {
        val cryptoService =
            FakeCryptoService(
                encryptException =
                    AuthenticationRequiredException()
            )

        val handler =
            CryptoChannelHandler(cryptoService)

        val call = MethodCall(
            "encrypt",
            mapOf(
                "plainText" to "TestPassword123!"
            )
        )

        val result = TestResult()

        handler.handle(call, result)

        assertEquals(
            "AUTHENTICATION_REQUIRED",
            result.errorCode
        )

        assertEquals(
            "User authentication is required to use the vault encryption key.",
            result.errorMessage
        )

        assertNull(result.successValue)
    }

    @Test
    fun generalCryptoFailureReturnsCryptoError() {
        val cryptoService =
            FakeCryptoService(
                encryptException =
                    IllegalStateException(
                        "Encryption failed."
                    )
            )

        val handler =
            CryptoChannelHandler(cryptoService)

        val call = MethodCall(
            "encrypt",
            mapOf(
                "plainText" to "TestPassword123!"
            )
        )

        val result = TestResult()

        handler.handle(call, result)

        assertEquals(
            "CRYPTO_ERROR",
            result.errorCode
        )

        assertEquals(
            "Encryption failed.",
            result.errorMessage
        )
    }

    @Test
    fun unknownMethodReturnsNotImplemented() {
        val handler =
            CryptoChannelHandler(
                FakeCryptoService()
            )

        val call = MethodCall(
            "unknownMethod",
            null
        )

        val result = TestResult()

        handler.handle(call, result)

        assertTrue(result.notImplementedCalled)
        assertNull(result.errorCode)
    }
}

private class FakeCryptoService(
    private val encryptException: Exception? = null
) : CryptoService(
    requireAuthentication = false
) {
    override fun encrypt(
        plainText: String
    ): Map<String, Any> {
        encryptException?.let {
            throw it
        }

        return mapOf(
            "cipherText" to listOf(1, 2, 3),
            "nonce" to listOf(4, 5, 6),
            "mac" to listOf(7, 8, 9)
        )
    }
}

private class TestResult : MethodChannel.Result {

    var successValue: Any? = null
    var errorCode: String? = null
    var errorMessage: String? = null
    var errorDetails: Any? = null
    var notImplementedCalled = false

    override fun success(result: Any?) {
        successValue = result
    }

    override fun error(
        errorCode: String,
        errorMessage: String?,
        errorDetails: Any?
    ) {
        this.errorCode = errorCode
        this.errorMessage = errorMessage
        this.errorDetails = errorDetails
    }

    override fun notImplemented() {
        notImplementedCalled = true
    }
}