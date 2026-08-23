package com.oluwakemimafe.key_vault

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import android.security.keystore.UserNotAuthenticatedException

@RunWith(AndroidJUnit4::class)
class CryptoServiceTest {

    private lateinit var cryptoService: CryptoService

    @Before
    fun setUp() {
        cryptoService = CryptoService(
            requireAuthentication = false
        )

        cryptoService.deleteKey()
    }

    @After
    fun tearDown() {
        cryptoService.deleteKey()
    }

    @Test
    fun encryptAndDecryptReturnsOriginalPlainText() {
        val plainText = "TestPassword123!"

        val encrypted = cryptoService.encrypt(plainText)

        val cipherText =
            encrypted["cipherText"] as List<*>

        val nonce =
            encrypted["nonce"] as List<*>

        val mac =
            encrypted["mac"] as List<*>

        val decrypted = cryptoService.decrypt(
            cipherText.toByteArray(),
            nonce.toByteArray(),
            mac.toByteArray()
        )

        assertEquals(
            plainText,
            decrypted
        )
    }

    @Test
    fun decryptRejectsModifiedCipherText() {
        val encrypted =
            cryptoService.encrypt("TestPassword123!")

        val cipherText =
            (encrypted["cipherText"] as List<*>)
                .toByteArray()

        val nonce =
            (encrypted["nonce"] as List<*>)
                .toByteArray()

        val mac =
            (encrypted["mac"] as List<*>)
                .toByteArray()

        // Deliberately corrupt one ciphertext byte.
        cipherText[0] =
            (cipherText[0].toInt() xor 0x01).toByte()

        assertThrows(Exception::class.java) {
            cryptoService.decrypt(
                cipherText,
                nonce,
                mac
            )
        }
    }

    @Test
    fun decryptRejectsModifiedAuthenticationTag() {
        val encrypted =
            cryptoService.encrypt("TestPassword123!")

        val cipherText =
            (encrypted["cipherText"] as List<*>)
                .toByteArray()

        val nonce =
            (encrypted["nonce"] as List<*>)
                .toByteArray()

        val mac =
            (encrypted["mac"] as List<*>)
                .toByteArray()

        // Deliberately corrupt the GCM authentication tag.
        mac[0] =
            (mac[0].toInt() xor 0x01).toByte()

        assertThrows(Exception::class.java) {
            cryptoService.decrypt(
                cipherText,
                nonce,
                mac
            )
        }
    }

    @Test
    fun decryptRejectsModifiedNonce() {
        val encrypted =
            cryptoService.encrypt("TestPassword123!")

        val cipherText =
            (encrypted["cipherText"] as List<*>)
                .toByteArray()

        val nonce =
            (encrypted["nonce"] as List<*>)
                .toByteArray()

        val mac =
            (encrypted["mac"] as List<*>)
                .toByteArray()

        // Deliberately corrupt the nonce.
        nonce[0] =
            (nonce[0].toInt() xor 0x01).toByte()

        assertThrows(Exception::class.java) {
            cryptoService.decrypt(
                cipherText,
                nonce,
                mac
            )
        }
    }

    @Test
    fun encryptionRequiresUserAuthentication() {
        // Remove the non-authenticated key used by the
        // other AES-GCM tests.
        cryptoService.deleteKey()

        val protectedCryptoService = CryptoService(
            requireAuthentication = true
        )

        try {
            assertThrows(
                AuthenticationRequiredException::class.java
            ) {
                protectedCryptoService.encrypt(
                    "TestPassword123!"
                )
            }
        } finally {
            protectedCryptoService.deleteKey()
        }
    }

    private fun List<*>.toByteArray(): ByteArray {
        return ByteArray(size) { index ->
            (this[index] as Number).toByte()
        }
    }
}