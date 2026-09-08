import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Registers/unregisters this device's FCM token with the `push-subscribe`
/// edge function, using the same table (and function) the web app's Web
/// Push subscriptions use - see PHASE_HANDOFF.md / the Phase 4 migration for
/// how the two subscription shapes share `push_subscriptions`.
class PushRepository {
  PushRepository({required SupabaseClient supabaseClient})
      : _supabaseClient = supabaseClient;

  final SupabaseClient _supabaseClient;

  String get _platform => Platform.isIOS ? 'ios' : 'android';

  /// Requests notification permission (a no-op / auto-granted on most
  /// Android versions below 13, an explicit runtime prompt on 13+), then
  /// registers the current FCM token for [memberId]. Silently does nothing
  /// if permission is denied or the member is a gym-only client (the
  /// backend 403s that case, same restriction as the web app).
  Future<void> registerCurrentDevice(String memberId) async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    await _subscribe(memberId: memberId, token: token);
  }

  Future<void> _subscribe({required String memberId, required String token}) async {
    try {
      await _supabaseClient.functions.invoke(
        'push-subscribe',
        body: {
          'member_id': memberId,
          'action': 'subscribe',
          'platform': _platform,
          'fcm_token': token,
        },
      );
    } catch (_) {
      // Best-effort - a failed push registration should never block login
      // or navigation.
    }
  }

  Future<void> unregister({required String memberId, required String token}) async {
    try {
      await _supabaseClient.functions.invoke(
        'push-subscribe',
        body: {
          'member_id': memberId,
          'action': 'unsubscribe',
          'platform': _platform,
          'fcm_token': token,
        },
      );
    } catch (_) {
      // Best-effort.
    }
  }

  /// Deactivates this device's push subscription for [memberId] - must be
  /// called on logout. The subscription row is keyed by the device's FCM
  /// token, not by who's currently logged in, so without this a device
  /// keeps receiving the previous member's reminder pushes indefinitely
  /// after they log out (the row only gets reassigned to a *different*
  /// member on their next login, never cleared by an absence of one).
  Future<void> unregisterCurrentDevice(String memberId) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await unregister(memberId: memberId, token: token);
  }
}
