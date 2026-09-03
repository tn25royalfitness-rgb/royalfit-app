import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../data/portal_repository.dart';

/// Full-screen "respond to a reminder" view, reached either by tapping a
/// full-screen-intent reminder notification or (on a locked device) via the
/// takeover itself. Deliberately self-contained - it re-derives everything
/// it needs from the stored session and [eventId] rather than depending on
/// in-memory app state, since it may be the very first screen shown after a
/// cold start from a locked-screen notification.
class ReminderResponseScreen extends ConsumerStatefulWidget {
  const ReminderResponseScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<ReminderResponseScreen> createState() =>
      _ReminderResponseScreenState();
}

class _ReminderResponseScreenState
    extends ConsumerState<ReminderResponseScreen> {
  bool _busy = false;
  String? _errorMessage;
  bool _responded = false;

  Future<void> _respond(bool done) async {
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final member =
          await ref.read(sessionRepositoryProvider).readStoredSession();
      final memberId = member?['id'] as String?;
      if (memberId == null) {
        throw PortalException('Please log in again.');
      }

      await ref.read(portalRepositoryProvider).respondReminder(
            memberId: memberId,
            eventId: widget.eventId,
            done: done,
          );

      if (!mounted) return;
      setState(() => _responded = true);
    } on PortalException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _responded ? Icons.check_circle : Icons.notifications_active,
                  color: const Color(0xFFD4AF37),
                  size: 72,
                ),
                const SizedBox(height: 24),
                Text(
                  _responded ? 'Thanks!' : 'Reminder',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (!_responded)
                  const Text(
                    "It's time - have you done this?",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFD4AF37)),
                  ),
                ],
                const SizedBox(height: 32),
                if (!_responded) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : () => _respond(false),
                          child: const Text('Not Now'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _busy ? null : () => _respond(true),
                          child: _busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('Back to Royal Fitness'),
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
