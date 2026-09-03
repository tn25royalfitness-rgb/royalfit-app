import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'device_key_channel.dart';

/// Thrown for any punch-in/out failure. [message] is safe to show directly
/// to the user. [code] mirrors the backend's machine-readable error codes
/// (e.g. 'OUT_OF_RANGE', 'ALREADY_IN') where present.
class PunchException implements Exception {
  PunchException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

const _keyIdPrefKey = 'device_signing_key_id';

/// Orchestrates the device-key punch-in flow: register a hardware-backed
/// signing key once per install, then sign a fresh server challenge with it
/// (biometric-gated) on every punch in/out. Mirrors the web app's
/// WebAuthn + geolocation punch-in (`attendance-punch`) but talks to the
/// mobile-specific `device-key-register` / `device-punch-challenge` /
/// `attendance-punch-mobile` edge functions instead - see PHASE_HANDOFF.md.
class PunchRepository {
  PunchRepository({required SupabaseClient supabaseClient})
      : _supabaseClient = supabaseClient;

  final SupabaseClient _supabaseClient;

  Future<Map<String, dynamic>> _invoke(
    String function,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _supabaseClient.functions.invoke(function, body: body);
      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw PunchException(
          data['error'].toString(),
          code: data['code'] as String?,
        );
      }
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      throw PunchException('Unexpected response from server.');
    } on PunchException {
      rethrow;
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['error'] != null) {
        throw PunchException(
          details['error'].toString(),
          code: details['code'] as String?,
        );
      }
      throw PunchException(e.reasonPhrase ?? 'Request failed.');
    } catch (_) {
      throw PunchException(
        'Network error. Please check your connection and try again.',
      );
    }
  }

  Future<String?> _readStoredKeyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyIdPrefKey);
  }

  Future<void> _saveKeyId(String keyId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyIdPrefKey, keyId);
  }

  Future<bool> isRegistered() async {
    if (await _readStoredKeyId() == null) return false;
    return DeviceKeyChannel.hasKey();
  }

  /// Generates the device key (if needed) and registers its public key with
  /// the backend. Does not require biometric confirmation - only signing
  /// (i.e. actually punching in/out) does.
  Future<void> registerDevice({
    required String memberId,
    String? deviceLabel,
  }) async {
    final publicKey = await DeviceKeyChannel.getOrCreatePublicKey();
    final data = await _invoke('device-key-register', {
      'member_id': memberId,
      'public_key': publicKey,
      'device_label': deviceLabel,
    });
    await _saveKeyId(data['key_id'] as String);
  }

  Future<Position> _currentPosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw PunchException(
        'Location permission is required to punch in/out.',
      );
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw PunchException('Please turn on location services.');
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      throw PunchException('Could not get your location. Please try again.');
    }
  }

  /// Full punch flow: fetch a fresh challenge, sign it with the device key
  /// (biometric prompt), capture location, then submit. Returns the
  /// `attendance` row from `attendance-punch-mobile` on success.
  Future<Map<String, dynamic>> punch({
    required String memberId,
    required bool checkingIn,
  }) async {
    final keyId = await _readStoredKeyId();
    if (keyId == null) {
      throw PunchException(
        'Set up punch-in on this device first.',
        code: 'NOT_REGISTERED',
      );
    }

    final challengeData = await _invoke('device-punch-challenge', {
      'member_id': memberId,
    });

    if (challengeData['has_key'] != true) {
      throw PunchException(
        'This device is not registered for punch-in yet.',
        code: 'NOT_REGISTERED',
      );
    }

    final challenge = challengeData['challenge'] as String;

    String signature;
    try {
      signature = await DeviceKeyChannel.sign(challenge);
    } on DeviceKeyException catch (e) {
      if (e.message == '_cancelled_') {
        throw PunchException('_cancelled_');
      }
      throw PunchException(e.message);
    }

    final position = await _currentPosition();

    final data = await _invoke('attendance-punch-mobile', {
      'member_id': memberId,
      'action': checkingIn ? 'in' : 'out',
      'key_id': keyId,
      'signature': signature,
      'location': {
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
      },
    });

    return Map<String, dynamic>.from(data['attendance'] as Map);
  }
}
