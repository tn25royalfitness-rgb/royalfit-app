// Basic sanity test for the app theme. The old counter-demo smoke test was
// removed because it referenced the default `MyApp` scaffold, which no
// longer exists now that this project is the Royal Fitness member app.
//
// A full widget test of `RoyalFitnessApp` would require Supabase to be
// initialized (it talks to a live backend on launch), so it is left for a
// later phase once test-friendly fakes/mocks are introduced.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:royalfitness_app/core/theme/app_theme.dart';

void main() {
  test('AppTheme.darkTheme uses a dark brightness and the brand gold', () {
    final theme = AppTheme.darkTheme;
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, AppTheme.primaryGold);
  });
}
