import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../domain/member.dart';

/// Result of a session revalidation pass: the freshly-computed status plus
/// whichever member data (fresh, or last-known on network failure) it was
/// computed from.
class RevalidationResult {
  const RevalidationResult({required this.status, required this.member});

  final AccessStatus status;
  final Map<String, dynamic>? member;
}

/// Handles persisting the member session locally and revalidating it
/// against the live `members` row.
class SessionRepository {
  SessionRepository({
    required SupabaseClient supabaseClient,
  }) : _supabaseClient = supabaseClient;

  final SupabaseClient _supabaseClient;

  static const String _sessionKey = SupabaseConstants.memberSessionStorageKey;

  /// Persists the full member JSON to local app-private storage.
  Future<void> saveSession(Map<String, dynamic> member) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(member));
  }

  /// Reads the last stored member session, if any. Returns null if nothing
  /// is stored, or if the stored value is unparsable.
  Future<Map<String, dynamic>?> readStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Clears the stored session (logout).
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  /// Fetches the live member row by id. The `members` table allows public
  /// SELECT via RLS, so no special auth is required.
  Future<Map<String, dynamic>?> fetchFreshMember(String id) async {
    final result = await _supabaseClient
        .from(SupabaseConstants.membersTable)
        .select()
        .eq('id', id)
        .maybeSingle();
    return result;
  }

  /// Re-fetches the live member row, recomputes [AccessStatus], and
  /// re-persists the refreshed data. If the network fetch fails, falls
  /// back to computing the status from the last-known stored data instead
  /// of hard-failing / locking the user out on a transient error.
  Future<RevalidationResult> revalidate(
    Map<String, dynamic> storedMember,
  ) async {
    final id = storedMember['id'] as String?;
    if (id == null || id.isEmpty) {
      return RevalidationResult(
        status: computeAccessStatus(storedMember),
        member: storedMember,
      );
    }

    Map<String, dynamic>? freshMember;
    bool fetchFailed = false;
    try {
      freshMember = await fetchFreshMember(id);
    } catch (_) {
      fetchFailed = true;
    }

    if (fetchFailed) {
      // Transient/network error: fall back to last-known data rather than
      // locking the user out.
      return RevalidationResult(
        status: computeAccessStatus(storedMember),
        member: storedMember,
      );
    }

    // Fetch succeeded (freshMember may be null if the row was deleted).
    if (freshMember != null) {
      await saveSession(freshMember);
    }
    return RevalidationResult(
      status: computeAccessStatus(freshMember),
      member: freshMember,
    );
  }
}
