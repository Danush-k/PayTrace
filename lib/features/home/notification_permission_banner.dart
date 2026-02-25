import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/upi_service.dart';
import '../../services/notification_service.dart';
import '../../services/sms_service.dart';
import '../../state/providers.dart';

/// SMS permission provider
final smsPermissionProvider = FutureProvider<bool>((ref) {
  return SmsService.hasSmsPermission();
});

/// Banner widget that prompts user to enable SMS + notification access.
/// SMS is the primary detection method; notifications are secondary.
class NotificationPermissionBanner extends ConsumerWidget {
  const NotificationPermissionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final smsAsync = ref.watch(smsPermissionProvider);
    final notifAsync = ref.watch(notificationAccessProvider);

    final hasSms = smsAsync.valueOrNull ?? false;
    final hasNotif = notifAsync.valueOrNull ?? false;

    // If both permissions granted, ensure listeners are active
    if (hasSms && hasNotif) {
      _ensureListenersActive();
      return const SizedBox.shrink();
    }

    // If at least SMS is granted, ensure SMS stream + start listeners
    if (hasSms) {
      SmsService.bankSmsStream; // ensure listening
      _ensureListenersActive();
    }

    // Show banner if either permission is missing
    if (hasSms && !hasNotif) {
      // SMS is granted — notification is optional, show subtle hint
      return const SizedBox.shrink(); // SMS alone is enough
    }

    return _buildBanner(context, ref, hasSms: hasSms, hasNotif: hasNotif);
  }

  void _ensureListenersActive() {
    UpiService.rebindNotificationListener();
    NotificationService.paymentNotifications;
    SmsService.bankSmsStream;
  }

  Widget _buildBanner(BuildContext context, WidgetRef ref,
      {required bool hasSms, required bool hasNotif}) {
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

          // SMS permission button (primary)
          if (!hasSms)
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

          if (!hasSms) const SizedBox(height: 8),

          // Notification access button (secondary)
          if (!hasNotif)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await UpiService.openNotificationSettings();
                  ref.invalidate(notificationAccessProvider);
                },
                icon: const Icon(Icons.notifications_rounded, size: 16),
                label: const Text('Enable Notification Access (optional)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  side: BorderSide(color: Colors.grey.shade400),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),

          const SizedBox(height: 8),
          Text(
            'PayTrace only reads bank debit SMS and UPI app notifications. '
            'No personal data is accessed.',
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
