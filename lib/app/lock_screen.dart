import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_auth_service.dart';
import '../core/theme/app_theme.dart';

final isUnlockedProvider = StateProvider<bool>((ref) => false);

class LockScreenWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const LockScreenWrapper({super.key, required this.child});

  @override
  ConsumerState<LockScreenWrapper> createState() => _LockScreenWrapperState();
}

class _LockScreenWrapperState extends ConsumerState<LockScreenWrapper> with WidgetsBindingObserver {
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth(false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAuth(true);
    } else if (state == AppLifecycleState.paused) {
      if (ref.read(appLockEnabledProvider)) {
        ref.read(isUnlockedProvider.notifier).state = false;
      }
    }
  }

  Future<void> _checkAuth(bool returningFromBackground) async {
    final isEnabled = ref.read(appLockEnabledProvider);
    if (!isEnabled) {
      ref.read(isUnlockedProvider.notifier).state = true;
      return;
    }
    
    final isUnlocked = ref.read(isUnlockedProvider);
    if (isUnlocked) return;

    if (_isAuthenticating) return;
    _isAuthenticating = true;

    final localAuth = ref.read(localAuthProvider);
    final canAuth = await localAuth.canAuthenticate();

    if (canAuth) {
      final success = await localAuth.authenticate();
      if (success) {
        ref.read(isUnlockedProvider.notifier).state = true;
      }
    } else {
      // If biometrics/PIN isn't setup but switch is on, fallback to unlocked
      ref.read(isUnlockedProvider.notifier).state = true;
    }
    _isAuthenticating = false;
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = ref.watch(appLockEnabledProvider);
    final isUnlocked = ref.watch(isUnlockedProvider);

    if (!isEnabled || isUnlocked) {
      return widget.child;
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_rounded,
              size: 64,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'PayTrace Locked',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _checkAuth(false),
              icon: const Icon(Icons.fingerprint_rounded),
              label: const Text('Unlock'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
