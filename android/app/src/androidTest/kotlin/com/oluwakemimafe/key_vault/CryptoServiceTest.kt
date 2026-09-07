package com.oluwakemimafe.key_vault

import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.security.KeyFactory
import java.security.KeyStore
import javax.crypto.SecretKey

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
    fun unlockSessionAllowsSubsequentEncryptionAndDecryption() {
        cryptoService.unlockSession()

        val plainText = "TestPassword123!"

        val encrypted = cryptoService.encrypt(
            plainText
        )

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
    fun lockSessionDoesNotInvalidateAndroidKeystoreKey() {
        cryptoService.unlockSession()

        val encrypted = cryptoService.encrypt(
            "TestPassword123!"
        )

        cryptoService.lockSession()

        val decrypted = cryptoService.decrypt(
            (encrypted["cipherText"] as List<*>)
                .toByteArray(),
            (encrypted["nonce"] as List<*>)
                .toByteArray(),
            (encrypted["mac"] as List<*>)
                .toByteArray()
        )

        assertEquals(
            "TestPassword123!",
            decrypted
        )
    }

    @Test
    fun encryptAndDecryptReturnsOriginalPlainText() {
        val plainText = "TestPassword123!"

        val encrypted = cryptoService.encrypt(
            plainText
        )

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
            cryptoService.encrypt(
                "TestPassword123!"
            )

        val cipherText =
            (encrypted["cipherText"] as List<*>)
                .toByteArray()

        val nonce =
            (encrypted["nonce"] as List<*>)
                .toByteArray()

        val mac =
            (encrypted["mac"] as List<*>)
                .toByteArray()

        cipherText[0] =
            (cipherText[0].toInt() xor 0x01)
                .toByte()

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
            cryptoService.encrypt(
                "TestPassword123!"
            )

        val cipherText =
            (encrypted["cipherText"] as List<*>)
                .toByteArray()

        val nonce =
            (encrypted["nonce"] as List<*>)
                .toByteArray()

        val mac =
            (encrypted["mac"] as List<*>)
                .toByteArray()

        mac[0] =
            (mac[0].toInt() xor 0x01)
                .toByte()

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
            cryptoService.encrypt(
                "TestPassword123!"
            )

        val cipherText =
            (encrypted["cipherText"] as List<*>)
                .toByteArray()

        val nonce =
            (encrypted["nonce"] as List<*>)
                .toByteArray()

        val mac =
            (encrypted["mac"] as List<*>)
                .toByteArray()

        nonce[0] =
            (nonce[0].toInt() xor 0x01)
                .toByte()

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
        cryptoService.deleteKey()

        val protectedCryptoService =
            CryptoService(
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

    @Test
    fun protectedKeyUsesFiveMinuteAuthenticationValidityPeriod() {
        cryptoService.deleteKey()

        val protectedCryptoService =
            CryptoService(
                requireAuthentication = true
            )

        try {
            try {
                protectedCryptoService.encrypt(
                    "TestPassword123!"
                )
            } catch (_: AuthenticationRequiredException) {
                // The key has been created successfully.
            }

            val keyStore =
                KeyStore.getInstance(
                    "AndroidKeyStore"
                ).apply {
                    load(null)
                }

            val secretKey =
                keyStore.getKey(
                    "keyvault_encryption_key",
                    null
                ) as SecretKey

            val keyFactory =
                KeyFactory.getInstance(
                    secretKey.algorithm,
                    "AndroidKeyStore"
                )

            val keyInfo =
                keyFactory.getKeySpec(
                    secretKey,
                    KeyInfo::class.java
                )

            assertEquals(
                300,
                keyInfo.userAuthenticationValidityDurationSeconds
            )
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