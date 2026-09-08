import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/portal_repository.dart';

const _fitnessGoals = ['weight_loss', 'weight_gain', 'maintenance'];
const _activityLevels = ['active', 'moderate', 'lazy'];

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.member});

  final Map<String, dynamic> member;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messages = <Map<String, String>>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  Map<String, dynamic>? _fitnessProfile;
  bool _needsIntake = false;
  bool _loadingProfile = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadProfileAndHistory();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _memberId => widget.member['id'] as String;

  Future<void> _loadProfileAndHistory() async {
    final repo = ref.read(portalRepositoryProvider);
    try {
      final profile = await repo.fetchFitnessProfile(_memberId);
      final history = await repo.fetchChatHistory(_memberId);
      if (!mounted) return;
      setState(() {
        _fitnessProfile = profile;
        _needsIntake = profile == null;
        _messages.addAll(
          history.map(
            (m) => {
              'role': m['role'] as String,
              'content': m['content'] as String,
            },
          ),
        );
      });
    } on PortalException catch (_) {
      // Best-effort - chat still works without history/profile pre-loaded.
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _sending) return;
    final repo = ref.read(portalRepositoryProvider);

    setState(() {
      _messages.add({'role': 'user', 'content': text.trim()});
      _sending = true;
    });
    _inputController.clear();
    _scrollToBottom();

    await repo.saveChatMessage(
      memberId: _memberId,
      role: 'user',
      content: text.trim(),
    );

    var assistantSoFar = '';
    var assistantAdded = false;

    try {
      final stream = repo.streamWorkoutChat(
        messages: _messages
            .map((m) => {'role': m['role']!, 'content': m['content']!})
            .toList(),
        memberProfile: {
          'name': widget.member['full_name'],
          'weight': widget.member['weight'],
          'height': widget.member['height'],
          'isActive': widget.member['is_active'],
        },
        fitnessProfile: _fitnessProfile,
      );

      await for (final chunk in stream) {
        assistantSoFar += chunk.delta;
        setState(() {
          if (!assistantAdded) {
            _messages.add({'role': 'assistant', 'content': assistantSoFar});
            assistantAdded = true;
          } else {
            _messages.last['content'] = assistantSoFar;
          }
        });
        _scrollToBottom();
      }

      if (assistantSoFar.isNotEmpty) {
        await repo.saveChatMessage(
          memberId: _memberId,
          role: 'assistant',
          content: assistantSoFar,
        );
      }
    } on PortalException catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': '❌ ${e.message}'});
      });
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProfile) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
        ),
      );
    }

    if (_needsIntake) {
      return _IntakeForm(
        onSubmit: (data) async {
          try {
            await ref.read(portalRepositoryProvider).saveFitnessProfile(
                  memberId: _memberId,
                  fitnessGoal: data['fitness_goal'] as String,
                  alcoholConsumption: data['alcohol_consumption'] as bool,
                  dietType: data['diet_type'] as String,
                  physicalIssues: data['physical_issues'] as String,
                  activityLevel: data['activity_level'] as String,
                  sex: data['sex'] as String,
                );
            if (!mounted) return;
            setState(() {
              _fitnessProfile = data;
              _needsIntake = false;
            });
          } on PortalException catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.message)),
            );
          }
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('AI Workout Coach')),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      "Ask me for today's workout! 💪",
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final msg = _messages[i];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.8,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? const Color(0xFFD4AF37)
                                : const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            msg['content'] ?? '',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      style: const TextStyle(color: Colors.white),
                      enabled: !_sending,
                      decoration: const InputDecoration(
                        hintText: 'Ask about workouts, diet, exercises...',
                      ),
                      onSubmitted: _send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _sending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: Color(0xFFD4AF37)),
                    onPressed:
                        _sending ? null : () => _send(_inputController.text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntakeForm extends StatefulWidget {
  const _IntakeForm({required this.onSubmit});

  final Future<void> Function(Map<String, dynamic> data) onSubmit;

  @override
  State<_IntakeForm> createState() => _IntakeFormState();
}

class _IntakeFormState extends State<_IntakeForm> {
  String _goal = _fitnessGoals.first;
  String _diet = 'veg';
  String _activity = _activityLevels.first;
  bool _alcohol = false;
  String? _sex;
  final _issuesController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _issuesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Up Your Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Tell the AI coach a bit about yourself so it can tailor your workouts.",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            const Text('Goal', style: TextStyle(color: Colors.white70)),
            DropdownButtonFormField<String>(
              value: _goal,
              dropdownColor: const Color(0xFF1E1E1E),
              style: const TextStyle(color: Colors.white),
              items: _fitnessGoals
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _goal = v!),
            ),
            const SizedBox(height: 16),
            const Text('Activity level', style: TextStyle(color: Colors.white70)),
            DropdownButtonFormField<String>(
              value: _activity,
              dropdownColor: const Color(0xFF1E1E1E),
              style: const TextStyle(color: Colors.white),
              items: _activityLevels
                  .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                  .toList(),
              onChanged: (v) => setState(() => _activity = v!),
            ),
            const SizedBox(height: 16),
            const Text('Sex (needed to calculate your calorie target)',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Male'),
                  selected: _sex == 'male',
                  onSelected: (_) => setState(() {
                    _sex = 'male';
                    _error = null;
                  }),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Female'),
                  selected: _sex == 'female',
                  onSelected: (_) => setState(() {
                    _sex = 'female';
                    _error = null;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Diet:', style: TextStyle(color: Colors.white70)),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Veg'),
                  selected: _diet == 'veg',
                  onSelected: (_) => setState(() => _diet = 'veg'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Non-Veg'),
                  selected: _diet == 'non_veg',
                  onSelected: (_) => setState(() => _diet = 'non_veg'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Do you drink alcohol?',
                  style: TextStyle(color: Colors.white70)),
              value: _alcohol,
              onChanged: (v) => setState(() => _alcohol = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _issuesController,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Any physical issues or pain?',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFD4AF37))),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitting
                  ? null
                  : () async {
                      if (_sex == null) {
                        setState(() => _error = 'Please select your sex');
                        return;
                      }
                      setState(() {
                        _submitting = true;
                        _error = null;
                      });
                      await widget.onSubmit({
                        'fitness_goal': _goal,
                        'alcohol_consumption': _alcohol,
                        'diet_type': _diet,
                        'physical_issues': _issuesController.text.trim(),
                        'activity_level': _activity,
                        'sex': _sex,
                      });
                      if (mounted) setState(() => _submitting = false);
                    },
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("Let's Go"),
            ),
          ],
        ),
      ),
    );
  }
}
