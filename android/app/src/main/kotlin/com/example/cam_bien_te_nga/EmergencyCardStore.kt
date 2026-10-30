package com.example.cam_bien_te_nga

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** One explicitly configured wearer per phone. Never sent to the cloud API. */
object EmergencyCardStore {
    private const val ALIAS = "motion.emergency.card.v1"
    private fun prefs(context: Context) = context.getSharedPreferences("motion_emergency_card", Context.MODE_PRIVATE)
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setUserAuthenticationRequired(false).build())
        }.generateKey()
    }
    @Synchronized fun read(context: Context): JSONObject {
        val encoded = prefs(context).getString("data", null) ?: return JSONObject()
        val parts = encoded.split(":")
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, Base64.decode(parts[0], Base64.NO_WRAP)))
        return JSONObject(String(cipher.doFinal(Base64.decode(parts[1], Base64.NO_WRAP)), Charsets.UTF_8))
    }
    @Synchronized fun save(context: Context, input: Map<*, *>) {
        val result = JSONObject()
        for ((field, limit) in mapOf("name" to 80, "conditions" to 500, "allergies" to 500, "medications" to 500,
            "contactName" to 80, "contactPhone" to 20, "heightCm" to 8, "weightKg" to 8, "bloodGroup" to 12)) {
            val value = (input[field] as? String ?: "").trim()
            check(value.length <= limit) { "Thông tin thẻ quá dài." }
            result.put(field, value)
        }
        result.put("showWhenLocked", input["showWhenLocked"] == true)
        result.put("updatedAt", System.currentTimeMillis())
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val data = Base64.encodeToString(cipher.iv, Base64.NO_WRAP) + ":" +
            Base64.encodeToString(cipher.doFinal(result.toString().toByteArray(Charsets.UTF_8)), Base64.NO_WRAP)
        check(prefs(context).edit().putString("data", data).commit()) { "Không lưu được thẻ." }
    }
    @Synchronized fun delete(context: Context) { prefs(context).edit().clear().commit() }
    fun available(context: Context): Boolean = try {
        val card = read(context)
        card.optBoolean("showWhenLocked") && card.optString("name").isNotBlank()
    } catch (_: Exception) { false }
}
