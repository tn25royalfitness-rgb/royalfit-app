import 'dart:convert';

import 'package:flutter/services.dart';

/// Thrown for any native device-key operation failure (biometric prompt
/// cancelled, no key registered, signing failed, etc). [message] is safe to
/// show directly to the user.
class DeviceKeyException implements Exception {
  DeviceKeyException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thin wrapper around the `Royal.fit/device_key`
/// MethodChannel, backed by hand-written Kotlin (`DeviceKeySigner.kt`) that
/// talks to the Android Keystore + BiometricPrompt directly - see
/// PHASE_HANDOFF.md for why this is native code rather than a plugin.
class DeviceKeyChannel {
  DeviceKeyChannel._();

  static const MethodChannel _channel =
      MethodChannel('Royal.fit/device_key');

  static Future<bool> hasKey() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasKey');
      return result ?? false;
    } on PlatformException catch (e) {
      throw DeviceKeyException(e.message ?? 'Could not check for a device key.');
    }
  }

  /// Returns the base64-encoded X.509 SubjectPublicKeyInfo DER of the
  /// device's signing key, generating it first if it doesn't exist yet.
  /// Key generation itself does not require biometric confirmation - only
  /// signing does.
  static Future<String> getOrCreatePublicKey() async {
    try {
      final result = await _channel.invokeMethod<String>('getOrCreatePublicKey');
      if (result == null) {
        throw DeviceKeyException('Could not create a device key.');
      }
      return result;
    } on PlatformException catch (e) {
      throw DeviceKeyException(e.message ?? 'Could not create a device key.');
    }
  }

  /// Signs the UTF-8 bytes of [challenge] with the device key, prompting
  /// biometric authentication. Returns the base64-encoded ASN.1 DER
  /// signature.
  static Future<String> sign(String challenge) async {
    try {
      final challengeBytes = utf8.encode(challenge);
      final result = await _channel.invokeMethod<String>('sign', {
        'challenge': base64Encode(challengeBytes),
      });
      if (result == null) {
        throw DeviceKeyException('Signing failed.');
      }
      return result;
    } on PlatformException catch (e) {
      if (e.message == '_cancelled_') {
        throw DeviceKeyException('_cancelled_');
      }
      throw DeviceKeyException(e.message ?? 'Signing failed.');
    }
  }

  static Future<void> deleteKey() async {
    try {
      await _channel.invokeMethod('deleteKey');
    } on PlatformException catch (e) {
      throw DeviceKeyException(e.message ?? 'Could not remove the device key.');
    }
  }
}
