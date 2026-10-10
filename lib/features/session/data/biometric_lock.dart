import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optional fingerprint / face unlock for returning members.
///
/// Opt-in flag is stored in SharedPreferences. Device PIN / pattern is
/// allowed as a fallback (`biometricOnly: false`). Every method is
/// failure-safe: any platform error is treated as "not available" / "not
/// authenticated" rather than thrown.
class BiometricLock {
  BiometricLock({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  static const String _enabledKey = 'biometric_unlock_enabled';

  /// True when the device supports local auth AND at least one biometric is
  /// enrolled.
  Future<bool> isSupported() async {
    try {
      final deviceSupported = await _localAuth.isDeviceSupported();
      if (!deviceSupported) return false;
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;
      final available = await _localAuth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_enabledKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, enabled);
    } catch (_) {
      // Best effort - failing to persist the flag must never break
      // login / logout.
    }
  }

  /// Prompts for fingerprint / face, falling back to the device PIN.
  /// Returns false on failure, cancellation or any error.
  Future<bool> authenticate() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock Royal Fitness',
        biometricOnly: false,
      );
    } catch (_) {
      return false;
    }
  }
}
