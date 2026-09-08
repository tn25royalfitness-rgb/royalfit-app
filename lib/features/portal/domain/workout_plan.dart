/// One exercise row within a branch section of an assigned workout.
class WorkoutExercise {
  const WorkoutExercise({
    required this.key,
    required this.branch,
    required this.name,
    required this.sets,
    required this.reps,
  });

  /// Stable identity for tracking completion - "$branch|$name", not
  /// positional, so editing the plan on the admin side doesn't silently
  /// reassign a member's existing ticks to a different exercise.
  final String key;
  final String branch;
  final String name;
  final String sets;
  final String reps;

  /// Whether this exercise is held for a duration (e.g. "45 sec", "3 min",
  /// as admins already write for things like Plank or Jump Rope) rather
  /// than counted in reps - detected from the `reps` field's own text since
  /// there's no separate structured field for it. Drives whether the member
  /// is asked to log a time or a rep count.
  bool get isTimeBased {
    final lower = reps.toLowerCase();
    return lower.contains('sec') || lower.contains('min') || lower.contains(':');
  }
}

/// One muscle-group section of an assigned workout.
class WorkoutBranch {
  const WorkoutBranch({required this.name, required this.exercises});

  final String name;
  final List<WorkoutExercise> exercises;
}

/// Parses the markdown `workout_plan` text the admin dashboard's
/// `buildMultiBranchPlan()`/`buildWeeklyDayPlan()` writes:
///
/// ```
/// **Chest**
/// | Exercise | Sets | Reps |
/// |---|---|---|
/// | Bench Press | 3 | 12 |
/// ```
///
/// Sections are separated by blank lines; each starts with a `**Branch**`
/// heading, then a markdown table whose header/separator rows are skipped.
/// Malformed input degrades gracefully to an empty list rather than
/// throwing - a member should never see a crash because of how an admin
/// phrased a plan.
List<WorkoutBranch> parseWorkoutPlan(String plan) {
  final branches = <WorkoutBranch>[];
  final sections = plan.split(RegExp(r'\n\s*\n'));

  for (final section in sections) {
    final lines = section
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) continue;

    final headingMatch = RegExp(r'^\*\*(.+?)\*\*$').firstMatch(lines.first);
    if (headingMatch == null) continue;
    final branchName = headingMatch.group(1)!.trim();

    final exercises = <WorkoutExercise>[];
    for (final line in lines.skip(1)) {
      if (!line.startsWith('|')) continue;
      // Table cells, dropping the empty strings from the leading/trailing '|'.
      final cells = line
          .split('|')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList();
      if (cells.length < 3) continue;
      // Header row ("Exercise | Sets | Reps") and separator row ("---|---|---").
      if (cells.first.toLowerCase() == 'exercise') continue;
      if (cells.every((c) => RegExp(r'^-+$').hasMatch(c))) continue;

      final name = cells[0];
      exercises.add(WorkoutExercise(
        key: '$branchName|$name',
        branch: branchName,
        name: name,
        sets: cells[1],
        reps: cells[2],
      ));
    }

    if (exercises.isNotEmpty) {
      branches.add(WorkoutBranch(name: branchName, exercises: exercises));
    }
  }

  return branches;
}
