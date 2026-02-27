import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/notification_service.dart';
import '../../services/sms_service.dart';
import '../../state/providers.dart';

/// SMS permission provider
final smsPermissionProvider = FutureProvider<bool>((ref) {
  if (kIsWeb) return Future.value(false);
  return SmsService.hasSmsPermission();
});

/// Banner widget that prompts user to enable SMS access.
/// SMS is the primary and sufficient detection method.
/// Notification listener is optional and available in Settings.
class NotificationPermissionBanner extends ConsumerWidget {
  const NotificationPermissionBanner({super.key});

  /// Static flag to prevent calling platform methods on every rebuild.
  static bool _listenersActivated = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb) return const SizedBox.shrink();

    final smsAsync = ref.watch(smsPermissionProvider);
    final hasSms = smsAsync.valueOrNull ?? false;

    // If SMS permission granted, ensure listeners are active and hide banner
    if (hasSms) {
      _ensureListenersActiveOnce();
      return const SizedBox.shrink();
    }

    return _buildBanner(context, ref);
  }

  void _ensureListenersActiveOnce() {
    if (_listenersActivated) return;
    _listenersActivated = true;
    NotificationService.paymentNotifications;
    SmsService.bankSmsStream;
  }

  Widget _buildBanner(BuildContext context, WidgetRef ref) {
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
          Row(
            children: [
              Icon(Icons.sms_rounded,
                  size: 22, color: Colors.amber.shade700),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Enable Auto-Detection',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),

          // SMS permission button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final granted = await SmsService.requestSmsPermission();
                if (granted) {
                  ref.invalidate(smsPermissionProvider);
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

          const SizedBox(height: 8),
          Text(
            'PayTrace only reads bank debit/credit SMS to detect transactions. '
            'No personal data is stored or shared.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
          ),
        ],
      ),
    );
  }
}
