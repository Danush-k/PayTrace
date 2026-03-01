import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/notification_service.dart';
import '../../services/sms_service.dart';
import '../../services/upi_service.dart';
import '../../state/providers.dart';

/// SMS permission provider
final smsPermissionProvider = FutureProvider<bool>((ref) {
  if (kIsWeb) return Future.value(false);
  return SmsService.hasSmsPermission();
});

/// Unified SMS permission banner.
/// Combines the SMS permission request + restricted settings guide
/// into a single, easy-to-understand banner.
class NotificationPermissionBanner extends ConsumerStatefulWidget {
  const NotificationPermissionBanner({super.key});

  @override
  ConsumerState<NotificationPermissionBanner> createState() =>
      _NotificationPermissionBannerState();
}

class _NotificationPermissionBannerState
    extends ConsumerState<NotificationPermissionBanner> {
  /// Static flag to prevent calling platform methods on every rebuild.
  static bool _listenersActivated = false;

  /// Whether to show the step-by-step restricted settings guide.
  bool _showGuide = false;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();

    final smsAsync = ref.watch(smsPermissionProvider);
    final hasSms = smsAsync.valueOrNull ?? false;

    // If SMS permission granted, ensure listeners are active and hide banner
    if (hasSms) {
      _ensureListenersActiveOnce();
      return const SizedBox.shrink();
    }

    return _buildBanner(context);
  }

  void _ensureListenersActiveOnce() {
    if (_listenersActivated) return;
    _listenersActivated = true;
    NotificationService.paymentNotifications;
  }

  Widget _buildBanner(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withValues(alpha: 0.15),
            Colors.orange.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Title Row ───
          Row(
            children: [
              Icon(Icons.sms_rounded,
                  size: 22, color: Colors.amber.shade700),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Enable Auto-Detection',
                  style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.amber.shade700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'PayTrace can automatically detect completed payments by '
            'reading your bank\'s debit SMS. Grant SMS permission to enable this.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),

          // ─── Single "Allow SMS Access" button ───
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final granted = await SmsService.requestSmsPermission();
                if (granted) {
                  ref.invalidate(smsPermissionProvider);
                } else {
                  // Permission denied — show the guide to help user
                  if (mounted) {
                    setState(() => _showGuide = true);
                  }
                }
              },
              icon: const Icon(Icons.sms_rounded, size: 16),
              label: const Text('Allow SMS Access'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ─── "Having trouble?" guide toggle ───
          InkWell(
            onTap: () => setState(() => _showGuide = !_showGuide),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.help_outline_rounded,
                    size: 16,
                    color: Colors.amber.shade800,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _showGuide
                        ? 'Hide setup instructions'
                        : 'SMS not working? Tap here for help',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _showGuide
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: Colors.amber.shade800,
                  ),
                ],
              ),
            ),
          ),

          // ─── Expandable restricted settings guide ───
          if (_showGuide) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.grey.shade900.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Some phones block SMS access by default. '
                    'Follow these steps to enable it:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildStep(context, '1', 'Open phone Settings → Apps → PayTrace'),
                  _buildStep(context, '2', 'Tap ⋮ (3 dots) at the top right'),
                  _buildStep(context, '3', 'Select "Allow restricted settings"'),
                  _buildStep(context, '4', 'Come back here and tap "Allow SMS Access"'),
                  const SizedBox(height: 12),

                  // Button to open app settings directly
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await UpiService.openAppSettings();
                      },
                      icon: const Icon(Icons.settings_rounded, size: 16),
                      label: const Text('Open PayTrace in Settings'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amber.shade800,
                        side: BorderSide(color: Colors.amber.shade700),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'After enabling restricted settings above, tap the '
                    '"Allow SMS Access" button again.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          Text(
            'PayTrace only reads bank debit/credit SMS to detect transactions. '
            'No personal data is stored or shared.',
            style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
          ),
        ],
      ),
    );
  }

  /// Build a numbered step row for the guide.
  Widget _buildStep(BuildContext context, String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.amber.shade700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
