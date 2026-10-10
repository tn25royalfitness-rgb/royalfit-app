import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router/app_router.dart';
import '../domain/member.dart';

/// Shown briefly on launch while the stored session (if any) is
/// revalidated against the live `members` row.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  // True once biometric unlock was required but failed / was cancelled; the
  // spinner is then replaced by Unlock / Use password buttons (no auto-loop).
  bool _showUnlockPrompt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSession());
  }

  Future<void> _checkSession() async {
    final sessionRepository = ref.read(sessionRepositoryProvider);
    final storedMember = await sessionRepository.readStoredSession();

    if (!mounted) return;

    if (storedMember == null) {
      context.go('/login');
      return;
    }

    // Optional fingerprint / face unlock - only when the member opted in and
    // the device still supports it. Otherwise the flow is unchanged.
    final biometricLock = ref.read(biometricLockProvider);
    if (await biometricLock.isEnabled() && await biometricLock.isSupported()) {
      if (!mounted) return;
      final unlocked = await biometricLock.authenticate();
      if (!mounted) return;
      if (!unlocked) {
        setState(() {
          _showUnlockPrompt = true;
        });
        return;
      }
    }

    if (!mounted) return;

    final result = await sessionRepository.revalidate(storedMember);

    if (!mounted) return;

    if (result.status == AccessStatus.ok) {
      context.go('/home', extra: result.member);
    } else {
      context.go(
        '/access-restricted',
        extra: AccessRestrictedArgs(status: result.status, member: result.member),
      );
    }
  }

  void _retryUnlock() {
    setState(() {
      _showUnlockPrompt = false;
    });
    _checkSession();
  }

  Future<void> _usePasswordInstead() async {
    await ref.read(sessionRepositoryProvider).clearSession();
    await ref.read(biometricLockProvider).setEnabled(false);
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Image(
              image: AssetImage('assets/logo.png'),
              width: 96,
              height: 96,
            ),
            const SizedBox(height: 24),
            const Text(
              'Royal Fitness',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            if (_showUnlockPrompt) ...[
              SizedBox(
                width: 240,
                child: ElevatedButton(
                  onPressed: _retryUnlock,
                  child: const Text('Unlock'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _usePasswordInstead,
                child: const Text('Use password instead'),
              ),
            ] else
              const CircularProgressIndicator(color: Color(0xFFD4AF37)),
          ],
        ),
      ),
    );
  }
}
