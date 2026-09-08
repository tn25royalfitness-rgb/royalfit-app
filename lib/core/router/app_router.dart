import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/nutrition/presentation/food_log_screen.dart';
import '../../features/portal/presentation/portal_home_screen.dart';
import '../../features/portal/presentation/reminder_response_screen.dart';
import '../../features/session/domain/member.dart';
import '../../features/session/presentation/access_restricted_screen.dart';
import '../../features/session/presentation/splash_screen.dart';

/// Extra data passed to the `/access-restricted` route.
class AccessRestrictedArgs {
  const AccessRestrictedArgs({required this.status, this.member});

  final AccessStatus status;
  final Map<String, dynamic>? member;
}

/// Global router instance. Exposed at module scope (rather than only via
/// `context.go`) so that non-widget code — such as the app-lifecycle
/// revalidation observer in `main.dart` — can trigger navigation directly.
final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/access-restricted',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is AccessRestrictedArgs) {
          return AccessRestrictedScreen(
            status: extra.status,
            member: extra.member,
          );
        }
        return const AccessRestrictedScreen(
          status: AccessStatus.notFound,
          member: null,
        );
      },
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) {
        final extra = state.extra;
        final member = extra is Map<String, dynamic> ? extra : null;
        return PortalHomeScreen(initialMember: member);
      },
    ),
    GoRoute(
      path: '/reminder-response',
      builder: (context, state) {
        final eventId = state.extra is String ? state.extra as String : '';
        return ReminderResponseScreen(eventId: eventId);
      },
    ),
    GoRoute(
      path: '/food-log',
      builder: (context, state) {
        final extra = state.extra;
        final args = extra is Map<String, dynamic> ? extra : const <String, dynamic>{};
        return FoodLogScreen(
          memberId: args['member_id'] as String?,
          reminderEventId: args['reminder_event_id'] as String?,
          initialEntryType: args['entry_type'] as String? ?? 'food',
        );
      },
    ),
  ],
);
