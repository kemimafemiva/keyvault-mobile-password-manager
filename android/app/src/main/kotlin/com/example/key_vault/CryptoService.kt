package com.oluwakemimafe.key_vault

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import android.security.keystore.UserNotAuthenticatedException

open class CryptoService(private val requireAuthentication: Boolean = true) {

    companion object {
        private const val KEY_ALIAS = "keyvault_encryption_key"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val GCM_TAG_LENGTH = 128
    }

    private val keyStore: KeyStore =
        KeyStore.getInstance(ANDROID_KEYSTORE).apply {
            load(null)
        }

    open fun encrypt(plainText: String): Map<String, Any> {
        val secretKey = getOrCreateKey()

        val cipher = Cipher.getInstance(TRANSFORMATION)

        try {
            cipher.init(
                Cipher.ENCRYPT_MODE,
                secretKey
            )
        } catch (exception: UserNotAuthenticatedException) {
            throw AuthenticationRequiredException()
        }

        val encryptedData = cipher.doFinal(
            plainText.toByteArray(Charsets.UTF_8)
        )

        val nonce = cipher.iv

        /*
         * Java's AES/GCM implementation returns:
         *
         * ciphertext || authentication tag
         *
         * the Dart/iOS contract keeps these separate,
         * so splitting the final 16 bytes into the MAC/tag.
         */
        val tagLengthBytes = GCM_TAG_LENGTH / 8

        val cipherText = encryptedData.copyOfRange(
            0,
            encryptedData.size - tagLengthBytes
        )

        val mac = encryptedData.copyOfRange(
            encryptedData.size - tagLengthBytes,
            encryptedData.size
        )

        return mapOf(
            "cipherText" to cipherText.toList(),
            "nonce" to nonce.toList(),
            "mac" to mac.toList()
        )
    }

    open fun decrypt(
        cipherText: ByteArray,
        nonce: ByteArray,
        mac: ByteArray
    ): String {
        val secretKey = getExistingKey()

        val cipher = Cipher.getInstance(TRANSFORMATION)

        val parameterSpec = GCMParameterSpec(
            GCM_TAG_LENGTH,
            nonce
        )

        try {
            cipher.init(
                Cipher.DECRYPT_MODE,
                secretKey,
                parameterSpec
            )
        } catch (exception: UserNotAuthenticatedException) {
            throw AuthenticationRequiredException()
        }

        // Reconstruct ciphertext || authentication tag.
        val encryptedData = cipherText + mac

        val decryptedData = cipher.doFinal(
            encryptedData
        )

        return String(
            decryptedData,
            Charsets.UTF_8
        )
    }

    open fun deleteKey() {
        if (keyStore.containsAlias(KEY_ALIAS)) {
            keyStore.deleteEntry(KEY_ALIAS)
        }
    }

    private fun getOrCreateKey(): SecretKey {
        return if (keyStore.containsAlias(KEY_ALIAS)) {
            getExistingKey()
        } else {
            createKey()
        }
    }

    private fun getExistingKey(): SecretKey {
        val key = keyStore.getKey(
            KEY_ALIAS,
            null
        )

        return key as? SecretKey
            ?: throw IllegalStateException(
                "KeyVault encryption key was not found."
            )
    }
    private fun createKey(): SecretKey {
        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            ANDROID_KEYSTORE
        )

        val keySpecBuilder = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or
                KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(
                KeyProperties.BLOCK_MODE_GCM
            )
            .setEncryptionPaddings(
                KeyProperties.ENCRYPTION_PADDING_NONE
            )
            .setKeySize(256)

        if (requireAuthentication) {
            keySpecBuilder
                .setUserAuthenticationRequired(true)
                .setUserAuthenticationParameters(
                    30,
                    KeyProperties.AUTH_BIOMETRIC_STRONG or
                        KeyProperties.AUTH_DEVICE_CREDENTIAL
                )
        }

        keyGenerator.init(
            keySpecBuilder.build()
        )

        return keyGenerator.generateKey()
    }
}