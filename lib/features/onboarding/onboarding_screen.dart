import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_theme.dart';
import 'scanning_screen.dart';

enum _PermissionStep {
  restrictedSettings,
  sms,
  notifications,
}

class _AppSettingsHelper {
  static const _channel = MethodChannel('com.paytrace.paytrace/upi');

  static Future<void> openAppSettings() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('openAppSettings');
    } on PlatformException {
      // fallback
    }
  }

  static Future<bool> hasSmsPermission() async {
    if (kIsWeb) return true;
    try {
      return await _channel.invokeMethod<bool>('hasSmsPermission') ?? false;
    } on PlatformException {
      return false;
    }
  }
}

class _NotifListenerHelper {
  static const _channel = MethodChannel('com.paytrace.paytrace/upi');

  static Future<bool> isEnabled() async {
    if (kIsWeb) return false;
    try {
      return await _channel.invokeMethod<bool>('isNotificationAccessEnabled') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> openSettings() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } on PlatformException {
      // no-op
    }
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  _PermissionStep _step = _PermissionStep.restrictedSettings;

  bool _isBusy = false;
  bool _waitingNotificationReturn = false;
  bool _waitingAppSettingsReturn = false;

  String? _smsMessage;
  String? _notificationMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_waitingAppSettingsReturn) {
        _waitingAppSettingsReturn = false;
        _checkAfterAppSettings();
      } else if (_waitingNotificationReturn) {
        _waitingNotificationReturn = false;
        _checkNotificationAndProceed();
      }
    }
  }

  Future<void> _openAppSettingsForRestricted() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    _waitingAppSettingsReturn = true;
    await _AppSettingsHelper.openAppSettings();

    if (!mounted) return;
    setState(() => _isBusy = false);
  }

  Future<void> _checkAfterAppSettings() async {
    // Move to SMS step regardless — user may or may not have toggled it
    setState(() {
      _step = _PermissionStep.sms;
    });
  }

  void _skipRestrictedStep() {
    setState(() {
      _step = _PermissionStep.sms;
    });
  }

  Future<void> _requestSmsPermission() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _smsMessage = null;
    });

    if (kIsWeb) {
      setState(() {
        _isBusy = false;
        _step = _PermissionStep.notifications;
      });
      return;
    }

    final status = await Permission.sms.request();

    if (!mounted) return;

    if (status.isGranted) {
      setState(() {
        _isBusy = false;
        _step = _PermissionStep.notifications;
      });
      return;
    }

    setState(() {
      _isBusy = false;
      _smsMessage =
          'SMS access helps automatic transaction detection. You can continue, but tracking will be limited until permission is enabled.';
    });
  }

  void _skipSmsStep() {
    _proceedToScanning();
  }

  Future<void> _enableNotifications() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _notificationMessage = null;
    });

    _waitingNotificationReturn = true;
    await _NotifListenerHelper.openSettings();

    if (!mounted) return;
    setState(() {
      _isBusy = false;
    });
  }

  Future<void> _checkNotificationAndProceed() async {
    final enabled = await _NotifListenerHelper.isEnabled();
    if (!mounted) return;

    if (enabled) {
      _proceedToScanning();
      return;
    }

    setState(() {
      _notificationMessage =
          'Notification access is still disabled. Enable it to detect payment notifications instantly.';
    });
  }

  void _skipNotificationStep() {
    _proceedToScanning();
  }

  void _proceedToScanning() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ScanningScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.scaffoldDark : AppTheme.scaffoldLight,
      body: Stack(
        children: [
          _Backdrop(isDark: isDark),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_step == _PermissionStep.restrictedSettings)
                      _RestrictedSettingsCard(
                        isBusy: _isBusy,
                        onOpenSettings: _openAppSettingsForRestricted,
                        onSkip: _skipRestrictedStep,
                      )
                    else if (_step == _PermissionStep.sms)
                      _SmsPermissionCard(
                        isBusy: _isBusy,
                        message: _smsMessage,
                        onAllow: _requestSmsPermission,
                        onNotNow: _skipSmsStep,
                      )
                    else
                      _NotificationPermissionCard(
                        isBusy: _isBusy,
                        message: _notificationMessage,
                        onEnable: _enableNotifications,
                        onNotNow: _skipNotificationStep,
                      ),
                    const SizedBox(height: 14),
                    Text(
                      'This app analyzes your bank SMS and payment notifications to automatically detect transactions and generate spending insights.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white70, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestrictedSettingsCard extends StatelessWidget {
  final bool isBusy;
  final VoidCallback onOpenSettings;
  final VoidCallback onSkip;

  const _RestrictedSettingsCard({
    required this.isBusy,
    required this.onOpenSettings,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return _PermissionCard(
      title: 'Allow Restricted Settings',
      description:
          'Google Play Protect may block SMS access. To fix this, open App Settings → tap ⋮ (3-dot menu) → "Allow restricted settings". This lets PayTrace read your bank messages.',
      primaryLabel: 'Open App Settings',
      secondaryLabel: 'Skip',
      icon: Icons.security_rounded,
      message: null,
      isBusy: isBusy,
      onPrimary: onOpenSettings,
      onSecondary: onSkip,
    );
  }
}

class _SmsPermissionCard extends StatelessWidget {
  final bool isBusy;
  final String? message;
  final VoidCallback onAllow;
  final VoidCallback onNotNow;

  const _SmsPermissionCard({
    required this.isBusy,
    required this.message,
    required this.onAllow,
    required this.onNotNow,
  });

  @override
  Widget build(BuildContext context) {
    return _PermissionCard(
      title: '"PayTrace" wants SMS access',
      description:
          'We scan bank transaction messages to automatically track your expenses. Your personal messages are never stored.',
      primaryLabel: 'Allow',
      secondaryLabel: 'Don’t Allow',
      icon: Icons.sms_rounded,
      message: message,
      isBusy: isBusy,
      onPrimary: onAllow,
      onSecondary: onNotNow,
    );
  }
}

class _NotificationPermissionCard extends StatelessWidget {
  final bool isBusy;
  final String? message;
  final VoidCallback onEnable;
  final VoidCallback onNotNow;

  const _NotificationPermissionCard({
    required this.isBusy,
    required this.message,
    required this.onEnable,
    required this.onNotNow,
  });

  @override
  Widget build(BuildContext context) {
    return _PermissionCard(
      title: '"PayTrace" wants notification access',
      description:
          'We read payment notifications from apps like GPay and PhonePe to detect transactions instantly.',
      primaryLabel: 'Enable Notifications',
      secondaryLabel: 'Don’t Allow',
      icon: Icons.notifications_active_rounded,
      message: message,
      isBusy: isBusy,
      onPrimary: onEnable,
      onSecondary: onNotNow,
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final String title;
  final String description;
  final String primaryLabel;
  final String secondaryLabel;
  final IconData icon;
  final String? message;
  final bool isBusy;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  const _PermissionCard({
    required this.title,
    required this.description,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.icon,
    required this.message,
    required this.isBusy,
    required this.onPrimary,
    required this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
            child: Column(
              children: [
                Icon(icon, color: const Color(0xFF4A4A52), size: 26),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F1F2A),
                        fontSize: 20,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF4D4D58),
                        height: 1.35,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (message != null) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFCC80),
                ),
              ),
              child: Text(
                message!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF8A5100),
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const Divider(height: 1, thickness: 1, color: Color(0xFFE3E3E8)),
          SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: isBusy ? null : onSecondary,
                    style: TextButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                        ),
                      ),
                    ),
                    child: Text(
                      secondaryLabel,
                      style: const TextStyle(
                        color: Color(0xFF3B82F6),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE3E3E8)),
                Expanded(
                  child: TextButton(
                    onPressed: isBusy ? null : onPrimary,
                    style: TextButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                    ),
                    child: isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            primaryLabel,
                            style: const TextStyle(
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  final bool isDark;

  const _Backdrop({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4C6A99), Color(0xFF2B4067)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: isDark ? 0.48 : 0.36),
            ),
          ),
        ),
      ],
    );
  }
}
