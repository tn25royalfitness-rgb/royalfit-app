package Royal.fit

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.Signature
import java.security.spec.ECGenParameterSpec

private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
private const val KEY_ALIAS = "royalfitness_punch_signing_key"

/**
 * Wraps a hardware-backed (Android Keystore) EC P-256 key used to sign the
 * punch-in challenge. This is deliberately hand-written platform code
 * instead of a third-party Flutter plugin: this project's history is that
 * small third-party packages touching crypto/secure-storage (see
 * flutter_secure_storage in PHASE_HANDOFF.md) have dragged in broken
 * transitive Gradle dependencies. Talking to AndroidKeyStore/BiometricPrompt
 * directly avoids that class of risk entirely.
 *
 * The key requires authentication (biometric or device credential) for
 * every signing operation - see `setUserAuthenticationValidityDurationSeconds(-1)`
 * below, which is the documented value for binding a key to a single
 * BiometricPrompt.CryptoObject operation rather than unlocking it for a
 * time window.
 */
object DeviceKeySigner {

    fun hasKey(): Boolean {
        val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }
        return keyStore.containsAlias(KEY_ALIAS)
    }

    /**
     * Generates the key pair if it doesn't already exist, and returns the
     * public key as base64-encoded X.509 SubjectPublicKeyInfo DER (the
     * format `crypto.subtle.importKey('spki', ...)` expects server-side).
     */
    fun getOrCreatePublicKey(): String {
        val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }

        if (!keyStore.containsAlias(KEY_ALIAS)) {
            val keyPairGenerator = KeyPairGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_EC, KEYSTORE_PROVIDER
            )
            val spec = KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_SIGN)
                .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setUserAuthenticationRequired(true)
                .setUserAuthenticationValidityDurationSeconds(-1)
                .build()
            keyPairGenerator.initialize(spec)
            keyPairGenerator.generateKeyPair()
        }

        val certificate = keyStore.getCertificate(KEY_ALIAS)
        return Base64.encodeToString(certificate.publicKey.encoded, Base64.NO_WRAP)
    }

    fun deleteKey() {
        val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }
        if (keyStore.containsAlias(KEY_ALIAS)) {
            keyStore.deleteEntry(KEY_ALIAS)
        }
    }

    /**
     * Signs [challenge] (raw bytes, typically the UTF-8 bytes of the
     * server-issued challenge string) with the stored key, prompting
     * biometric/device-credential authentication. Calls [onResult] with the
     * base64-encoded ASN.1 DER signature on success, or null + a
     * human-readable error message on failure/cancellation.
     *
     * Must be called on the main thread from a running [FragmentActivity].
     */
    fun signWithBiometricPrompt(
        activity: FragmentActivity,
        challenge: ByteArray,
        onResult: (signature: String?, error: String?) -> Unit
    ) {
        val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }
        val privateKey = keyStore.getKey(KEY_ALIAS, null) as? PrivateKey
        if (privateKey == null) {
            onResult(null, "No punch-in key registered on this device.")
            return
        }

        val signature: Signature
        try {
            signature = Signature.getInstance("SHA256withECDSA")
            signature.initSign(privateKey)
        } catch (e: Exception) {
            onResult(null, e.message ?: "Could not prepare signing key.")
            return
        }

        val executor = ContextCompat.getMainExecutor(activity)
        // Crypto-based authentication (a CryptoObject bound to this specific
        // Signature) only supports BIOMETRIC_STRONG - combining it with
        // DEVICE_CREDENTIAL throws at runtime, so a negative/cancel button is
        // required instead of a device-credential fallback.
        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Confirm punch-in")
            .setSubtitle("Verify it's you to record attendance")
            .setAllowedAuthenticators(androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG)
            .setNegativeButtonText("Cancel")
            .build()

        val biometricPrompt = BiometricPrompt(
            activity,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(
                    result: BiometricPrompt.AuthenticationResult
                ) {
                    try {
                        val authedSignature = result.cryptoObject?.signature
                        if (authedSignature == null) {
                            onResult(null, "Authentication did not return a usable signature.")
                            return
                        }
                        authedSignature.update(challenge)
                        val signed = authedSignature.sign()
                        onResult(Base64.encodeToString(signed, Base64.NO_WRAP), null)
                    } catch (e: Exception) {
                        onResult(null, e.message ?: "Signing failed.")
                    }
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    // Match on the numeric error code, not the (localized,
                    // OEM-varying) message text, so the Dart side can reliably
                    // tell "user cancelled" apart from an actual failure.
                    val cancelled = errorCode == BiometricPrompt.ERROR_USER_CANCELED ||
                        errorCode == BiometricPrompt.ERROR_NEGATIVE_BUTTON ||
                        errorCode == BiometricPrompt.ERROR_CANCELED
                    onResult(null, if (cancelled) "_cancelled_" else errString.toString())
                }

                override fun onAuthenticationFailed() {
                    // Not terminal - the prompt stays open for the user to retry.
                }
            }
        )

        try {
            biometricPrompt.authenticate(promptInfo, BiometricPrompt.CryptoObject(signature))
        } catch (e: Exception) {
            onResult(null, e.message ?: "Could not start biometric prompt.")
        }
    }
}
