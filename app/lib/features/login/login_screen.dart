import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_controller.dart';
import '../../ui/theme.dart';
import '../../ui/vinyl.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.5),
            radius: 1.1,
            colors: [Color(0xFF3A220E), Palette.background],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const SpinningRecord(size: 220, labelText: 'VINYLSS', secondsPerTurn: 3),
                  const SizedBox(height: 40),
                  Text('Vinylss', style: text.displaySmall),
                  const SizedBox(height: 12),
                  Text(
                    'Find the records worth owning, based on what you actually listen to.',
                    textAlign: TextAlign.center,
                    style: text.bodyLarge?.copyWith(color: Palette.subtext),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Palette.spotifyGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      onPressed: auth.loading ? null : () => ref.read(authProvider.notifier).login(),
                      icon: auth.loading
                          ? const SizedBox.square(
                              dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.login),
                      label: const Text('Continue with Spotify'),
                    ),
                  ),
                  if (auth.error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      auth.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Palette.error),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
