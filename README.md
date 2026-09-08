# Royal Fitness — Member App (Flutter)

Companion Android app for Royal Fitness gym members: fingerprint punch-in, workout/diet plans, reminders (including full-screen alarm-style reminder popups, not possible in the web PWA), and reports.

This is a separate codebase from the main web app, but talks to the same Supabase backend.

## Building

No local Flutter/Android Studio install required — every push to `main` is built automatically by GitHub Actions (see `.github/workflows/build-apk.yml`). After a workflow run finishes, download the installable APK from that run's **Artifacts** section (Actions tab → latest run → `royalfitness-app-release-apk`).
