import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../data/portal_repository.dart';
import 'create_reminder_screen.dart';

const _typeIcons = {
  'water': Icons.water_drop,
  'meal': Icons.restaurant,
  'workout': Icons.fitness_center,
  'custom': Icons.notifications,
};

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key, required this.memberId});

  final String memberId;

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<Map<String, dynamic>>? _events;
  String? _eventsError;
  bool _eventsLoading = true;

  List<Map<String, dynamic>>? _schedules;
  String? _schedulesError;
  bool _schedulesLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEvents();
    _loadSchedules();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _eventsLoading = true;
      _eventsError = null;
    });
    try {
      final events =
          await ref.read(portalRepositoryProvider).fetchReminders(widget.memberId);
      if (!mounted) return;
      setState(() => _events = events);
    } on PortalException catch (e) {
      if (!mounted) return;
      setState(() => _eventsError = e.message);
    } finally {
      if (mounted) setState(() => _eventsLoading = false);
    }
  }

  Future<void> _loadSchedules() async {
    setState(() {
      _schedulesLoading = true;
      _schedulesError = null;
    });
    try {
      final schedules = await ref
          .read(portalRepositoryProvider)
          .fetchMyReminderSchedules(widget.memberId);
      if (!mounted) return;
      setState(() => _schedules = schedules);
    } on PortalException catch (e) {
      if (!mounted) return;
      setState(() => _schedulesError = e.message);
    } finally {
      if (mounted) setState(() => _schedulesLoading = false);
    }
  }

  Future<void> _respond(String eventId, bool done) async {
    try {
      await ref.read(portalRepositoryProvider).respondReminder(
            memberId: widget.memberId,
            eventId: eventId,
            done: done,
          );
      await _loadEvents();
    } on PortalException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteSchedule(String scheduleId) async {
    try {
      await ref.read(portalRepositoryProvider).deleteReminderSchedule(
            memberId: widget.memberId,
            scheduleId: scheduleId,
          );
      await _loadSchedules();
    } on PortalException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _createReminder() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CreateReminderScreen(memberId: widget.memberId),
      ),
    );
    if (created == true) {
      _loadSchedules();
    }
  }

  Widget _buildTodayTab() {
    if (_eventsLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
    }
    if (_eventsError != null) {
      return Center(
        child: Text(_eventsError!, style: const TextStyle(color: Colors.white70)),
      );
    }
    if (_events == null || _events!.isEmpty) {
      return const Center(
        child: Text('No reminders scheduled for today.', style: TextStyle(color: Colors.white54)),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _events!.length,
        separatorBuilder: (_, __) => const Divider(color: Colors.white12),
        itemBuilder: (context, i) {
          final event = _events![i];
          final schedule = Map<String, dynamic>.from(event['reminder_schedules'] as Map? ?? {});
          final scheduledFor = event['scheduled_for'] as String?;
          final status = event['status'] as String? ?? 'pending';
          final time = scheduledFor != null
              ? DateFormat('h:mm a').format(DateTime.parse(scheduledFor).toLocal())
              : '';

          return ListTile(
            title: Text(schedule['title'] as String? ?? 'Reminder',
                style: const TextStyle(color: Colors.white)),
            subtitle: Text(
              '$time${(schedule['message'] as String?)?.isNotEmpty ?? false ? ' • ${schedule['message']}' : ''}',
              style: const TextStyle(color: Colors.white54),
            ),
            trailing: status == 'pending'
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => _respond(event['id'] as String, false),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.greenAccent),
                        onPressed: () => _respond(event['id'] as String, true),
                      ),
                    ],
                  )
                : Text(
                    status,
                    style: TextStyle(
                      color: status == 'done' ? Colors.greenAccent : Colors.white38,
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildMyRemindersTab() {
    if (_schedulesLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
    }
    if (_schedulesError != null) {
      return Center(
        child: Text(_schedulesError!, style: const TextStyle(color: Colors.white70)),
      );
    }
    if (_schedules == null || _schedules!.isEmpty) {
      return const Center(
        child: Text(
          'No reminders set up yet. Tap + to add one.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadSchedules,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _schedules!.length,
        separatorBuilder: (_, __) => const Divider(color: Colors.white12),
        itemBuilder: (context, i) {
          final schedule = _schedules![i];
          final createdByMember = schedule['created_by_member'] == true;
          final time = (schedule['time_of_day'] as String?)?.substring(0, 5) ?? '';

          return ListTile(
            leading: Icon(
              _typeIcons[schedule['reminder_type']] ?? Icons.notifications,
              color: const Color(0xFFD4AF37),
            ),
            title: Text(schedule['title'] as String? ?? 'Reminder',
                style: const TextStyle(color: Colors.white)),
            subtitle: Text(
              createdByMember ? '$time • Set by you' : '$time • Set by your gym',
              style: const TextStyle(color: Colors.white54),
            ),
            trailing: createdByMember
                ? IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white54),
                    onPressed: () => _deleteSchedule(schedule['id'] as String),
                  )
                : null,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'My Reminders'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createReminder,
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodayTab(),
          _buildMyRemindersTab(),
        ],
      ),
    );
  }
}
