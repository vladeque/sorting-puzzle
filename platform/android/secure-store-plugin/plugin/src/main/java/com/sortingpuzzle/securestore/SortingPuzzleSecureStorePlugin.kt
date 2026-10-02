package com.sortingpuzzle.securestore

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot
import java.nio.charset.StandardCharsets
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.Signature
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class SortingPuzzleSecureStorePlugin(godot: Godot) : GodotPlugin(godot) {
    override fun getPluginName() = BuildConfig.GODOT_PLUGIN_NAME

    private val keyStore: KeyStore
        get() = KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }

    @UsedByGodot
    fun ensure_installation_key(installationId: String): Boolean = runCatching {
        val alias = signingAlias(installationId)
        if (!keyStore.containsAlias(alias)) {
            val generator = KeyPairGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_EC,
                KEYSTORE_PROVIDER,
            )
            generator.initialize(
                KeyGenParameterSpec.Builder(
                    alias,
                    KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY,
                )
                    .setAlgorithmParameterSpec(java.security.spec.ECGenParameterSpec("secp256r1"))
                    .setDigests(KeyProperties.DIGEST_SHA256)
                    .setUserAuthenticationRequired(false)
                    .build(),
            )
            generator.generateKeyPair()
        }
    }.isSuccess

    @UsedByGodot
    fun get_installation_public_key_der(installationId: String): String = runCatching {
        if (!ensure_installation_key(installationId)) return ""
        val certificate = keyStore.getCertificate(signingAlias(installationId)) ?: return ""
        Base64.encodeToString(certificate.publicKey.encoded, Base64.NO_WRAP)
    }.getOrDefault("")

    @UsedByGodot
    fun sign_save_operation_hash(operationHash: String): String = runCatching {
        if (!operationHash.matches(Regex("^[a-f0-9]{64}$"))) return ""
        val installationId = installationIdFromPreferences() ?: return ""
        if (!ensure_installation_key(installationId)) return ""
        val privateKey = keyStore.getKey(signingAlias(installationId), null) ?: return ""
        val signer = Signature.getInstance("SHA256withECDSA")
        signer.initSign(privateKey as java.security.PrivateKey)
        signer.update(SIGNATURE_DOMAIN)
        signer.update(operationHash.toByteArray(StandardCharsets.US_ASCII))
        Base64.encodeToString(signer.sign(), Base64.NO_WRAP)
    }.getOrDefault("")

    @UsedByGodot
    fun sign_installation_payload(payload: String): String =
        signInstallationMessage(payload.toByteArray(StandardCharsets.UTF_8))

    @UsedByGodot
    fun store_player_session(playerId: String, sessionJson: String): Boolean = runCatching {
        if (!isUuid(playerId) || sessionJson.isBlank()) return false
        val encrypted = encrypt(sessionJson.toByteArray(StandardCharsets.UTF_8))
        preferences().edit()
            .putString(sessionPreferenceKey(playerId), Base64.encodeToString(encrypted, Base64.NO_WRAP))
            .apply()
    }.isSuccess

    @UsedByGodot
    fun load_player_session(playerId: String): String = runCatching {
        if (!isUuid(playerId)) return ""
        val encoded = preferences().getString(sessionPreferenceKey(playerId), null) ?: return ""
        val plaintext = decrypt(Base64.decode(encoded, Base64.NO_WRAP))
        String(plaintext, StandardCharsets.UTF_8)
    }.getOrDefault("")

    // commit() rather than apply(): account deletion must learn about a failed write.
    @UsedByGodot
    fun clear_player_session(playerId: String): Boolean = runCatching {
        preferences().edit().remove(sessionPreferenceKey(playerId)).commit()
    }.getOrDefault(false)

    // GAME-012: removes the signing key for a deleted account's installation and, when it names
    // that installation, the stored installation id. Idempotent. The shared session-encryption
    // key stays, because other players' sessions are encrypted with it.
    @UsedByGodot
    fun destroy_installation_key(installationId: String): Boolean = runCatching {
        if (!isUuid(installationId)) return false
        val alias = signingAlias(installationId)
        val store = keyStore
        if (store.containsAlias(alias)) store.deleteEntry(alias)
        val preferences = preferences()
        if (preferences.getString(INSTALLATION_ID_KEY, null) == installationId &&
            !preferences.edit().remove(INSTALLATION_ID_KEY).commit()
        ) {
            return false
        }
        !keyStore.containsAlias(alias)
    }.getOrDefault(false)

    @UsedByGodot
    fun set_installation_id(installationId: String): Boolean {
        if (!isUuid(installationId) || !ensure_installation_key(installationId)) return false
        preferences().edit().putString(INSTALLATION_ID_KEY, installationId).apply()
        return true
    }

    private fun encrypt(plaintext: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, sessionKey())
        return cipher.iv + cipher.doFinal(plaintext)
    }

    private fun decrypt(ciphertext: ByteArray): ByteArray {
        require(ciphertext.size > GCM_IV_BYTES)
        val iv = ciphertext.copyOfRange(0, GCM_IV_BYTES)
        val encrypted = ciphertext.copyOfRange(GCM_IV_BYTES, ciphertext.size)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, sessionKey(), GCMParameterSpec(GCM_TAG_BITS, iv))
        return cipher.doFinal(encrypted)
    }

    private fun sessionKey(): SecretKey {
        val existing = keyStore.getKey(SESSION_KEY_ALIAS, null)
        if (existing is SecretKey) return existing
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE_PROVIDER)
        generator.init(
            KeyGenParameterSpec.Builder(
                SESSION_KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .build(),
        )
        return generator.generateKey()
    }

    private fun preferences() =
        activity!!.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    private fun installationIdFromPreferences(): String? =
        preferences().getString(INSTALLATION_ID_KEY, null)

    private fun signInstallationMessage(message: ByteArray): String = runCatching {
        val installationId = installationIdFromPreferences() ?: return ""
        if (!ensure_installation_key(installationId)) return ""
        val privateKey = keyStore.getKey(signingAlias(installationId), null) ?: return ""
        val signer = Signature.getInstance("SHA256withECDSA")
        signer.initSign(privateKey as java.security.PrivateKey)
        signer.update(message)
        Base64.encodeToString(signer.sign(), Base64.NO_WRAP)
    }.getOrDefault("")

    private fun signingAlias(installationId: String) =
        "sorting_puzzle_signing_${sha256(installationId).take(32)}"

    private fun sessionPreferenceKey(playerId: String) =
        "player_session_${sha256(playerId)}"

    private fun sha256(value: String): String =
        MessageDigest.getInstance("SHA-256")
            .digest(value.toByteArray(StandardCharsets.UTF_8))
            .joinToString("") { "%02x".format(it) }

    private fun isUuid(value: String) =
        value.matches(Regex("^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"))

    companion object {
        private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
        private const val PREFERENCES_NAME = "sorting_puzzle_secure_sessions"
        private const val INSTALLATION_ID_KEY = "installation_id"
        private const val SESSION_KEY_ALIAS = "sorting_puzzle_session_encryption_v1"
        private const val GCM_IV_BYTES = 12
        private const val GCM_TAG_BITS = 128
        private val SIGNATURE_DOMAIN =
            "sorting-puzzle:save-operation:2\u0000".toByteArray(StandardCharsets.UTF_8)
    }
}
