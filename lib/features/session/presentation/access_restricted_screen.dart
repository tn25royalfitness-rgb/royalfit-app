import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../domain/member.dart';

class _StatusContent {
  const _StatusContent({
    required this.icon,
    required this.heading,
    required this.message,
  });

  final IconData icon;
  final String heading;
  final String message;
}

/// Shown instead of the portal when a member's access is not currently
/// allowed (pending approval, expired, deactivated, or not found).
class AccessRestrictedScreen extends ConsumerWidget {
  const AccessRestrictedScreen({
    super.key,
    required this.status,
    this.member,
  });

  final AccessStatus status;
  final Map<String, dynamic>? member;

  _StatusContent _contentFor(AccessStatus status) {
    switch (status) {
      case AccessStatus.noAppAccess:
        return const _StatusContent(
          icon: Icons.smartphone,
          heading: 'App Not Available',
          message:
              'This app is for Online PT members. Your membership is '
              'gym-only — contact the gym to upgrade if you\'d like access.',
        );
      case AccessStatus.pending:
        return const _StatusContent(
          icon: Icons.hourglass_top,
          heading: 'Awaiting Approval',
          message:
              'Your profile has been submitted. An admin needs to approve '
              'your account before you can access the app.',
        );
      case AccessStatus.expired:
        return const _StatusContent(
          icon: Icons.event_busy,
          heading: 'Membership Expired',
          message:
              'Your membership has expired. Please contact the gym to renew.',
        );
      case AccessStatus.deactivated:
        return const _StatusContent(
          icon: Icons.block,
          heading: 'Account Deactivated',
          message:
              'Your account has been deactivated. Please contact the gym.',
        );
      case AccessStatus.notFound:
        return const _StatusContent(
          icon: Icons.person_off,
          heading: 'Account Not Found',
          message:
              "We couldn't find your member account. Please log in again.",
        );
      case AccessStatus.ok:
        // Should not happen: callers only route here for non-ok statuses.
        return const _StatusContent(
          icon: Icons.check_circle,
          heading: 'Access Restricted',
          message: 'Please log in again.',
        );
    }
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final memberId = member?['id'] as String?;
    if (memberId != null) {
      // Must happen before clearing the session - stops this device from
      // receiving this member's reminder pushes now that they're logged out.
      await ref.read(pushRepositoryProvider).unregisterCurrentDevice(memberId);
    }
    await ref.read(sessionRepositoryProvider).clearSession();
    if (!context.mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = _contentFor(status);
    final memberId = member?['member_id'] as String?;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(content.icon, color: const Color(0xFFD4AF37), size: 72),
                const SizedBox(height: 24),
                Text(
                  content.heading,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  content.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                if (memberId != null && memberId.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Your Member ID: $memberId',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _handleLogout(context, ref),
                    child: const Text('Logout'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
