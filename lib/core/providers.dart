import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/nutrition/data/nutrition_repository.dart';
import '../features/portal/data/portal_repository.dart';
import '../features/punch/data/punch_repository.dart';
import '../features/push/data/push_repository.dart';
import '../features/session/data/session_repository.dart';

/// Plain Riverpod providers (no code generation) shared across the app.

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(
    supabaseClient: ref.watch(supabaseClientProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(supabaseClient: ref.watch(supabaseClientProvider));
});

final portalRepositoryProvider = Provider<PortalRepository>((ref) {
  return PortalRepository(supabaseClient: ref.watch(supabaseClientProvider));
});

final punchRepositoryProvider = Provider<PunchRepository>((ref) {
  return PunchRepository(supabaseClient: ref.watch(supabaseClientProvider));
});

final pushRepositoryProvider = Provider<PushRepository>((ref) {
  return PushRepository(supabaseClient: ref.watch(supabaseClientProvider));
});

final nutritionRepositoryProvider = Provider<NutritionRepository>((ref) {
  return NutritionRepository(supabaseClient: ref.watch(supabaseClientProvider));
});
