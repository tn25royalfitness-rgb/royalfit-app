import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../data/portal_repository.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key, required this.memberId});

  final String memberId;

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref
        .read(portalRepositoryProvider)
        .fetchAttendance(widget.memberId);
  }

  String _formatTime(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '—';
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
            );
          }
          if (snapshot.hasError) {
            final message = snapshot.error is PortalException
                ? (snapshot.error as PortalException).message
                : 'Something went wrong.';
            return Center(
              child: Text(message, style: const TextStyle(color: Colors.white70)),
            );
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return const Center(
              child: Text(
                'No attendance records yet.',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white12),
            itemBuilder: (context, i) {
              final row = rows[i];
              final checkIn = row['check_in_time'] as String?;
              final checkOut = row['check_out_time'] as String?;
              return ListTile(
                leading: const Icon(Icons.fitness_center, color: Color(0xFFD4AF37)),
                title: Text(
                  _formatTime(checkIn),
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  checkOut != null
                      ? 'Out: ${_formatTime(checkOut)}'
                      : 'Still checked in',
                  style: const TextStyle(color: Colors.white54),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
