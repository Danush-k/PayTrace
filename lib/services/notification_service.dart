import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A parsed payment notification from GPay/PhonePe/etc.
class PaymentNotification {
  final String packageName;
  final String title;
  final String text;
  final DateTime timestamp;
  final double? amount;
  final String? payeeName;
  final bool isDebit; // true = money sent, false = money received

  const PaymentNotification({
    required this.packageName,
    required this.title,
    required this.text,
    required this.timestamp,
    this.amount,
    this.payeeName,
    required this.isDebit,
  });

  @override
  String toString() =>
      'PaymentNotification(pkg: $packageName, amount: $amount, '
      'payee: $payeeName, isDebit: $isDebit)';
}

/// Listens to payment notifications from the Android NotificationListenerService
/// via an EventChannel, parses them, and exposes a notification stream.
class NotificationService {
  NotificationService._();

  static const _eventChannel =
      EventChannel('com.paytrace.paytrace/notifications');

  /// Persistent broadcast controller — multiple listeners can subscribe/cancel
  /// without affecting the underlying EventChannel subscription.
  static final _controller = StreamController<PaymentNotification>.broadcast();

  /// Whether we've already subscribed to the EventChannel.
  static bool _platformListening = false;

  /// Ensures the EventChannel subscription is active.
  /// Called automatically when accessing [paymentNotifications].
  static void _ensurePlatformListening() {
    if (_platformListening) return;
    _platformListening = true;

    debugPrint('PayTrace: Subscribing to EventChannel for notifications');

    _eventChannel.receiveBroadcastStream().listen(
      (event) {
        debugPrint('PayTrace: Raw notification event: $event');
        try {
          final notif =
              _parseNotification(Map<String, String>.from(event));
          if (notif != null) {
            _controller.add(notif);
          }
        } catch (e) {
          debugPrint('PayTrace: Error parsing notification: $e');
        }
      },
      onError: (e) {
        debugPrint('PayTrace: EventChannel error: $e — will reconnect');
        _platformListening = false;
        // Try to reconnect on next access
      },
      onDone: () {
        debugPrint('PayTrace: EventChannel closed — will reconnect');
        _platformListening = false;
      },
    );
  }

  /// Stream of payment notifications.
  /// Multiple listeners can subscribe without conflicting.
  /// The EventChannel subscription persists independently.
  static Stream<PaymentNotification> get paymentNotifications {
    _ensurePlatformListening();
    return _controller.stream;
  }

  /// Parse a raw notification map into a PaymentNotification.
  /// More permissive — returns any notification with a detectable amount.
  static PaymentNotification? _parseNotification(Map<String, String> data) {
    final packageName = data['package'] ?? '';
    final title = data['title'] ?? '';
    final text = data['text'] ?? '';
    final timestampStr = data['timestamp'] ?? '0';
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      int.tryParse(timestampStr) ?? 0,
    );

    if (text.isEmpty && title.isEmpty) return null;

    final combined = '$title $text';
    final combinedLower = combined.toLowerCase();

    // Try to extract amount from both title and text
    final amount = _extractAmount(combined);

    // Determine debit vs credit
    final isDebit = _isDebit(combinedLower);

    // Try to extract payee name
    final payeeName = _extractPayeeName(combined, packageName);

    debugPrint(
      'PayTrace: Parsed notification → pkg=$packageName, '
      'amount=$amount, payee=$payeeName, isDebit=$isDebit, '
      'title="$title", text="$text"',
    );

    // Return even if amount is null — let the matcher decide
    return PaymentNotification(
      packageName: packageName,
      title: title,
      text: text,
      timestamp: timestamp,
      amount: amount,
      payeeName: payeeName,
      isDebit: isDebit,
    );
  }

  /// Extract amount from notification text.
  ///
  /// Common patterns:
  /// - "Paid ₹150.00 to John"
  /// - "₹500 sent to xyz@ybl"
  /// - "You paid Rs. 200 to Store"
  /// - "Sent Rs 1,500.00 to ..."
  /// - "Payment of INR 250.00 successful"
  static double? _extractAmount(String text) {
    // Pattern: ₹ or Rs or Rs. or INR followed by optional space and amount
    final patterns = [
      RegExp(r'[₹]\s?([\d,]+\.?\d{0,2})'),
      RegExp(r'Rs\.?\s?([\d,]+\.?\d{0,2})', caseSensitive: false),
      RegExp(r'INR\s?([\d,]+\.?\d{0,2})', caseSensitive: false),
      RegExp(r'(?:paid|sent|debited|transferred)\s+(?:₹|Rs\.?|INR)?\s?([\d,]+\.?\d{0,2})', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final amountStr = match.group(1)?.replaceAll(',', '');
        if (amountStr != null) {
          final amount = double.tryParse(amountStr);
          if (amount != null && amount > 0) return amount;
        }
      }
    }

    return null;
  }

  /// Check if notification indicates money was SENT (debit).
  static bool _isDebit(String text) {
    final debitKeywords = [
      'paid',
      'sent',
      'debited',
      'transferred',
      'payment successful',
      'payment of',
      'you paid',
      'money sent',
    ];
    final creditKeywords = [
      'received',
      'credited',
      'got',
      'money received',
      'you got',
    ];

    for (final kw in creditKeywords) {
      if (text.contains(kw)) return false;
    }
    for (final kw in debitKeywords) {
      if (text.contains(kw)) return true;
    }

    // Default to debit if amount is present (most payment notifications are debits)
    return true;
  }

  /// Try to extract payee name from notification text.
  ///
  /// Common patterns:
  /// - "Paid ₹150 to John Doe"
  /// - "Sent to xyz@ybl"
  /// - "Payment to Store Name successful"
  static String? _extractPayeeName(String text, String packageName) {
    // Pattern: "to <name>" — capture what's after "to"
    final toPatterns = [
      RegExp(r'(?:paid|sent|transferred)\s+(?:₹|Rs\.?|INR)?\s?[\d,]+\.?\d{0,2}\s+to\s+(.+?)(?:\s+on|\s+via|\s*[.!]|\s*$)', caseSensitive: false),
      RegExp(r'to\s+(.+?)(?:\s+on|\s+via|\s+using|\s+from|\s*[.!]|\s*$)', caseSensitive: false),
    ];

    for (final pattern in toPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final name = match.group(1)?.trim();
        if (name != null && name.isNotEmpty && name.length < 50) {
          return name;
        }
      }
    }

    return null;
  }

  /// Match a notification against a pending payment.
  /// Returns true if the notification likely corresponds to this payment.
  ///
  /// Strategy: Amount match is the primary signal. But if no amount was
  /// parsed (some apps format differently), look for success keywords
  /// combined with approximate payee name match.
  static bool matchesPending({
    required PaymentNotification notification,
    required double pendingAmount,
    String? pendingPayeeName,
  }) {
    final fullText =
        '${notification.title} ${notification.text}'.toLowerCase();

    // ── Strategy 1: Amount match ──
    if (notification.amount != null) {
      final amountDiff = (notification.amount! - pendingAmount).abs();
      if (amountDiff <= 0.50) {
        debugPrint(
          'PayTrace: matchesPending → AMOUNT MATCH '
          '(pending=$pendingAmount, notif=${notification.amount})',
        );
        return true;
      }
    }

    // ── Strategy 2: Success keyword + payee name match ──
    // If amount couldn't be parsed but notification text mentions success
    // and contains the payee name, treat it as a match
    final hasSuccessKeyword = [
      'success',
      'paid',
      'sent',
      'debited',
      'completed',
      'transferred',
    ].any((kw) => fullText.contains(kw));

    if (hasSuccessKeyword && pendingPayeeName != null) {
      final nameLower = pendingPayeeName.toLowerCase();
      if (nameLower.isNotEmpty && fullText.contains(nameLower)) {
        debugPrint(
          'PayTrace: matchesPending → NAME+KEYWORD MATCH '
          '(payee=$pendingPayeeName)',
        );
        return true;
      }
    }

    // ── Strategy 3: Amount string in raw text ──
    // Some notifications have amounts but in non-standard formats
    final amountStr = pendingAmount.toStringAsFixed(2);
    final amountIntStr = pendingAmount.toStringAsFixed(0);
    if (fullText.contains(amountStr) || fullText.contains(amountIntStr)) {
      debugPrint(
        'PayTrace: matchesPending → RAW TEXT AMOUNT MATCH '
        '(looking for $amountStr or $amountIntStr)',
      );
      return true;
    }

    debugPrint(
      'PayTrace: matchesPending → NO MATCH '
      '(pending=$pendingAmount/$pendingPayeeName, '
      'notif amount=${notification.amount}, text="${notification.text}")',
    );
    return false;
  }
}
