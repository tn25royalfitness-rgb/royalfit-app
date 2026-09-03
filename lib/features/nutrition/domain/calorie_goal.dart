/// Daily calorie target derived from the member's stats + stated goal.
class CalorieGoal {
  const CalorieGoal({
    required this.bmr,
    required this.tdee,
    required this.targetCalories,
  });

  /// Basal metabolic rate - calories burned at rest.
  final int bmr;

  /// Total daily energy expenditure - BMR adjusted for activity level.
  final int tdee;

  /// TDEE adjusted for the member's stated goal (deficit/surplus/maintain).
  final int targetCalories;
}

/// Mifflin-St Jeor equation, the standard formula for this - needs weight,
/// height, age, and sex. Returns null if any required input is missing
/// (e.g. sex was never set, or weight/height/date_of_birth are blank),
/// rather than guessing.
CalorieGoal? computeCalorieGoal({
  required num? weightKg,
  required num? heightCm,
  required String? dateOfBirth,
  required String? sex,
  required String? activityLevel,
  required String? fitnessGoal,
}) {
  if (weightKg == null || heightCm == null) return null;
  if (dateOfBirth == null || sex == null) return null;

  final dob = DateTime.tryParse(dateOfBirth);
  if (dob == null) return null;

  final now = DateTime.now();
  var age = now.year - dob.year;
  if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
    age--;
  }
  if (age <= 0) return null;

  final bmr = sex == 'female'
      ? 10 * weightKg + 6.25 * heightCm - 5 * age - 161
      : 10 * weightKg + 6.25 * heightCm - 5 * age + 5;

  final activityMultiplier = switch (activityLevel) {
    'active' => 1.725,
    'moderate' => 1.55,
    _ => 1.2, // 'lazy' or unset - conservative default
  };
  final tdee = bmr * activityMultiplier;

  final adjustment = switch (fitnessGoal) {
    'weight_loss' => -500,
    'weight_gain' => 500,
    _ => 0,
  };

  return CalorieGoal(
    bmr: bmr.round(),
    tdee: tdee.round(),
    targetCalories: (tdee + adjustment).round(),
  );
}
