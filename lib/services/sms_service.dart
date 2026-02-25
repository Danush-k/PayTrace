import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A parsed bank SMS indicating a UPI debit.
class BankSms {
  final String sender;
  final String body;
  final DateTime timestamp;
  final double? amount;
  final String? refNumber; // UPI ref if found
  final String? accountHint; // Last 4 digits of account

  const BankSms({
    required this.sender,
    required this.body,
    required this.timestamp,
    this.amount,
    this.refNumber,
    this.accountHint,
  });

  @override
  String toString() =>
      'BankSms(sender: $sender, amount: $amount, ref: $refNumber)';
}

/// Listens to incoming bank SMS via BroadcastReceiver EventChannel,
/// parses them for UPI debit details, and provides matching.
class SmsService {
  SmsService._();

  static const _channel = MethodChannel('com.paytrace.paytrace/upi');
  static const _eventChannel =
      EventChannel('com.paytrace.paytrace/sms');

  static final _controller = StreamController<BankSms>.broadcast();
  static bool _platformListening = false;

  /// Ensures SMS EventChannel subscription is active.
  static void _ensurePlatformListening() {
    if (_platformListening) return;
    _platformListening = true;

    debugPrint('PayTrace: Subscribing to SMS EventChannel');

    _eventChannel.receiveBroadcastStream().listen(
      (event) {
        debugPrint('PayTrace: Raw SMS event: $event');
        try {
          final sms = _parseSms(Map<String, String>.from(event));
          if (sms != null) {
            _controller.add(sms);
          }
        } catch (e) {
          debugPrint('PayTrace: Error parsing SMS: $e');
        }
      },
      onError: (e) {
        debugPrint('PayTrace: SMS EventChannel error: $e — will reconnect');
        _platformListening = false;
      },
      onDone: () {
        debugPrint('PayTrace: SMS EventChannel closed — will reconnect');
        _platformListening = false;
      },
    );
  }

  /// Stream of parsed bank debit SMS.
  static Stream<BankSms> get bankSmsStream {
    _ensurePlatformListening();
    return _controller.stream;
  }

  /// Check if SMS permission is granted.
  static Future<bool> hasSmsPermission() async {
    try {
      final result = await _channel.invokeMethod('hasSmsPermission');
      return result == true;
    } on PlatformException {
      return false;
    }
  }

  /// Request SMS permission from user.
  /// Returns true if granted.
  static Future<bool> requestSmsPermission() async {
    try {
      final result = await _channel.invokeMethod('requestSmsPermission');
      return result == true;
    } on PlatformException {
      return false;
    }
  }

  /// Read recent SMS from inbox via ContentResolver (polling approach).
  /// This is MORE RELIABLE than BroadcastReceiver because it reads from the
  /// actual SMS database — works even if the broadcast was suppressed by
  /// OEM battery optimization.
  ///
  /// Returns a list of parsed BankSms received after [since].
  static Future<List<BankSms>> readRecentSms({required DateTime since}) async {
    try {
      final result = await _channel.invokeMethod('readRecentSms', {
        'since': since.millisecondsSinceEpoch,
      });

      if (result == null) return [];

      final list = List<Map>.from(result);
      final parsed = <BankSms>[];

      for (final item in list) {
        final data = Map<String, String>.from(item);
        final sms = _parseSms(data);
        if (sms != null) {
          debugPrint('PayTrace: Inbox SMS → $sms');
          parsed.add(sms);
        }
      }

      debugPrint('PayTrace: readRecentSms found ${parsed.length} bank SMS since $since');
      return parsed;
    } on PlatformException catch (e) {
      debugPrint('PayTrace: readRecentSms error: $e');
      return [];
    }
  }

  /// Poll the SMS inbox for a matching debit SMS.
  /// Polls every [interval] for up to [timeout] duration.
  /// Returns the matching BankSms if found, null if timed out.
  ///
  /// When [pendingAmount] is 0 or less, matches ANY debit SMS (amount-free mode).
  static Future<BankSms?> pollForPaymentSms({
    required double pendingAmount,
    required DateTime paymentStartTime,
    Duration interval = const Duration(seconds: 3),
    Duration timeout = const Duration(seconds: 90),
    void Function(int smsCount)? onPollUpdate,
  }) async {
    final amountFree = pendingAmount <= 0;
    debugPrint('PayTrace: Starting SMS poll — amount=$pendingAmount (amountFree=$amountFree), since=$paymentStartTime');

    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final smsList = await readRecentSms(since: paymentStartTime);

      debugPrint('PayTrace: SMS poll cycle — found ${smsList.length} SMS to check');
      onPollUpdate?.call(smsList.length);

      for (final sms in smsList) {
        if (amountFree) {
          // Amount-free mode: match ANY SMS that looks like a debit transaction
          if (isDebitSms(sms) && sms.amount != null && sms.amount! > 0) {
            debugPrint('PayTrace: SMS poll matched (amount-free)! sender=${sms.sender}, amount=${sms.amount}, ref=${sms.refNumber}');
            return sms;
          }
        } else {
          // Normal mode: match by amount
          if (matchesPending(sms: sms, pendingAmount: pendingAmount)) {
            debugPrint('PayTrace: SMS poll matched! sender=${sms.sender}, amount=${sms.amount}, ref=${sms.refNumber}');
            return sms;
          }
        }
      }

      // Wait before next poll
      await Future.delayed(interval);
    }

    debugPrint('PayTrace: SMS poll timed out after $timeout');
    return null;
  }

  /// Check if an SMS looks like a debit/payment transaction.
  /// Used in amount-free mode to match ANY debit SMS.
  static bool isDebitSms(BankSms sms) {
    final lower = sms.body.toLowerCase();

    // Must have debit/payment indicators
    final hasDebit = lower.contains('debit') ||
        lower.contains('sent') ||
        lower.contains('paid') ||
        lower.contains('transferred') ||
        lower.contains('withdrawn') ||
        lower.contains('purchase') ||
        lower.contains('transaction');

    // Must have some amount indicator
    final hasAmount = lower.contains('rs') ||
        lower.contains('inr') ||
        lower.contains('₹');

    // UPI markers boost confidence
    final hasUpi = lower.contains('upi') ||
        lower.contains('imps') ||
        lower.contains('neft');

    return hasAmount && (hasDebit || hasUpi);
  }

  /// Parse raw SMS data into a BankSms object.
  static BankSms? _parseSms(Map<String, String> data) {
    final sender = data['sender'] ?? '';
    final body = data['body'] ?? '';
    final timestampStr = data['timestamp'] ?? '0';
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      int.tryParse(timestampStr) ?? 0,
    );

    if (body.isEmpty) return null;

    final amount = _extractAmount(body);
    final refNumber = _extractUpiRef(body);
    final accountHint = _extractAccountHint(body);

    debugPrint(
      'PayTrace: Parsed SMS → sender=$sender, '
      'amount=$amount, ref=$refNumber, acct=$accountHint',
    );

    return BankSms(
      sender: sender,
      body: body,
      timestamp: timestamp,
      amount: amount,
      refNumber: refNumber,
      accountHint: accountHint,
    );
  }

  /// Extract amount from bank SMS.
  ///
  /// Common patterns:
  /// - "Rs.500.00 debited"
  /// - "INR 1,500 has been debited"
  /// - "₹200 sent to"
  /// - "Transaction of Rs 500.00"
  /// - "debited by Rs.150.00"
  /// - "You have done a UPI txn of Rs 500"
  static double? _extractAmount(String text) {
    final patterns = [
      // ₹ symbol
      RegExp(r'[₹]\s?([\d,]+\.?\d{0,2})'),
      // Rs or Rs. followed by amount
      RegExp(r'Rs\.?\s?([\d,]+\.?\d{0,2})', caseSensitive: false),
      // INR followed by amount
      RegExp(r'INR\s?([\d,]+\.?\d{0,2})', caseSensitive: false),
      // "of Rs X" or "for Rs X"
      RegExp(
        r'(?:of|for|by)\s+(?:Rs\.?|INR|₹)\s?([\d,]+\.?\d{0,2})',
        caseSensitive: false,
      ),
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

  /// Extract UPI reference number from SMS.
  ///
  /// Common patterns:
  /// - "UPI Ref No 123456789012"
  /// - "UPI Ref: 123456789012"
  /// - "UPI/P2P/123456789012"
  /// - "Ref no. 123456789012"
  /// - "TxnId: 123456789012"
  static String? _extractUpiRef(String text) {
    final patterns = [
      RegExp(r'UPI\s*(?:Ref|ref)\.?\s*(?:No|no)?\.?\s*:?\s*(\d{8,14})',
          caseSensitive: false),
      RegExp(r'UPI/\w+/(\d{8,14})', caseSensitive: false),
      RegExp(r'Ref\s*(?:No|no)?\.?\s*:?\s*(\d{8,14})',
          caseSensitive: false),
      RegExp(r'TxnId\s*:?\s*(\d{8,14})', caseSensitive: false),
      RegExp(r'Txn\s*(?:No|no)?\.?\s*:?\s*(\d{8,14})',
          caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  /// Extract last 4 digits of account number.
  ///
  /// Common patterns:
  /// - "A/c XX1234"
  /// - "a/c *1234"
  /// - "account ending 1234"
  /// - "A/c no XX1234"
  static String? _extractAccountHint(String text) {
    final patterns = [
      RegExp(r'[Aa]/[Cc]\s*(?:[Nn]o)?\.?\s*[*xX]*(\d{4})\b'),
      RegExp(r'account\s+(?:ending|no\.?)\s*[*xX]*(\d{4})\b',
          caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  /// Match a bank SMS against a pending payment.
  ///
  /// Strategy:
  /// 1. Amount match (within ₹0.50 tolerance)
  /// 2. Raw amount string in SMS body
  /// 3. UPI keyword + debit keyword as loose match
  static bool matchesPending({
    required BankSms sms,
    required double pendingAmount,
  }) {
    // ── Strategy 1: Parsed amount match ──
    if (sms.amount != null) {
      final diff = (sms.amount! - pendingAmount).abs();
      if (diff <= 0.50) {
        debugPrint(
          'PayTrace: SMS matchesPending → AMOUNT MATCH '
          '(pending=$pendingAmount, sms=${sms.amount})',
        );
        return true;
      }
    }

    // ── Strategy 2: Raw text amount search ──
    final amountStr = pendingAmount.toStringAsFixed(2);
    final amountIntStr = pendingAmount.toStringAsFixed(0);
    final body = sms.body;

    if (body.contains(amountStr) || body.contains(amountIntStr)) {
      debugPrint(
        'PayTrace: SMS matchesPending → RAW TEXT AMOUNT MATCH '
        '(looking for $amountStr or $amountIntStr)',
      );
      return true;
    }

    // ── Strategy 3: Amount with commas ──
    // e.g., 1500 → "1,500"
    if (pendingAmount >= 1000) {
      final formatted = _formatWithCommas(pendingAmount);
      if (body.contains(formatted)) {
        debugPrint(
          'PayTrace: SMS matchesPending → COMMA FORMAT MATCH ($formatted)',
        );
        return true;
      }
    }

    debugPrint(
      'PayTrace: SMS matchesPending → NO MATCH '
      '(pending=$pendingAmount, sms amount=${sms.amount})',
    );
    return false;
  }

  /// Format a number with Indian comma style (1,50,000)
  static String _formatWithCommas(double amount) {
    final intPart = amount.truncate();
    final str = intPart.toString();
    if (str.length <= 3) return str;

    // Last 3 digits
    final last3 = str.substring(str.length - 3);
    final remaining = str.substring(0, str.length - 3);

    // Group remaining by 2
    final buffer = StringBuffer();
    for (var i = 0; i < remaining.length; i++) {
      if (i > 0 && (remaining.length - i) % 2 == 0) {
        buffer.write(',');
      }
      buffer.write(remaining[i]);
    }
    buffer.write(',');
    buffer.write(last3);

    return buffer.toString();
  }
}
