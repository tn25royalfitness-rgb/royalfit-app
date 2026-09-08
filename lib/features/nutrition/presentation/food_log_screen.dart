import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers.dart';
import '../data/nutrition_repository.dart';
import '../domain/calorie_goal.dart';

/// Reached either from a meal/water reminder notification - [memberId] is
/// null in that case, since a notification tap can't carry the full member
/// map, so it's re-derived from the stored session, same as
/// `ReminderResponseScreen` - or directly from the portal with [memberId]
/// already known. [reminderEventId] set means the linked reminder_event is
/// marked done on save.
class FoodLogScreen extends ConsumerStatefulWidget {
  const FoodLogScreen({
    super.key,
    this.memberId,
    this.reminderEventId,
    this.initialEntryType = 'food',
  });

  final String? memberId;
  final String? reminderEventId;
  final String initialEntryType;

  @override
  ConsumerState<FoodLogScreen> createState() => _FoodLogScreenState();
}

class _FoodLogScreenState extends ConsumerState<FoodLogScreen> {
  late String _entryType;
  final _foodNameController = TextEditingController();
  final _quantityController = TextEditingController();
  XFile? _photo;

  String? _memberId;
  bool _resolvingMember = true;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _result;

  CalorieGoal? _calorieGoal;
  int? _todayCalories;

  @override
  void initState() {
    super.initState();
    _entryType = widget.initialEntryType == 'water' ? 'water' : 'food';
    _resolveMemberId();
  }

  Future<void> _resolveMemberId() async {
    final stored = await ref.read(sessionRepositoryProvider).readStoredSession();
    if (!mounted) return;

    final id = widget.memberId ?? stored?['id'] as String?;
    if (id == null) {
      context.go('/login');
      return;
    }
    setState(() {
      _memberId = id;
      _resolvingMember = false;
    });

    _loadCalorieGoal(id, stored);
  }

  Future<void> _loadCalorieGoal(String memberId, Map<String, dynamic>? member) async {
    try {
      final fitnessProfile =
          await ref.read(portalRepositoryProvider).fetchFitnessProfile(memberId);
      final todayCalories =
          await ref.read(nutritionRepositoryProvider).fetchTodayCalories(memberId);

      final goal = computeCalorieGoal(
        weightKg: member?['weight'] as num?,
        heightCm: member?['height'] as num?,
        dateOfBirth: member?['date_of_birth'] as String?,
        sex: fitnessProfile?['sex'] as String?,
        activityLevel: fitnessProfile?['activity_level'] as String?,
        fitnessGoal: fitnessProfile?['fitness_goal'] as String?,
      );

      if (!mounted) return;
      setState(() {
        _calorieGoal = goal;
        _todayCalories = todayCalories;
      });
    } catch (_) {
      // Calorie target is a nice-to-have on this screen - never block
      // logging a meal because the target couldn't be computed.
    }
  }

  @override
  void dispose() {
    _foodNameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _photo = picked);
  }

  Future<void> _submit() async {
    if (_quantityController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a quantity');
      return;
    }
    if (_entryType == 'food') {
      if (_foodNameController.text.trim().isEmpty) {
        setState(() => _error = 'Please enter the food name');
        return;
      }
      if (_photo == null) {
        setState(() => _error = 'Please take a photo of the food');
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final repo = ref.read(nutritionRepositoryProvider);
      final Map<String, dynamic> entry;

      if (_entryType == 'water') {
        entry = await repo.logWater(
          memberId: _memberId!,
          quantity: _quantityController.text.trim(),
          reminderEventId: widget.reminderEventId,
        );
      } else {
        final bytes = await _photo!.readAsBytes();
        final extension = _photo!.path.split('.').last.toLowerCase();
        entry = await repo.logFood(
          memberId: _memberId!,
          foodName: _foodNameController.text.trim(),
          quantity: _quantityController.text.trim(),
          photoBytes: Uint8List.fromList(bytes),
          extension: extension.isEmpty ? 'jpg' : extension,
          reminderEventId: widget.reminderEventId,
        );
      }

      if (!mounted) return;
      setState(() => _result = entry);
    } on NutritionException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildResult(Map<String, dynamic> entry) {
    final calories = entry['calories'];
    final protein = entry['protein_g'];
    final carbs = entry['carbs_g'];
    final fat = entry['fat_g'];
    final fiber = entry['fiber_g'];
    final vitamins = List<String>.from(entry['vitamins'] as List? ?? []);
    final notes = entry['ai_notes'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle, color: Colors.greenAccent, size: 56),
        const SizedBox(height: 16),
        const Text(
          'Logged!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        if (_entryType == 'food' && calories != null) ...[
          const SizedBox(height: 24),
          Card(
            color: const Color(0xFF1E1E1E),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _nutrientRow('Calories', calories, 'kcal'),
                  _nutrientRow('Protein', protein, 'g'),
                  _nutrientRow('Carbs', carbs, 'g'),
                  _nutrientRow('Fat', fat, 'g'),
                  _nutrientRow('Fiber', fiber, 'g'),
                  if (vitamins.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Vitamins: ${vitamins.join(", ")}',
                        style: const TextStyle(color: Colors.white70)),
                  ],
                  if (notes != null && notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(notes,
                        style: const TextStyle(
                            color: Colors.white54, fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _nutrientRow(String label, dynamic value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(
            value != null ? '$value $unit' : 'Not estimated',
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieGoalCard() {
    final goal = _calorieGoal;
    if (goal == null) return const SizedBox.shrink();

    final logged = _todayCalories ?? 0;
    final remaining = goal.targetCalories - logged;

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today\'s Calorie Target',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${goal.targetCalories} kcal',
                    style: const TextStyle(
                        color: Color(0xFFD4AF37), fontSize: 24, fontWeight: FontWeight.bold)),
                Text(
                  remaining >= 0 ? '$remaining kcal left' : '${-remaining} kcal over',
                  style: TextStyle(
                    color: remaining >= 0 ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Logged so far today: $logged kcal',
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_resolvingMember) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Log Nutrition')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _result != null
            ? _buildResult(_result!)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCalorieGoalCard(),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Meal'),
                          selected: _entryType == 'food',
                          onSelected: (_) => setState(() => _entryType = 'food'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Water'),
                          selected: _entryType == 'water',
                          onSelected: (_) => setState(() => _entryType = 'water'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_entryType == 'food') ...[
                    if (_photo != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_photo!.path),
                          height: 180,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Container(
                            height: 180,
                            color: const Color(0xFF1E1E1E),
                            alignment: Alignment.center,
                            child: const Icon(Icons.image, color: Colors.white38),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: Text(_photo == null ? 'Take a Photo' : 'Retake Photo'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _foodNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Food Name *'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _quantityController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Quantity *',
                        hintText: 'e.g. 200g, 1 bowl, 2 pieces',
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Quantity *',
                        hintText: 'e.g. 250ml, 1 glass',
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: const TextStyle(color: Color(0xFFD4AF37))),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_entryType == 'food' ? 'Analyze & Save' : 'Save'),
                  ),
                ],
              ),
      ),
    );
  }
}
