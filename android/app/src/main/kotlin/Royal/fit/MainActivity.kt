package Royal.fit

import android.util.Base64
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val DEVICE_KEY_CHANNEL = "Royal.fit/device_key"

// FlutterFragmentActivity (not the plain FlutterActivity from the default
// template) because BiometricPrompt requires a FragmentActivity host.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_KEY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasKey" -> result.success(DeviceKeySigner.hasKey())

                    "getOrCreatePublicKey" -> {
                        try {
                            result.success(DeviceKeySigner.getOrCreatePublicKey())
                        } catch (e: Exception) {
                            result.error("GENERATE_FAILED", e.message, null)
                        }
                    }

                    "deleteKey" -> {
                        DeviceKeySigner.deleteKey()
                        result.success(null)
                    }

                    "sign" -> {
                        val challengeB64 = call.argument<String>("challenge")
                        if (challengeB64 == null) {
                            result.error("BAD_ARGS", "challenge is required", null)
                            return@setMethodCallHandler
                        }
                        val challengeBytes = Base64.decode(challengeB64, Base64.NO_WRAP)
                        DeviceKeySigner.signWithBiometricPrompt(this, challengeBytes) { signature, error ->
                            if (signature != null) {
                                result.success(signature)
                            } else {
                                result.error("SIGN_FAILED", error ?: "Signing failed.", null)
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
