import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/portal_repository.dart';

const _reminderTypes = [
  {'value': 'water', 'label': 'Drink Water', 'icon': Icons.water_drop},
  {'value': 'meal', 'label': 'Meal', 'icon': Icons.restaurant},
  {'value': 'workout', 'label': 'Workout', 'icon': Icons.fitness_center},
  {'value': 'custom', 'label': 'Custom', 'icon': Icons.notifications},
];

// index 0 = Sunday, matching reminder_schedules.days_of_week's convention
// (JS getUTCDay() in reminders-dispatch, and the column's own default).
const _dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

class CreateReminderScreen extends ConsumerStatefulWidget {
  const CreateReminderScreen({super.key, required this.memberId});

  final String memberId;

  @override
  ConsumerState<CreateReminderScreen> createState() => _CreateReminderScreenState();
}

class _CreateReminderScreenState extends ConsumerState<CreateReminderScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  String _type = 'water';
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  final Set<int> _days = {0, 1, 2, 3, 4, 5, 6};

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  String get _timeOfDayString {
    final hh = _time.hour.toString().padLeft(2, '0');
    final mm = _time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a title');
      return;
    }
    if (_days.isEmpty) {
      setState(() => _error = 'Pick at least one day');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(portalRepositoryProvider).createReminderSchedule(
            memberId: widget.memberId,
            reminderType: _type,
            title: _titleController.text.trim(),
            message: _messageController.text.trim().isEmpty
                ? null
                : _messageController.text.trim(),
            timeOfDay: _timeOfDayString,
            daysOfWeek: _days.toList()..sort(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PortalException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not create reminder. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Reminder')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Type', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final type in _reminderTypes)
                  ChoiceChip(
                    label: Text(type['label'] as String),
                    avatar: Icon(type['icon'] as IconData, size: 18),
                    selected: _type == type['value'],
                    onSelected: (_) => setState(() => _type = type['value'] as String),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Title *'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Message (optional)'),
            ),
            const SizedBox(height: 20),
            const Text('Time', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.access_time),
              label: Text(_time.format(context)),
            ),
            const SizedBox(height: 20),
            const Text('Repeat on', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (var i = 0; i < 7; i++)
                  FilterChip(
                    label: Text(_dayLabels[i]),
                    selected: _days.contains(i),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _days.add(i);
                        } else {
                          _days.remove(i);
                        }
                      });
                    },
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Color(0xFFD4AF37))),
            ],
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Reminder'),
            ),
          ],
        ),
      ),
    );
  }
}
