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

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image(image: AssetImage('assets/logo.png'), width: 96, height: 96),
            SizedBox(height: 24),
            Text(
              'Royal Fitness',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Color(0xFFD4AF37)),
          ],
        ),
      ),
    );
  }
}
