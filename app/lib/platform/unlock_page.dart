import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/termex_bridge.dart' as bridge;

import '../main.dart';

class UnlockPage extends ConsumerStatefulWidget {
  const UnlockPage({super.key});

  @override
  ConsumerState<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends ConsumerState<UnlockPage> {
  final _controller = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ok = await bridge.verifyMasterPassword(password: _controller.text);
      if (ok) {
        ref.read(appUnlockedProvider.notifier).state = true;
      } else {
        setState(() => _error = 'Incorrect password');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFirstRun = ref.watch(appInitStateProvider).isFirstRun;
    return Container(
      color: const Color(0xFF1E1E2E),
      child: Center(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isFirstRun ? 'Set master password' : 'Enter master password',
                style: const TextStyle(
                  color: Color(0xFFCDD6F4),
                  fontSize: 20,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFF38BA8),
                    decoration: TextDecoration.none,
                  ),
                ),
              if (_loading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.0),
                )
              else
                GestureDetector(
                  onTap: _submit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF89B4FA),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Unlock',
                      style: TextStyle(
                        color: Color(0xFF1E1E2E),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
