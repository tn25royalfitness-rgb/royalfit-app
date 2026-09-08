import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';

/// Thrown for any portal data-fetch failure. [message] is safe to show
/// directly to the user.
class PortalException implements Exception {
  PortalException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One streamed chunk of the AI workout coach's reply.
class ChatChunk {
  const ChatChunk(this.delta);

  final String delta;
}

/// All read-only portal data: attendance, workouts, weekly report, diet,
/// reminders, fitness profile, and AI chat. Mirrors the same edge
/// functions / direct table reads the web app's member portal uses (see
/// PHASE_HANDOFF.md for the full contract reference).
class PortalRepository {
  PortalRepository({required SupabaseClient supabaseClient})
      : _supabaseClient = supabaseClient;

  final SupabaseClient _supabaseClient;

  Future<Map<String, dynamic>> _invoke(
    String function,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _supabaseClient.functions.invoke(
        function,
        body: body,
      );
      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw PortalException(data['error'].toString());
      }
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      throw PortalException('Unexpected response from server.');
    } on PortalException {
      rethrow;
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['error'] != null) {
        throw PortalException(details['error'].toString());
      }
      throw PortalException(e.reasonPhrase ?? 'Request failed.');
    } catch (_) {
      throw PortalException(
        'Network error. Please check your connection and try again.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchAttendance(
    String memberId, {
    int limit = 20,
  }) async {
    final data = await _invoke('member-attendance', {
      'member_id': memberId,
      'limit': limit,
    });
    return List<Map<String, dynamic>>.from(
      (data['attendance'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  /// Today's assigned workout (device-local date), or null if nothing is
  /// assigned for today - direct table read, `member_workouts` allows
  /// public SELECT via RLS, same pattern `fetchDietPlans` uses. Deliberately
  /// scoped to today only, not a history list: admins assign workouts weeks
  /// ahead via the repeat-weeks feature, and members were previously seeing
  /// (and completing) whichever workout happened to be furthest in the
  /// future instead of today's.
  Future<Map<String, dynamic>?> fetchTodayWorkout(String memberId) async {
    try {
      final now = DateTime.now();
      final today =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      return await _supabaseClient
          .from('member_workouts')
          .select()
          .eq('member_id', memberId)
          .eq('workout_date', today)
          .maybeSingle();
    } catch (_) {
      throw PortalException('Could not load today\'s workout.');
    }
  }

  /// Saves per-exercise progress - [exerciseProgress] maps each exercise's
  /// `"branch|name"` key to what the member actually logged (a rep count or
  /// a time held, e.g. "12" or "45 sec"). [allDone] is computed client-side
  /// (the server has no structured view of the markdown plan, only the
  /// parsed Flutter side does) and drives whether `completed_at` gets set
  /// or cleared.
  Future<Map<String, dynamic>> saveWorkoutProgress({
    required String memberId,
    required String workoutId,
    required Map<String, String> exerciseProgress,
    required bool allDone,
  }) async {
    final data = await _invoke('member-workout-complete', {
      'member_id': memberId,
      'workout_id': workoutId,
      'exercise_progress': exerciseProgress,
      'all_done': allDone,
    });
    return Map<String, dynamic>.from(data['workout'] as Map);
  }

  Future<Map<String, dynamic>> fetchReport(
    String memberId, {
    int weekOffset = 0,
    int weeks = 8,
  }) {
    return _invoke('member-report', {
      'member_id': memberId,
      'week_offset': weekOffset,
      'weeks': weeks,
    });
  }

  Future<List<Map<String, dynamic>>> fetchReminders(String memberId) async {
    final data = await _invoke('member-reminders', {'member_id': memberId});
    return List<Map<String, dynamic>>.from(
      (data['events'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  Future<Map<String, dynamic>> respondReminder({
    required String memberId,
    required String eventId,
    required bool done,
  }) async {
    final data = await _invoke('reminder-respond', {
      'member_id': memberId,
      'event_id': eventId,
      'action': done ? 'done' : 'rejected',
    });
    return Map<String, dynamic>.from(data['event'] as Map);
  }

  /// Every schedule set up for this member - admin-assigned ones included
  /// (read-only in the UI), member-created ones deletable. `reminder_type`
  /// is one of 'water'/'meal'/'workout'/'custom'.
  Future<List<Map<String, dynamic>>> fetchMyReminderSchedules(String memberId) async {
    final data = await _invoke('member-reminder-list', {'member_id': memberId});
    return List<Map<String, dynamic>>.from(
      (data['schedules'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  Future<void> createReminderSchedule({
    required String memberId,
    required String reminderType,
    required String title,
    String? message,
    required String timeOfDay,
    required List<int> daysOfWeek,
  }) async {
    await _invoke('member-reminder-create', {
      'member_id': memberId,
      'reminder_type': reminderType,
      'title': title,
      'message': message,
      'time_of_day': timeOfDay,
      'days_of_week': daysOfWeek,
    });
  }

  Future<void> deleteReminderSchedule({
    required String memberId,
    required String scheduleId,
  }) async {
    await _invoke('member-reminder-delete', {
      'member_id': memberId,
      'schedule_id': scheduleId,
    });
  }

  /// Active diet plans for the member, each with its `items` list attached
  /// under the `items` key (direct table reads, both tables allow public
  /// SELECT via RLS — no edge function needed).
  Future<List<Map<String, dynamic>>> fetchDietPlans(String memberId) async {
    try {
      final plans = await _supabaseClient
          .from('diet_plans')
          .select()
          .eq('member_id', memberId)
          .eq('is_active', true)
          .order('start_date', ascending: false);

      final result = <Map<String, dynamic>>[];
      for (final plan in List<Map<String, dynamic>>.from(plans)) {
        final items = await _supabaseClient
            .from('diet_plan_items')
            .select()
            .eq('diet_plan_id', plan['id'] as String)
            .order('sort_order');
        result.add({...plan, 'items': List<Map<String, dynamic>>.from(items)});
      }
      return result;
    } catch (_) {
      throw PortalException('Could not load diet plans.');
    }
  }

  Future<Map<String, dynamic>?> fetchFitnessProfile(String memberId) async {
    try {
      return await _supabaseClient
          .from('member_fitness_profiles')
          .select()
          .eq('member_id', memberId)
          .maybeSingle();
    } catch (_) {
      throw PortalException('Could not load your fitness profile.');
    }
  }

  Future<void> saveFitnessProfile({
    required String memberId,
    required String fitnessGoal,
    required bool alcoholConsumption,
    required String dietType,
    required String physicalIssues,
    required String activityLevel,
    required String sex,
  }) async {
    try {
      await _supabaseClient.from('member_fitness_profiles').insert({
        'member_id': memberId,
        'fitness_goal': fitnessGoal,
        'alcohol_consumption': alcoholConsumption,
        'diet_type': dietType,
        'physical_issues': physicalIssues,
        'activity_level': activityLevel,
        'sex': sex,
      });
    } catch (_) {
      throw PortalException('Could not save your fitness profile.');
    }
  }

  /// Lists progress photos from the `member-photos` storage bucket, path
  /// `transformations/{memberId}/...` - matches the web app's
  /// `transformationPhotosService`/`TransformationPhotos.tsx` convention
  /// exactly, so photos uploaded from either app show up in both. There's
  /// no database table involved, just Storage.
  Future<List<Map<String, dynamic>>> fetchProgressPhotos(String memberId) async {
    try {
      final files = await _supabaseClient.storage
          .from('member-photos')
          .list(path: 'transformations/$memberId');

      final photos = files
          .where((f) => f.name != '.emptyFolderPlaceholder')
          .map((f) {
        final path = 'transformations/$memberId/${f.name}';
        final url =
            _supabaseClient.storage.from('member-photos').getPublicUrl(path);
        return {
          'name': f.name,
          'url': url,
          'created_at': f.createdAt,
        };
      }).toList();

      photos.sort((a, b) =>
          (a['created_at'] as String? ?? '').compareTo(b['created_at'] as String? ?? ''));
      return photos;
    } catch (_) {
      throw PortalException('Could not load progress photos.');
    }
  }

  /// Uploads via the `member-photo-upload` edge function rather than
  /// `storage.uploadBinary` directly - the `member-photos` bucket's only
  /// INSERT policy requires an authenticated admin Supabase Auth session
  /// (`has_role(auth.uid(),'admin')`), which this anon-key app never has, so
  /// a direct client upload is always rejected. The edge function uses the
  /// service-role key to bypass that, after verifying the member exists.
  /// [kind] is 'transformation' (progress photos) or 'food' (Phase 8 meal
  /// photos) - both share this bucket, in separate top-level folders.
  Future<String> uploadPhoto({
    required String memberId,
    required Uint8List bytes,
    required String extension,
    String kind = 'transformation',
  }) async {
    final data = await _invoke('member-photo-upload', {
      'member_id': memberId,
      'kind': kind,
      'file_base64': base64Encode(bytes),
      'extension': extension,
    });
    return data['url'] as String;
  }

  Future<void> uploadProgressPhoto({
    required String memberId,
    required Uint8List bytes,
    required String extension,
  }) {
    return uploadPhoto(memberId: memberId, bytes: bytes, extension: extension);
  }

  Future<List<Map<String, dynamic>>> fetchChatHistory(String memberId) async {
    try {
      final rows = await _supabaseClient
          .from('chat_messages')
          .select('role, content, created_at')
          .eq('member_id', memberId)
          .order('created_at', ascending: true)
          .limit(50);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      throw PortalException('Could not load chat history.');
    }
  }

  Future<void> saveChatMessage({
    required String memberId,
    required String role,
    required String content,
  }) async {
    try {
      await _supabaseClient.from('chat_messages').insert({
        'member_id': memberId,
        'role': role,
        'content': content,
      });
    } catch (_) {
      // Chat history is best-effort - never let a save failure break the
      // conversation the member is having right now.
    }
  }

  /// Streams the `workout-chat` edge function's Server-Sent Events response,
  /// yielding each incremental text delta. There is no native Dart SSE
  /// client for Supabase edge functions, so this parses the OpenAI-style
  /// `data: {...}\n\n` stream by hand — same parsing the web app's
  /// `MemberWorkoutChat.tsx` does client-side.
  Stream<ChatChunk> streamWorkoutChat({
    required List<Map<String, String>> messages,
    required Map<String, dynamic> memberProfile,
    Map<String, dynamic>? fitnessProfile,
    List<Map<String, String>> recentWorkouts = const [],
  }) async* {
    final uri = Uri.parse(
      '${SupabaseConstants.url}/functions/v1/workout-chat',
    );
    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Authorization'] = 'Bearer ${SupabaseConstants.anonKey}'
      ..body = jsonEncode({
        'messages': messages,
        'memberProfile': memberProfile,
        'fitnessProfile': fitnessProfile,
        'recentWorkouts': recentWorkouts,
      });

    final http.StreamedResponse response;
    try {
      response = await http.Client().send(request);
    } catch (_) {
      throw PortalException(
        'Could not reach the AI coach. Please try again.',
      );
    }

    if (response.statusCode == 429) {
      throw PortalException('Rate limit exceeded. Please try again later.');
    }
    if (response.statusCode == 402) {
      throw PortalException(
        'AI service credits exhausted. Please contact the gym admin.',
      );
    }
    if (response.statusCode >= 400) {
      throw PortalException('AI service temporarily unavailable.');
    }

    var buffer = '';
    await for (final bytes in response.stream) {
      buffer += utf8.decode(bytes, allowMalformed: true);

      var newlineIndex = buffer.indexOf('\n');
      while (newlineIndex != -1) {
        var line = buffer.substring(0, newlineIndex);
        buffer = buffer.substring(newlineIndex + 1);
        if (line.endsWith('\r')) line = line.substring(0, line.length - 1);

        if (line.isEmpty || line.startsWith(':')) {
          newlineIndex = buffer.indexOf('\n');
          continue;
        }
        if (!line.startsWith('data: ')) {
          newlineIndex = buffer.indexOf('\n');
          continue;
        }

        final jsonStr = line.substring(6).trim();
        if (jsonStr == '[DONE]') return;

        try {
          final parsed = jsonDecode(jsonStr);
          final content =
              parsed['choices']?[0]?['delta']?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            yield ChatChunk(content);
          }
        } catch (_) {
          // Incomplete JSON split across a read boundary - put the line
          // back and wait for more bytes, same recovery the web parser uses.
          buffer = '$line\n$buffer';
          break;
        }

        newlineIndex = buffer.indexOf('\n');
      }
    }
  }
}
