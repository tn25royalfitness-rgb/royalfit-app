import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../data/portal_repository.dart';

const _componentLabels = {
  'attendance': 'Attendance',
  'workout': 'Workouts',
  'diet': 'Diet',
  'discipline': 'Discipline',
};

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, required this.member});

  final Map<String, dynamic> member;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future =
        ref.read(portalRepositoryProvider).fetchReport(widget.member['id'] as String);
  }

  Widget _buildProfileHeader() {
    final photoUrl = widget.member['photo_url'] as String?;
    final fullName = widget.member['full_name'] as String? ?? 'Member';
    final memberId = widget.member['member_id'] as String? ?? '';
    final packageEndDate = widget.member['package_end_date'] as String?;

    String planText;
    if (packageEndDate == null) {
      planText = 'No active plan';
    } else {
      final endDate = DateTime.tryParse(packageEndDate);
      planText = endDate != null
          ? 'Plan expires ${DateFormat('MMM d, yyyy').format(endDate)}'
          : 'No active plan';
    }

    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: const Color(0xFF1E1E1E),
          backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
              ? NetworkImage(photoUrl)
              : null,
          child: (photoUrl == null || photoUrl.isEmpty)
              ? const Icon(Icons.person, color: Colors.white38, size: 32)
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fullName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('ID: $memberId', style: const TextStyle(color: Colors.white54)),
              Text(planText, style: const TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrendChart(List<Map<String, dynamic>> trend) {
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: Colors.white12, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 25,
                reservedSize: 32,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= trend.length) return const SizedBox.shrink();
                  final weekStart = trend[i]['week_start'] as String?;
                  final date = weekStart != null ? DateTime.tryParse(weekStart) : null;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      date != null ? DateFormat('M/d').format(date) : '',
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              color: const Color(0xFFD4AF37),
              barWidth: 3,
              dotData: const FlDotData(show: true),
              spots: [
                for (var i = 0; i < trend.length; i++)
                  FlSpot(i.toDouble(), (trend[i]['score'] as num?)?.toDouble() ?? 0),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionSection(Map<String, dynamic> nutrition) {
    final mealsLogged = nutrition['meals_logged'] as int? ?? 0;
    final waterLogged = nutrition['water_logged'] as int? ?? 0;
    final totalCalories = nutrition['total_calories'];
    final avgCalories = nutrition['avg_calories_per_day'];
    final totalProtein = nutrition['total_protein_g'];
    final avgProtein = nutrition['avg_protein_g_per_day'];
    final totalFiber = nutrition['total_fiber_g'];

    return Card(
      color: const Color(0xFF1E1E1E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Meals logged', style: const TextStyle(color: Colors.white70)),
                Text('$mealsLogged', style: const TextStyle(color: Colors.white)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Water logged', style: TextStyle(color: Colors.white70)),
                Text('$waterLogged', style: const TextStyle(color: Colors.white)),
              ],
            ),
            if (mealsLogged > 0) ...[
              const Divider(color: Colors.white12, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Calories (total / avg per day)',
                      style: TextStyle(color: Colors.white70)),
                  Text('$totalCalories / $avgCalories kcal',
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Protein (total / avg per day)',
                      style: TextStyle(color: Colors.white70)),
                  Text('$totalProtein / $avgProtein g',
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Fiber (total)', style: TextStyle(color: Colors.white70)),
                  Text('$totalFiber g', style: const TextStyle(color: Colors.white)),
                ],
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Text(
                'Log a meal from the portal or a meal reminder to see nutrition totals here.',
                style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Report')),
      body: FutureBuilder<Map<String, dynamic>>(
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

          final data = snapshot.data!;
          final score = data['score'] as num?;
          final components =
              Map<String, dynamic>.from(data['components'] as Map? ?? {});
          final trend = List<Map<String, dynamic>>.from(
            (data['trend'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
          );
          final workoutMinutes = (data['workout_minutes'] as num?)?.toInt() ?? 0;
          final nutrition = Map<String, dynamic>.from(data['nutrition'] as Map? ?? {});

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildProfileHeader(),
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      Text(
                        score != null ? '${score.round()}' : '—',
                        style: const TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text("This week's score", style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (trend.length > 1) ...[
                  const Text('Trend',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildTrendChart(trend),
                  const SizedBox(height: 24),
                ],
                const Text('Breakdown',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                for (final key in _componentLabels.keys)
                  _ComponentTile(
                    label: _componentLabels[key]!,
                    component: components[key] != null
                        ? Map<String, dynamic>.from(components[key] as Map)
                        : null,
                  ),
                const SizedBox(height: 8),
                _WorkoutTimeTile(minutes: workoutMinutes),
                const SizedBox(height: 24),
                const Text('Nutrition',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildNutritionSection(nutrition),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ComponentTile extends StatelessWidget {
  const _ComponentTile({required this.label, required this.component});

  final String label;
  final Map<String, dynamic>? component;

  @override
  Widget build(BuildContext context) {
    if (component == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white)),
            const Text('Not tracked yet', style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    final pct = (component!['pct'] as num?)?.toDouble() ?? 0;
    final done = component!['done'];
    final total = component!['total'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white)),
              Text('$done / $total', style: const TextStyle(color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0, 1),
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFD4AF37)),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutTimeTile extends StatelessWidget {
  const _WorkoutTimeTile({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final display = minutes == 0 ? 'Not tracked yet' : '${hours}h ${mins}m';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Workout Time', style: TextStyle(color: Colors.white)),
          Text(
            display,
            style: TextStyle(color: minutes == 0 ? Colors.white38 : Colors.white54),
          ),
        ],
      ),
    );
  }
}
