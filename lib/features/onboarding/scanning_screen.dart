import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/theme/app_theme.dart';
import '../../services/historical_sms_scanner_service.dart';
import '../../state/providers.dart';
import '../../app/app_shell.dart';

// ── Storage key ────────────────────────────────────────────────────────────────
const _kOnboardingComplete = 'onboarding_complete';

/// Mark onboarding as done so the app never shows it again.
Future<void> markOnboardingComplete() async {
  const storage = FlutterSecureStorage();
  await storage.write(key: _kOnboardingComplete, value: 'true');
}

/// Returns `true` if the user has already completed onboarding.
Future<bool> isOnboardingComplete() async {
  try {
    const storage = FlutterSecureStorage();
    return await storage.read(key: _kOnboardingComplete) == 'true';
  } catch (_) {
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Progress messages shown during the scan
// ─────────────────────────────────────────────────────────────────────────────
const _kProgressMessages = [
  (Icons.sms_rounded, 'Scanning messages...'),
  (Icons.manage_search_rounded, 'Detecting transactions...'),
  (Icons.bar_chart_rounded, 'Analyzing spending patterns...'),
];

// ─────────────────────────────────────────────────────────────────────────────
//  ScanningScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Displayed immediately after permissions are granted.
///
/// Responsibilities:
///  1. Runs [HistoricalSmsScannerService.scanHistorical] to scan the
///     last 90 days of SMS from both inbox and sent folders.
///  2. Cycles through 3 friendly progress messages driven by the actual
///     [ScanPhase] reported by the scanner.
///  3. Writes the [_kOnboardingComplete] flag to secure storage.
///  4. Navigates to [AppShell] when scanning is complete.
class ScanningScreen extends ConsumerStatefulWidget {
  const ScanningScreen({super.key});

  @override
  ConsumerState<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends ConsumerState<ScanningScreen> {
  int _msgIndex = 0;
  bool _scanDone = false;

  // Minimum time each message must be visible before the phase can advance.
  // This prevents the UI from blinking too fast on fast devices.
  static const _minPhaseDuration = Duration(milliseconds: 1400);
  DateTime _lastAdvance = DateTime.now();

  @override
  void initState() {
    super.initState();
    _runScan();
  }

  // ── scan ────────────────────────────────────────────────────────────────────

  Future<void> _runScan() async {
    final db = ref.read(databaseProvider);
    try {
      final result = await HistoricalSmsScannerService.scanHistorical(
        db,
        onProgress: _handleProgress,
      );
      debugPrint(
        'PayTrace Onboarding: $result',
      );
    } catch (e) {
      debugPrint('PayTrace Onboarding: Scan error — $e');
    } finally {
      _scanDone = true;
      // Ensure we reach the last message before navigating.
      _advanceTo(_kProgressMessages.length - 1);
      _maybeNavigate();
    }
  }

  // ── phase → message mapping ──────────────────────────────────────────────

  /// Maps [ScanPhase] to a target message index.
  static int _phaseToIndex(ScanPhase phase) {
    switch (phase) {
      case ScanPhase.fetching:
        return 0; // "Scanning messages…"
      case ScanPhase.filtering:
      case ScanPhase.parsing:
        return 1; // "Detecting transactions…"
      case ScanPhase.storing:
      case ScanPhase.done:
        return 2; // "Analyzing spending patterns…"
    }
  }

  void _handleProgress(ScanProgress progress) {
    final target = _phaseToIndex(progress.phase);
    _advanceTo(target);
  }

  /// Advance the message index to [target], respecting the minimum phase
  /// duration so every message is visible long enough for the user to read.
  void _advanceTo(int target) {
    if (!mounted) return;
    if (target <= _msgIndex) return; // never go backwards

    final now = DateTime.now();
    final elapsed = now.difference(_lastAdvance);
    if (elapsed < _minPhaseDuration) {
      // Schedule the advance for later.
      final delay = _minPhaseDuration - elapsed;
      Future.delayed(delay, () => _advanceTo(target));
      return;
    }

    setState(() {
      _msgIndex = target.clamp(0, _kProgressMessages.length - 1);
      _lastAdvance = now;
    });

    if (_msgIndex >= _kProgressMessages.length - 1) {
      _maybeNavigate();
    }
  }

  void _maybeNavigate() {
    // Only navigate once BOTH conditions hold: all messages shown + scan done.
    if (_msgIndex < _kProgressMessages.length - 1) return;
    if (!_scanDone) return;

    if (!mounted) return;

    // Brief pause on the last message before transitioning.
    Future.delayed(const Duration(milliseconds: 700), () async {
      if (!mounted) return;
      await markOnboardingComplete();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, a1, a2) => const AppShell(),
          transitionsBuilder: (_, a1, __, child) => FadeTransition(
            opacity: a1,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    });
  }

  // ── build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final (icon, message) = _kProgressMessages[_msgIndex];

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.scaffoldDark : AppTheme.scaffoldLight,
      body: Center(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Animated icon ─────────────────────────────────────────────
              _PulsingIcon(icon: icon, key: ValueKey(icon)),

              const SizedBox(height: 40),

              // ── Progress indicator ────────────────────────────────────────
              SizedBox(
                width: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor:
                        AppTheme.primary.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.primary),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Cycling message ───────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Text(
                  message,
                  key: ValueKey(message),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.textPrimaryDark
                        : AppTheme.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 16),

              // ── Dots indicator ────────────────────────────────────────────
              _DotsIndicator(
                count: _kProgressMessages.length,
                current: _msgIndex,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon({super.key, required this.icon});

  final IconData icon;

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    lowerBound: 0.92,
    upperBound: 1.08,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _ctrl,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primary, AppTheme.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(widget.icon, color: Colors.white, size: 46),
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? AppTheme.primary
                : AppTheme.primary.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
