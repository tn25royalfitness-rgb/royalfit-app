import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/device_key_channel.dart';
import '../data/punch_repository.dart';

class PunchScreen extends ConsumerStatefulWidget {
  const PunchScreen({super.key, required this.memberId});

  final String memberId;

  @override
  ConsumerState<PunchScreen> createState() => _PunchScreenState();
}

class _PunchScreenState extends ConsumerState<PunchScreen> {
  bool? _isRegistered;
  bool _busy = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _checkRegistration();
  }

  Future<void> _checkRegistration() async {
    final registered = await ref.read(punchRepositoryProvider).isRegistered();
    if (!mounted) return;
    setState(() => _isRegistered = registered);
  }

  Future<void> _setUpDevice() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      await ref.read(punchRepositoryProvider).registerDevice(
            memberId: widget.memberId,
          );
      if (!mounted) return;
      setState(() {
        _isRegistered = true;
        _statusMessage = 'This device is now set up for punch-in.';
        _statusIsError = false;
      });
    } on PunchException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = e.message;
        _statusIsError = true;
      });
    } on DeviceKeyException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = e.message;
        _statusIsError = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Could not set up this device. Please try again.';
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _punch(bool checkingIn) async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      await ref.read(punchRepositoryProvider).punch(
            memberId: widget.memberId,
            checkingIn: checkingIn,
          );
      if (!mounted) return;
      setState(() {
        _statusMessage =
            checkingIn ? 'Punched in! Have a great workout 💪' : 'Punched out. See you next time!';
        _statusIsError = false;
      });
    } on PunchException catch (e) {
      if (!mounted) return;
      if (e.message == '_cancelled_') {
        setState(() => _statusMessage = null);
        return;
      }
      setState(() {
        _statusMessage = e.message;
        _statusIsError = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Something went wrong. Please try again.';
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Punch In / Out')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fingerprint, color: Color(0xFFD4AF37), size: 64),
              const SizedBox(height: 24),
              if (_isRegistered == null)
                const CircularProgressIndicator(color: Color(0xFFD4AF37))
              else if (_isRegistered == false) ...[
                const Text(
                  'Set up this device to punch in and out with your fingerprint '
                  'and location - no admin QR code needed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _busy ? null : _setUpDevice,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Set Up This Device'),
                ),
              ] else ...[
                const Text(
                  'You are near the gym? Confirm with your fingerprint to '
                  'punch in or out.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _busy ? null : () => _punch(true),
                        child: const Text('Punch In'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _punch(false),
                        child: const Text('Punch Out'),
                      ),
                    ),
                  ],
                ),
                if (_busy) ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(color: Color(0xFFD4AF37)),
                ],
              ],
              if (_statusMessage != null) ...[
                const SizedBox(height: 24),
                Text(
                  _statusMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _statusIsError ? const Color(0xFFD4AF37) : Colors.greenAccent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
