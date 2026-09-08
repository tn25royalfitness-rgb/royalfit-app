import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/portal_repository.dart';

class DietScreen extends ConsumerStatefulWidget {
  const DietScreen({super.key, required this.memberId});

  final String memberId;

  @override
  ConsumerState<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends ConsumerState<DietScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(portalRepositoryProvider).fetchDietPlans(widget.memberId);
  }

  IconData _iconFor(String itemType) {
    switch (itemType) {
      case 'water':
        return Icons.water_drop;
      case 'supplement':
        return Icons.medication;
      case 'meal':
        return Icons.restaurant;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diet Plan')),
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
          final plans = snapshot.data ?? [];
          if (plans.isEmpty) {
            return const Center(
              child: Text(
                'No active diet plan yet.',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            itemBuilder: (context, i) {
              final plan = plans[i];
              final items = List<Map<String, dynamic>>.from(
                plan['items'] as List? ?? [],
              );
              return Card(
                color: const Color(0xFF1E1E1E),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan['title'] as String? ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if ((plan['description'] as String?)?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 4),
                        Text(
                          plan['description'] as String,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                      const SizedBox(height: 12),
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                _iconFor(item['item_type'] as String? ?? ''),
                                size: 18,
                                color: const Color(0xFFD4AF37),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item['name'] as String? ?? '',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              if (item['scheduled_time'] != null)
                                Text(
                                  (item['scheduled_time'] as String)
                                      .substring(0, 5),
                                  style: const TextStyle(color: Colors.white54),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
