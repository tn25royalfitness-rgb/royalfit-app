import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';

/// Thrown when the `member-login` edge function reports a login failure.
/// The [message] is the human-readable text returned by the backend and is
/// safe to show directly to the user.
class MemberLoginException implements Exception {
  MemberLoginException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Handles the custom member-ID + password login flow. This is NOT
/// Supabase Auth — it calls a dedicated edge function.
class AuthRepository {
  AuthRepository({required SupabaseClient supabaseClient})
      : _supabaseClient = supabaseClient;

  final SupabaseClient _supabaseClient;

  /// Calls the `member-login` edge function. Returns the full member JSON
  /// map on success. Throws [MemberLoginException] with the backend's
  /// error message on failure.
  Future<Map<String, dynamic>> login({
    required String memberId,
    required String password,
  }) async {
    try {
      final response = await _supabaseClient.functions.invoke(
        SupabaseConstants.memberLoginFunction,
        body: {
          'member_id': memberId,
          'password': password,
        },
      );

      final data = response.data;
      if (data is Map && data['member'] is Map) {
        return Map<String, dynamic>.from(data['member'] as Map);
      }

      if (data is Map && data['error'] != null) {
        throw MemberLoginException(data['error'].toString());
      }

      throw MemberLoginException('Login failed. Please try again.');
    } on FunctionException catch (e) {
      throw MemberLoginException(_messageFromFunctionException(e));
    } on MemberLoginException {
      rethrow;
    } catch (_) {
      throw MemberLoginException(
        'Network error. Please check your connection and try again.',
      );
    }
  }

  String _messageFromFunctionException(FunctionException e) {
    final details = e.details;
    if (details is Map && details['error'] != null) {
      return details['error'].toString();
    }
    if (details is String && details.isNotEmpty) {
      return details;
    }
    if (e.reasonPhrase != null && e.reasonPhrase!.isNotEmpty) {
      return e.reasonPhrase!;
    }
    return 'Login failed. Please try again.';
  }
}
