/// Supabase project constants for the Royal Fitness member app.
///
/// Points at Royal Fitness's own Supabase project — separate from the
/// original Real Fitness / BlackSquad backend. The anon/publishable key is
/// safe to ship client-side by design (it is subject to RLS policies
/// enforced server-side).
///
/// TODO: `anonKey` below is a placeholder — replace it with the real
/// anon/publishable key from Supabase Dashboard -> Settings -> API for
/// project ufpaeaondevdhuqnuaqe before this app can log anyone in.
class SupabaseConstants {
  SupabaseConstants._();

  static const String url = 'https://ufpaeaondevdhuqnuaqe.supabase.co';

  static const String anonKey = 'REPLACE_WITH_ANON_PUBLISHABLE_KEY';

  /// Name of the edge function used for the custom member-ID + password
  /// login flow (not Supabase Auth).
  static const String memberLoginFunction = 'member-login';

  /// Table used for session revalidation (public SELECT via RLS).
  static const String membersTable = 'members';

  /// Local-storage key under which the full member JSON session is kept.
  static const String memberSessionStorageKey = 'member_session';
}
