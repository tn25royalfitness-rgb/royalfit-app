import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../data/portal_repository.dart';
import '../domain/workout_plan.dart';

/// Today's assigned workout only - admins routinely assign workouts weeks
/// ahead via the repeat-weeks feature, and showing a plain "most recent 10"
/// list meant members were completing whatever happened to be furthest in
/// the future instead of today's, which also silently broke the weekly
/// report (workouts are scored by workout_date within the current week).
class WorkoutsScreen extends ConsumerStatefulWidget {
  const WorkoutsScreen({super.key, required this.memberId});

  final String memberId;

  @override
  ConsumerState<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends ConsumerState<WorkoutsScreen> {
  Map<String, dynamic>? _workout;
  List<WorkoutBranch> _branches = const [];
  Map<String, String> _progress = {};
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final workout =
          await ref.read(portalRepositoryProvider).fetchTodayWorkout(widget.memberId);
      if (!mounted) return;
      setState(() {
        _workout = workout;
        _branches = workout != null
            ? parseWorkoutPlan(workout['workout_plan'] as String? ?? '')
            : const [];
        _progress = workout != null
            ? Map<String, String>.from(
                (workout['exercise_progress'] as Map? ?? {})
                    .map((k, v) => MapEntry(k.toString(), v.toString())),
              )
            : {};
      });
    } on PortalException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _totalExercises =>
      _branches.fold(0, (sum, b) => sum + b.exercises.length);

  Future<void> _saveProgress(Map<String, String> next) async {
    if (_workout == null || _saving) return;

    final previous = _progress;
    setState(() {
      _progress = next;
      _saving = true;
    });

    try {
      final allDone = _totalExercises > 0 && next.length == _totalExercises;
      final updated = await ref.read(portalRepositoryProvider).saveWorkoutProgress(
            memberId: widget.memberId,
            workoutId: _workout!['id'] as String,
            exerciseProgress: next,
            allDone: allDone,
          );
      if (!mounted) return;
      setState(() => _workout = updated);
    } on PortalException catch (e) {
      if (!mounted) return;
      setState(() => _progress = previous);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logExercise(WorkoutExercise exercise) async {
    if (_saving) return;
    final entered = await showDialog<String>(
      context: context,
      builder: (context) => _LogEntryDialog(
        exercise: exercise,
        initialValue: _progress[exercise.key],
      ),
    );
    if (entered == null) return; // cancelled

    final next = Map<String, String>.from(_progress);
    if (entered.isEmpty) {
      next.remove(exercise.key);
    } else {
      next[exercise.key] = entered;
    }
    await _saveProgress(next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Workout - ${DateFormat('MMM d').format(DateTime.now())}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : _error != null
              ? Center(
                  child: Text(_error!, style: const TextStyle(color: Colors.white70)),
                )
              : _workout == null
                  ? const Center(
                      child: Text(
                        'No workout assigned for today.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildProgressHeader(),
                          const SizedBox(height: 16),
                          for (final branch in _branches) _buildBranchCard(branch),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildProgressHeader() {
    final done = _progress.length;
    final total = _totalExercises;
    final complete = total > 0 && done == total;

    return Card(
      color: const Color(0xFF1E1E1E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$done / $total exercises logged',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            if (complete)
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                  SizedBox(width: 6),
                  Text('Complete!', style: TextStyle(color: Colors.greenAccent)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchCard(WorkoutBranch branch) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              branch.name,
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
              },
              children: [
                const TableRow(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Exercise', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Target', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Your Log', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ),
                  ],
                ),
                for (final exercise in branch.exercises)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          exercise.name,
                          style: TextStyle(
                            color: _progress.containsKey(exercise.key)
                                ? Colors.white38
                                : Colors.white,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '${exercise.sets} × ${exercise.reps}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: OutlinedButton(
                          onPressed: _saving ? null : () => _logExercise(exercise),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            side: BorderSide(
                              color: _progress.containsKey(exercise.key)
                                  ? Colors.greenAccent
                                  : Colors.white24,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_progress.containsKey(exercise.key)) ...[
                                const Icon(Icons.check, color: Colors.greenAccent, size: 14),
                                const SizedBox(width: 4),
                              ],
                              Flexible(
                                child: Text(
                                  _progress[exercise.key] ??
                                      (exercise.isTimeBased ? 'Log time' : 'Log reps'),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _progress.containsKey(exercise.key)
                                        ? Colors.greenAccent
                                        : Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Prompts for what the member actually did on one exercise - a rep count
/// for normal exercises, or a time held for duration-based ones (Plank,
/// Jump Rope, etc, detected from the admin-entered "reps" text). Returns
/// the entered value, an empty string to clear a previous log, or null if
/// cancelled.
class _LogEntryDialog extends StatefulWidget {
  const _LogEntryDialog({required this.exercise, this.initialValue});

  final WorkoutExercise exercise;
  final String? initialValue;

  @override
  State<_LogEntryDialog> createState() => _LogEntryDialogState();
}

class _LogEntryDialogState extends State<_LogEntryDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeBased = widget.exercise.isTimeBased;
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(widget.exercise.name, style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Target: ${widget.exercise.sets} × ${widget.exercise.reps}',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            keyboardType: timeBased
                ? TextInputType.text
                : const TextInputType.numberWithOptions(),
            inputFormatters:
                timeBased ? null : [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: timeBased ? 'Time held' : 'Reps done',
              hintText: timeBased ? 'e.g. 45 sec' : 'e.g. 12',
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (widget.initialValue != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Clear'),
          ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
