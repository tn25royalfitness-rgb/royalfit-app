# Royal Fitness Member App — Phase Handoff

This document lets a different AI assistant (or the same one, in a fresh session) safely continue this Flutter app without repeating already-solved problems. Read this whole file before touching code.

> **2026 rebrand note:** this codebase was forked from the original Real Fitness / BlackSquad app (`https://github.com/realfitness2020dec-collab/BlackSquad-App`) and re-pointed at a brand-new, independent Supabase project (`ufpaeaondevdhuqnuaqe`) and Firebase project (`royal-fit-b6460`) for a different gym business, Royal Fitness (Tiruvannamalai). Everything below describes the current app's architecture and is still accurate — only the brand name, package identifiers, and backend project changed. The rest of this document's "do not create a new Supabase project" guidance refers to *this* project going forward, not the original Real Fitness one.
>
> Known gap from the fork: the web app repo this Flutter app shipped alongside only had 5 of the ~17 edge functions this app calls (diet plans, food/water logging, member-created reminders, device-key punch-in, and push subscriptions are missing their backend). Tables exist (see the new project's baseline migration) but the edge functions that should own most of the writes need to be located from the original repo or rewritten before those features work.

Repo: `https://github.com/tn25royalfitness-rgb/royalfit-app.git` (branch `main`).
Backend: Royal Fitness's own Supabase project (`ufpaeaondevdhuqnuaqe`) — **do not create a new Supabase project**, and treat `supabase/migrations` and `supabase/functions` in the sibling web app repo as the source of truth for schema/contracts.

## Status: all planned phases (0 through 5) are implemented and committed

Everything below is written and locally committed to `royalfitness_app`. As of this writing the last push to GitHub may still be pending (this environment's `git push` hangs on a Git Credential Manager prompt it can't complete non-interactively — the owner has been pushing manually). **Check `git log`/GitHub before assuming anything past a given commit hash is live**, and check the Actions tab for the actual CI result of the latest pushed commit before building further on top of it.

- **Phase 0 + 1** — bootstrap, member-ID/password login, access gate. CI-verified working on a real device.
- **Phase 1.5** — real Google Sign-In (`features/auth/data/auth_repository.dart`'s `signInWithGoogle()`, `features/auth/presentation/complete_profile_screen.dart`). **Not fully live yet** — needs `SupabaseConstants.googleServerClientId` filled in and an Android OAuth client registered in Google Cloud Console (see "Open manual steps" below).
- **Phase 2** — full read-only portal: attendance, workouts, weekly report (chart), diet plan, reminders, AI coach chat. `features/portal/`.
- **Phase 3** — device-key punch-in: hand-written Android Keystore + BiometricPrompt signing (`android/app/src/main/kotlin/.../DeviceKeySigner.kt`, `MainActivity.kt`), `features/punch/`. Backend: `device-key-register`/`device-punch-challenge`/`attendance-punch-mobile` edge functions + `device_signing_keys`/`device_punch_challenges` tables in the web app repo. **CI only proves this compiles** — the actual biometric-signing flow can only be verified by testing on a real device.
- **Phase 4** — FCM push. `firebase_core`/`firebase_messaging` wired with a real `google-services.json` (already committed at `android/app/google-services.json` — this file is not sensitive, it's client identifiers only). `features/push/data/push_repository.dart` registers the device's FCM token via `push-subscribe`. **Backend needs two Supabase secrets before FCM sends actually work**: `FIREBASE_PROJECT_ID` and `FIREBASE_SERVICE_ACCOUNT_JSON` (a Firebase service account private key — sensitive, ask the owner whether they've set it; never ask them to paste it into chat).
- **Phase 5** — full-screen reminder takeover (`core/notifications/local_notifications.dart`'s `showReminder()`, `features/portal/presentation/reminder_response_screen.dart`) and progress photos (`features/portal/presentation/progress_photos_screen.dart`, Storage bucket `member-photos`). Depends on Phase 4's FCM plumbing actually being configured to receive the `type: 'reminder'` data payload that triggers it.

## Hard constraints — learned the expensive way, read before writing any code

1. **No local Flutter or Android Studio exists anywhere in this workflow** — not on the owner's machine, not in any AI coding environment working on this repo. `.github/workflows/build-apk.yml` (push to `main` → GitHub Actions → downloadable APK artifact) is the *only* way to know whether code compiles. There is no faster feedback loop. Budget for round trips: push, wait ~2-4 min, check the Actions tab, read the log if red, fix, repeat.
2. **No code generation, ever.** No `freezed`, `json_serializable`, `riverpod_generator`, or any `build_runner`-dependent package. Hand-written Dart only, plain Riverpod `Provider`s, manual `fromJson`/`toJson` where models exist (most data is passed around as raw `Map<String, dynamic>`, which is the established pattern here — don't introduce typed models as a "cleanup", it'd be inconsistent with everything else).
3. **Known dependency landmine**: `flutter_secure_storage` 9.x pulls in a broken `jni` transitive dependency that fails the Android Gradle build, and even avoiding that, the plugin's own module hardcodes an internal `compileSdk` of 33 that breaks against newer AndroidX deps. This is why session storage uses plain `shared_preferences`. Any new package touching native crypto/secure-storage/signing should be checked against its full transitive dependency tree before committing to it — or written by hand as platform code instead (see `DeviceKeySigner.kt`, deliberately not a third-party plugin for this reason).
4. **`compileSdk` is pinned to `36`** in `android/app/build.gradle.kts` (not `flutter.compileSdkVersion`, which resolved to a stale `33` in this CI image). **`minSdk` is pinned to `maxOf(23, flutter.minSdkVersion)`** (Keystore + BiometricPrompt need 23+). Don't revert either without re-verifying in CI.
5. The CI-built APK is release-mode but not properly signed for Play Store (default debug/CI signing) — sideload-only today. Google Sign-In's Android OAuth client and any future Play Store signing config need the SHA-1 of whatever key actually signs the installed APK.
6. **Native/hardware-dependent code (Phase 3's biometric signing, Phase 5's full-screen-intent-over-lockscreen) cannot be verified by CI at all** — CI only proves it compiles. Both need real-device testing, and full-screen-intent behavior specifically varies by OEM battery-optimization settings (Samsung/Xiaomi are notably aggressive) in ways no amount of correct code can fully control.
7. **Git push from an automated/sandboxed shell in this environment hangs on a Git Credential Manager sign-in prompt it can't complete.** Every commit in this project's history past a certain point was pushed manually by the owner running `git push` themselves in their own terminal. Don't assume a local commit is on GitHub — check.

## Backend reference

All member auth is **custom**, not Supabase Auth: member_id + bcrypt-hashed password checked by a service-role edge function (`member-login`) against the `members` table directly. There is no member row in `auth.users` *unless* they've signed in with Google (Phase 1.5 does briefly create/reuse a Supabase Auth session to read the Google account's email, then immediately signs it out locally — see `signInWithGoogle()`).

### `members` table (see `supabase/migrations/` in the web app repo for full history)

```
id uuid PK, member_id text UNIQUE (e.g. "RF0001"), full_name text, phone text,
email text NULL, address text NULL, date_of_birth date NULL,
height numeric NULL, weight numeric NULL, photo_url text NULL,
password text NULL (bcrypt hash, or legacy plaintext auto-upgraded on next login),
package_id uuid NULL FK gym_packages, package_start_date date NULL, package_end_date date NULL,
is_active boolean DEFAULT true,
client_type text CHECK IN ('gym','online_pt','hybrid') DEFAULT 'gym',
approval_status text CHECK IN ('pending','approved') DEFAULT 'approved',
created_at, updated_at timestamptz
```
RLS: public `SELECT`, admin-only write. Safe to query directly from the Flutter client with the anon key.

### Edge functions (all `POST`, JSON, CORS `*`, via `supabase.functions.invoke(name, body: {...})`)

| Function | Request | Response (200) | Notes |
|---|---|---|---|
| `member-login` | `{member_id, password}` | `{member: {...}}` | 400/404/401/403 various |
| `member-self-register` | `{email, full_name, phone, address, weight, height, fitness_goal, smoking, diet_type}` | `{member: {...}}` | Used by Complete Profile after first Google sign-in |
| `member-attendance` | `{member_id, limit?}` | `{attendance: [...]}` | |
| `member-workouts` | `{member_id, limit?}` | `{workouts: [...]}` | |
| `member-workout-complete` | `{member_id, workout_id}` | `{success, workout}` | |
| `member-report` | `{member_id, week_offset?, weeks?}` | `{period, components, score, trend}` | |
| `member-reminders` | `{member_id}` | `{events: [...]}` | Today's IST-day window |
| `reminder-respond` | `{member_id, event_id, action}` | `{success, event}` | action: 'done'\|'rejected' |
| `push-subscribe` | `{member_id, action, subscription?, platform?, fcm_token?, user_agent?}` | `{success}` | `platform` omitted/`'web'` = Web Push shape; `'android'`/`'ios'` = bare `fcm_token`. 403 if `client_type==='gym'` |
| `attendance-punch` | WebAuthn assertion + geo (web app only, not used by Flutter) | | |
| `device-key-register` | `{member_id, public_key, device_label?}` | `{success, key_id}` | Mobile equivalent of WebAuthn registration |
| `device-punch-challenge` | `{member_id}` | `{challenge, has_key}` | |
| `attendance-punch-mobile` | `{member_id, action, key_id, signature, location}` | `{success, attendance, distance_m}` | Verifies Keystore EC signature (DER→raw conversion happens server-side) |
| `workout-chat` | `{messages, memberProfile, fitnessProfile, recentWorkouts}` | raw SSE stream | Hand-parsed in `portal_repository.dart`'s `streamWorkoutChat()` |

`reminders-dispatch` is cron-only (needs `x-cron-secret`), never called from the app.

### Direct table/storage reads (RLS allows public SELECT, no edge function)

`diet_plans`/`diet_plan_items`, `gym_packages` (joined into `member-login`'s response), `monster_of_week` (published only), `member_fitness_profiles`, `chat_messages` (all `FOR ALL USING (true)`, client reads/writes directly). Storage bucket `member-photos`, path `transformations/{memberId}/{timestamp}.{ext}`, public URLs — no table involved.

## Open manual steps (need the account owner, not an AI)

1. **Google Sign-In**: `SupabaseConstants.googleServerClientId` is still empty. Needs the Web OAuth Client ID Supabase's Google provider already trusts, plus a new Android OAuth client (package `Royal.fit`, SHA-1 of the actual signing cert) registered in the same Google Cloud project.
2. **FCM secrets**: confirm `FIREBASE_PROJECT_ID` and `FIREBASE_SERVICE_ACCOUNT_JSON` are set as Supabase secrets (Edge Functions → Manage secrets). Without them, `sendFcmNotification` in `_shared/push.ts` fails closed (logs an error, doesn't throw) — pushes silently don't send rather than crashing anything.
3. **Play Store signing**: `android/app/build.gradle.kts` still signs release builds with the debug key. Needed before any real distribution beyond sideloading.

## Verification

Every change: push to `main` (owner does this manually - see constraint 7), open the repo's Actions tab, read the failure log if red, fix, push again. For Phase 3/5's native-only behavior, CI going green is necessary but not sufficient - it still needs a real-device test.
