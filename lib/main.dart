import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_constants.dart';
import 'core/notifications/local_notifications.dart';
import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/session/domain/member.dart';

/// Every push this app sends is a data-only FCM message (see
/// `_shared/push.ts`) precisely so this function - not the OS - decides how
/// to display it, which is what makes the full-screen reminder takeover
/// possible. Must be a top-level (or static) function since the platform
/// re-invokes this as the isolate entry point for background/terminated
/// delivery, so it can't close over any app state.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await LocalNotifications.initialize();
  await _showForData(message.data);
}

Future<void> _showForData(Map<String, dynamic> data) async {
  final title = data['title'] as String? ?? 'Royal Fitness';
  final body = data['body'] as String?;

  if (data['type'] == 'reminder') {
    final eventId = data['event_id'] as String?;
    if (eventId == null || eventId.isEmpty) return;
    final reminderType = data['reminder_type'] as String? ?? 'custom';
    await LocalNotifications.showReminder(
      eventId: eventId,
      reminderType: reminderType,
      title: title,
      body: body,
    );
  } else {
    await LocalNotifications.show(title: title, body: body);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConstants.url,
    anonKey: SupabaseConstants.anonKey,
  );

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  LocalNotifications.onReminderTapped = (payload) {
    if (payload.reminderType == 'meal' || payload.reminderType == 'water') {
      appRouter.push(
        '/food-log',
        extra: {
          'reminder_event_id': payload.eventId,
          'entry_type': payload.reminderType,
        },
      );
    } else {
      appRouter.push('/reminder-response', extra: payload.eventId);
    }
  };
  await LocalNotifications.initialize();

  // Foreground messages never get an automatic system notification from
  // FCM regardless of payload shape - always shown manually.
  FirebaseMessaging.onMessage.listen((message) => _showForData(message.data));

  runApp(const ProviderScope(child: RoyalFitnessApp()));
}

class RoyalFitnessApp extends StatelessWidget {
  const RoyalFitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return _AppLifecycleRevalidator(
      child: MaterialApp.router(
        title: 'Royal Fitness',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routerConfig: appRouter,
      ),
    );
  }
}

/// Re-checks the stored member session's access status every time the app
/// is resumed from the background (not just at launch), mirroring the web
/// app's behavior of re-validating access whenever the user returns.
class _AppLifecycleRevalidator extends ConsumerStatefulWidget {
  const _AppLifecycleRevalidator({required this.child});

  final Widget child;

  @override
  ConsumerState<_AppLifecycleRevalidator> createState() =>
      _AppLifecycleRevalidatorState();
}

class _AppLifecycleRevalidatorState
    extends ConsumerState<_AppLifecycleRevalidator>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _revalidateSession();
    }
  }

  Future<void> _revalidateSession() async {
    final sessionRepository = ref.read(sessionRepositoryProvider);
    final storedMember = await sessionRepository.readStoredSession();
    if (storedMember == null) return;

    final result = await sessionRepository.revalidate(storedMember);

    if (result.status == AccessStatus.ok) {
      appRouter.go('/home', extra: result.member);
    } else {
      appRouter.go(
        '/access-restricted',
        extra: AccessRestrictedArgs(status: result.status, member: result.member),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
