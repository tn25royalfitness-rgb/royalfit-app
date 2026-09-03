/// Supabase project constants for the Royal Fitness member app.
///
/// Points at Royal Fitness's own Supabase project — separate from the
/// original Real Fitness / BlackSquad backend. The anon/publishable key is
/// safe to ship client-side by design (it is subject to RLS policies
/// enforced server-side).
///
class SupabaseConstants {
  SupabaseConstants._();

  static const String url = 'https://ufpaeaondevdhuqnuaqe.supabase.co';

  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVmcGFlYW9uZGV2ZGh1cW51YXFlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgzNjUxMTQsImV4cCI6MjEwMzk0MTExNH0.H4JtgGq6BFWfIm_13TNWQP8u3OAN-V1XzqLfnYsAbp0';

  /// Name of the edge function used for the custom member-ID + password
  /// login flow (not Supabase Auth).
  static const String memberLoginFunction = 'member-login';

  /// Table used for session revalidation (public SELECT via RLS).
  static const String membersTable = 'members';

  /// Local-storage key under which the full member JSON session is kept.
  static const String memberSessionStorageKey = 'member_session';
}
