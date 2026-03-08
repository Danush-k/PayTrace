import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'core/theme/app_theme.dart';
import 'app/app_shell.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/scanning_screen.dart';
import 'state/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-load both theme and onboarding state simultaneously.
  ThemeMode initialTheme = ThemeMode.dark;
  bool onboardingDone = false;

  try {
    const storage = FlutterSecureStorage();
    final themeResult = await storage.read(key: 'theme_mode');
    if (themeResult == 'light') {
      initialTheme = ThemeMode.light;
    } else if (themeResult == 'system') {
      initialTheme = ThemeMode.system;
    }
  } catch (_) {
    // Fall back to dark if secure storage fails
  }

  onboardingDone = await isOnboardingComplete();

  runApp(ProviderScope(
    overrides: [
      themeModeProvider
          .overrideWith((_) => ThemeModeNotifier(initialTheme)),
    ],
    child: PayTraceApp(onboardingComplete: onboardingDone),
  ));
}

class PayTraceApp extends ConsumerWidget {
  const PayTraceApp({super.key, required this.onboardingComplete});

  final bool onboardingComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'PayTrace',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: onboardingComplete ? const AppShell() : const OnboardingScreen(),
    );
  }
}
