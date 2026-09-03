import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../nutrition/presentation/food_log_screen.dart';
import '../../punch/presentation/punch_screen.dart';
import 'attendance_screen.dart';
import 'chat_screen.dart';
import 'diet_screen.dart';
import 'progress_photos_screen.dart';
import 'report_screen.dart';
import 'reminders_screen.dart';
import 'workouts_screen.dart';

class _PortalTile {
  const _PortalTile({
    required this.icon,
    required this.label,
    required this.builder,
  });

  final IconData icon;
  final String label;
  final Widget Function(BuildContext context, Map<String, dynamic> member)
      builder;
}

final _portalTiles = <_PortalTile>[
  _PortalTile(
    icon: Icons.fingerprint,
    label: 'Punch In/Out',
    builder: (context, member) =>
        PunchScreen(memberId: member['id'] as String),
  ),
  _PortalTile(
    icon: Icons.calendar_month,
    label: 'Attendance',
    builder: (context, member) =>
        AttendanceScreen(memberId: member['id'] as String),
  ),
  _PortalTile(
    icon: Icons.fitness_center,
    label: 'Workouts',
    builder: (context, member) =>
        WorkoutsScreen(memberId: member['id'] as String),
  ),
  _PortalTile(
    icon: Icons.insights,
    label: 'Report',
    builder: (context, member) => ReportScreen(member: member),
  ),
  _PortalTile(
    icon: Icons.restaurant_menu,
    label: 'Diet Plan',
    builder: (context, member) =>
        DietScreen(memberId: member['id'] as String),
  ),
  _PortalTile(
    icon: Icons.notifications_active,
    label: 'Reminders',
    builder: (context, member) =>
        RemindersScreen(memberId: member['id'] as String),
  ),
  _PortalTile(
    icon: Icons.restaurant,
    label: 'Log Food',
    builder: (context, member) =>
        FoodLogScreen(memberId: member['id'] as String),
  ),
  _PortalTile(
    icon: Icons.smart_toy,
    label: 'AI Coach',
    builder: (context, member) => ChatScreen(member: member),
  ),
  _PortalTile(
    icon: Icons.photo_camera,
    label: 'Progress Photos',
    builder: (context, member) =>
        ProgressPhotosScreen(memberId: member['id'] as String),
  ),
];

/// Portal home: a tile grid to each feature area, plus the member's basic
/// info and a logout button. Full portal, replacing the Phase 1 placeholder.
class PortalHomeScreen extends ConsumerStatefulWidget {
  const PortalHomeScreen({super.key, this.initialMember});

  final Map<String, dynamic>? initialMember;

  @override
  ConsumerState<PortalHomeScreen> createState() => _PortalHomeScreenState();
}

class _PortalHomeScreenState extends ConsumerState<PortalHomeScreen> {
  Map<String, dynamic>? _member;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _member = widget.initialMember;
    if (_member != null) {
      _isLoading = false;
      _registerPushToken();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadStoredMember());
    }
  }

  void _registerPushToken() {
    final memberId = _member?['id'] as String?;
    if (memberId == null) return;
    // Best-effort, fire-and-forget - a failed/denied push registration
    // should never block the portal from showing.
    ref.read(pushRepositoryProvider).registerCurrentDevice(memberId);
  }

  Future<void> _loadStoredMember() async {
    final stored =
        await ref.read(sessionRepositoryProvider).readStoredSession();
    if (!mounted) return;
    setState(() {
      _member = stored;
      _isLoading = false;
    });
    _registerPushToken();
  }

  Future<void> _handleLogout() async {
    final memberId = _member?['id'] as String?;
    if (memberId != null) {
      // Must happen before clearing the session - stops this device from
      // receiving this member's reminder pushes now that they're logged out.
      await ref.read(pushRepositoryProvider).unregisterCurrentDevice(memberId);
    }
    await ref.read(sessionRepositoryProvider).clearSession();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
        ),
      );
    }

    final member = _member ?? const <String, dynamic>{};
    final fullName = member['full_name'] as String? ?? 'Member';
    final memberId = member['member_id'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Image(image: AssetImage('assets/logo.png'), width: 28, height: 28),
            SizedBox(width: 10),
            Text('Royal Fitness'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, $fullName',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Member ID: $memberId',
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  for (final tile in _portalTiles)
                    _PortalTileCard(
                      tile: tile,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => tile.builder(context, member),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortalTileCard extends StatelessWidget {
  const _PortalTileCard({required this.tile, required this.onTap});

  final _PortalTile tile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E1E1E),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tile.icon, color: const Color(0xFFD4AF37), size: 36),
            const SizedBox(height: 12),
            Text(
              tile.label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
