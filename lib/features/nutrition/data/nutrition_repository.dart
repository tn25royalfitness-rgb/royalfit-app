import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown for any nutrition logging failure. [message] is safe to show
/// directly to the user.
class NutritionException implements Exception {
  NutritionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Food/water logging with AI-estimated nutrition (Phase 8). Mirrors the
/// same edge-function-per-write pattern every other member-facing feature
/// in this app uses - `member-photo-upload` for the photo, `analyze-food`
/// for the estimate + save.
class NutritionRepository {
  NutritionRepository({required SupabaseClient supabaseClient})
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
        throw NutritionException(data['error'].toString());
      }
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      throw NutritionException('Unexpected response from server.');
    } on NutritionException {
      rethrow;
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['error'] != null) {
        throw NutritionException(details['error'].toString());
      }
      throw NutritionException(e.reasonPhrase ?? 'Request failed.');
    } catch (_) {
      throw NutritionException(
        'Network error. Please check your connection and try again.',
      );
    }
  }

  Future<String> _uploadFoodPhoto({
    required String memberId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final data = await _invoke('member-photo-upload', {
      'member_id': memberId,
      'kind': 'food',
      'file_base64': base64Encode(bytes),
      'extension': extension,
    });
    return data['url'] as String;
  }

  /// Uploads the photo, then analyzes it. Returns the saved
  /// `nutrition_logs` row (with the AI's calorie/macro/vitamin estimate, or
  /// nulls + an explanatory `ai_notes` if the estimate itself failed - the
  /// entry is still saved either way).
  Future<Map<String, dynamic>> logFood({
    required String memberId,
    required String foodName,
    required String quantity,
    required Uint8List photoBytes,
    required String extension,
    String? reminderEventId,
  }) async {
    final photoUrl = await _uploadFoodPhoto(
      memberId: memberId,
      bytes: photoBytes,
      extension: extension,
    );

    final data = await _invoke('analyze-food', {
      'member_id': memberId,
      'entry_type': 'food',
      'food_name': foodName,
      'quantity': quantity,
      'photo_url': photoUrl,
      'reminder_event_id': reminderEventId,
    });

    return Map<String, dynamic>.from(data['entry'] as Map);
  }

  Future<Map<String, dynamic>> logWater({
    required String memberId,
    required String quantity,
    String? reminderEventId,
  }) async {
    final data = await _invoke('analyze-food', {
      'member_id': memberId,
      'entry_type': 'water',
      'quantity': quantity,
      'reminder_event_id': reminderEventId,
    });
    return Map<String, dynamic>.from(data['entry'] as Map);
  }

  /// Sum of calories logged today (device-local calendar day), for showing
  /// progress against the calculated calorie target. Direct table read -
  /// `nutrition_logs` allows public SELECT via RLS, same as every other
  /// member-facing table.
  Future<int> fetchTodayCalories(String memberId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toUtc();

      final rows = await _supabaseClient
          .from('nutrition_logs')
          .select('calories')
          .eq('member_id', memberId)
          .eq('entry_type', 'food')
          .gte('logged_at', startOfDay.toIso8601String());

      num total = 0;
      for (final row in List<Map<String, dynamic>>.from(rows)) {
        total += (row['calories'] as num?) ?? 0;
      }
      return total.round();
    } catch (_) {
      return 0;
    }
  }
}
