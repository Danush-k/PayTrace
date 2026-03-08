import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/utils/sms_transaction_parser.dart';

/// A parsed bank SMS indicating a UPI transaction (debit or credit).
class BankSms {
  final String sender;
  final String body;
  final DateTime timestamp;
  final double? amount;
  final String? refNumber; // UPI ref if found
  final String? accountHint; // Last 4 digits of account
  final bool isCredit; // true = money received, false = money sent
  final String? payeeName; // Extracted payee/payer name from SMS

  const BankSms({
    required this.sender,
    required this.body,
    required this.timestamp,
    this.amount,
    this.refNumber,
    this.accountHint,
    this.isCredit = false,
    this.payeeName,
  });

  @override
  String toString() =>
      'BankSms(sender: $sender, amount: $amount, ref: $refNumber, credit: $isCredit, payee: $payeeName)';
}

/// Listens to incoming bank SMS via BroadcastReceiver EventChannel,
/// parses them for UPI debit details, and provides matching.
class SmsService {
  SmsService._();

  /// Known financial sender IDs. Unknown senders are allowed only when
  /// strong transaction semantics are present in the message body.
  static const _financialSenderWhitelist = <String>{
    'AXISBK',
    'HDFCBK',
    'ICICIB',
    'SBIBNK',
    'SBIINB',
    'SBINOB',
    'PAYTMB',
    'PHONEPE',
    'GPAY',
    'KOTAKB',
    'PNBSMS',
    'CANBNK',
    'BOBSMS',
    'INDBNK',
    'IDFCFB',
  };

  static const _channel = MethodChannel('com.paytrace.paytrace/upi');
  static const _eventChannel =
      EventChannel('com.paytrace.paytrace/sms');

  static final _controller = StreamController<BankSms>.broadcast();
  static bool _platformListening = false;
  static StreamSubscription<dynamic>? _platformSubscription;

  /// Ensures SMS EventChannel subscription is active.
  static void _ensurePlatformListening() {
    if (_platformListening) return;
    _platformListening = true;

    debugPrint('PayTrace: Subscribing to SMS EventChannel');

    // Cancel any stale subscription before creating a new one
    _platformSubscription?.cancel();
    _platformSubscription = _eventChannel.receiveBroadcastStream().listen(
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
        _platformSubscription = null;
        _platformListening = false;
      },
      onDone: () {
        debugPrint('PayTrace: SMS EventChannel closed — will reconnect');
        _platformSubscription = null;
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

    // ── Strong debit indicators (bank-specific language) ──
    final hasStrongDebit = lower.contains('debited') ||
        lower.contains('withdrawn') ||
        lower.contains('transferred');

    // ── Medium debit indicators (need banking context to avoid
    //    matching non-financial SMS like "paid for Hotstar plan") ──
    final hasMediumDebit = lower.contains('sent') ||
        lower.contains('paid') ||
        lower.contains('purchase') ||
        lower.contains('debit');

    // ── Banking / account context ──
    final hasBankContext = lower.contains('a/c') ||
        lower.contains('acct') ||
        lower.contains('account') ||
        lower.contains('upi') ||
        lower.contains('imps') ||
        lower.contains('neft') ||
        lower.contains('txn') ||
        lower.contains('ref no') ||
        lower.contains('vpa') ||
        RegExp(r'\bbank\b', caseSensitive: false).hasMatch(sms.body);

    // Must have some amount indicator
    final hasAmount = lower.contains('rs') ||
        lower.contains('inr') ||
        lower.contains('₹');

    // UPI markers boost confidence
    final hasUpi = lower.contains('upi') ||
        lower.contains('imps') ||
        lower.contains('neft');

    // Must NOT be a credit SMS
    final isCredit = isCreditSms(sms);

    // Strong debit keywords + amount → always accept.
    // Medium debit keywords need banking context.
    // UPI markers alone (with amount) → accept.
    return !isCredit &&
        hasAmount &&
        (hasStrongDebit || (hasMediumDebit && hasBankContext) || hasUpi);
  }

  /// Check if an SMS looks like a credit/received transaction.
  static bool isCreditSms(BankSms sms) {
    final lower = sms.body.toLowerCase();

    final hasCreditKeyword = lower.contains('credited') ||
        lower.contains('received') ||
        lower.contains('credit') ||
        lower.contains('deposited') ||
        lower.contains('added to');

    final hasAmount = lower.contains('rs') ||
        lower.contains('inr') ||
        lower.contains('₹');

    // Exclude credit card bill/EMI SMS
    final isCreditCard = lower.contains('credit card') ||
        lower.contains('card payment') ||
        lower.contains('emi');

    return hasCreditKeyword && hasAmount && !isCreditCard;
  }

  /// Check if an SMS is any UPI transaction (debit or credit).
  static bool isUpiTransactionSms(BankSms sms) {
    return isDebitSms(sms) || isCreditSms(sms);
  }

  /// Extract payee/payer name from bank SMS body.
  ///
  /// Common patterns:
  /// - "Sent to JOHN DOE via UPI"
  /// - "paid to MERCHANT NAME"
  /// - "transferred to PERSON NAME"
  /// - "credited by SENDER NAME"
  /// - "received from SENDER NAME"
  /// - "from PERSON NAME-UPI"
  /// - "Info: UPI/P2P/412345678901/JOHN DOE/person@ybl/SBI"
  /// - "VPA person@ybl (JOHN DOE)"
  static String? extractPayeeName(String text) {
    final patterns = [
      // "Info: UPI/.../PERSON NAME/vpa@bank" — SBI, HDFC, ICICI style
      // Captures the name field between the ref number and the VPA
      RegExp(r'(?:Info|info)\s*:?\s*UPI/[A-Za-z0-9]+/\d+/([A-Za-z][A-Za-z\s.]+?)/[a-zA-Z0-9._-]+@',
          caseSensitive: false),
      // "UPI/P2P/ref/PERSON NAME/vpa" or "UPI/P2M/ref/MERCHANT/vpa"
      RegExp(r'UPI/[A-Za-z0-9]+/\d+/([A-Za-z][A-Za-z\s.]{1,30})/[a-zA-Z0-9._-]+@',
          caseSensitive: false),
      // "to PERSON via UPI" or "to PERSON UPI" (greedy, relaxed first char)
      RegExp(r'(?:to|for)\s+([A-Za-z][A-Za-z\s.]+)\s+(?:via\s+)?(?:UPI|IMPS|NEFT)',
          caseSensitive: false),
      // "from PERSON via UPI" (for credits) — greedy
      RegExp(r'(?:from|by)\s+([A-Za-z][A-Za-z\s.]+)\s+(?:via\s+)?(?:UPI|IMPS|NEFT)',
          caseSensitive: false),
      // "to PERSON Ref" or "from PERSON Ref" — greedy, relaxed
      RegExp(r'(?:to|from|by)\s+([A-Za-z][A-Za-z\s.]{2,30})\s*(?:Ref|ref|REF|UPI)',
          caseSensitive: false),
      // "VPA person@bank (PERSON NAME)" — parenthesized name after VPA
      RegExp(r'(?:VPA\s+)?[a-zA-Z0-9._-]+@[a-zA-Z]+\s*\(([A-Za-z][A-Za-z\s.]+?)\)',
          caseSensitive: false),
      // "to VPA person@bank" — extract VPA as fallback
      RegExp(r'(?:to|from)\s+(?:VPA\s+)?([a-zA-Z0-9._-]+@[a-zA-Z]+)',
          caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        var name = match.group(1)?.trim();
        if (name == null || name.length < 2 || name.length > 40) continue;
        // Clean trailing prepositions / junk that greedy match may capture
        name = name.replaceAll(RegExp(r'\s+(via|on|in|at|is|was|has|the)$', caseSensitive: false), '').trim();
        if (name.length >= 2) return name;
      }
    }
    return null;
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

    // Early filter: reject messages not from banks/financial institutions
    if (!_isLikelyBankSms(sender, body)) {
      debugPrint('PayTrace: Skipping non-bank SMS from $sender');
      return null;
    }

    final amount = _extractAmount(body);
    final refNumber = _extractUpiRef(body);
    final accountHint = _extractAccountHint(body);
    final payeeName = extractPayeeName(body);

    // Determine if credit
    final tempSms = BankSms(
      sender: sender,
      body: body,
      timestamp: timestamp,
      amount: amount,
      refNumber: refNumber,
      accountHint: accountHint,
    );
    final isCredit = isCreditSms(tempSms);

    debugPrint(
      'PayTrace: Parsed SMS → sender=$sender, '
      'amount=$amount, ref=$refNumber, acct=$accountHint, '
      'credit=$isCredit, payee=$payeeName',
    );

    return BankSms(
      sender: sender,
      body: body,
      timestamp: timestamp,
      amount: amount,
      refNumber: refNumber,
      accountHint: accountHint,
      isCredit: isCredit,
      payeeName: payeeName,
    );
  }

  /// Check if an SMS is likely from a bank or financial institution.
  /// Rejects OTT services, subscription notifications, marketing, etc.
  static bool _isLikelyBankSms(String sender, String body) {
    final lower = body.toLowerCase();
    final senderLower = sender.toLowerCase();
    final normalizedSender = sender
        .replaceFirst(RegExp(r'^[A-Z]{2}-'), '')
        .toUpperCase();

    // ── Reject known non-financial senders ──
    const nonFinancialSenders = [
      'hotstar', 'disney', 'netflix', 'spotify', 'youtube',
      'jiocinema', 'sonyliv', 'zee5', 'voot', 'wynk',
      'gaana', 'hungama', 'mxplay',
      'swiggy', 'zomato', 'dunzo', 'blinkit', 'bigbask',
      'flipkart', 'myntra', 'ajio', 'meesho', 'nykaa',
      'ola', 'uber', 'rapido',
      'makemy', 'goibibo', 'cleartrip', 'yatra',
      'bookmyshow', 'pvr', 'inox',
      'dream11', 'mpl', 'winzo',
      'unacad', 'byju', 'vedantu',
      'practo', 'pharmeasy', 'netmeds',
      'linkedinapp', 'twitter', 'instagram',
    ];
    for (final name in nonFinancialSenders) {
      if (senderLower.contains(name)) return false;
    }

    // ── Reject subscription / plan / recharge notifications ──
    if (_isSubscriptionOrPlanSms(lower)) return false;

    final isWhitelistedSender =
      _financialSenderWhitelist.contains(normalizedSender) ||
      _financialSenderWhitelist.any(normalizedSender.contains);

    // Unknown senders are accepted only if they have strong transaction
    // semantics and financial context.
    final hasStrongTransactionKeyword = lower.contains('debited') ||
      lower.contains('credited') ||
      lower.contains('spent') ||
      lower.contains('paid') ||
      lower.contains('sent') ||
      lower.contains('received') ||
      lower.contains('transferred') ||
      lower.contains('deposited') ||
      lower.contains('withdrawn') ||
      lower.contains('txn') ||
      lower.contains('ref no');

    // ── Must contain at least one banking / financial keyword ──
    // Real bank SMS always reference accounts, UPI, or use
    // bank-specific transaction language.
    final hasBankIndicator = lower.contains('a/c') ||
        lower.contains('acct') ||
        lower.contains('debited') ||
        lower.contains('credited') ||
        lower.contains('upi') ||
        lower.contains('imps') ||
        lower.contains('neft') ||
        lower.contains('rtgs') ||
        lower.contains('txn') ||
        lower.contains('ref no') ||
        lower.contains('vpa') ||
        lower.contains('avl bal') ||
        lower.contains('available bal') ||
        lower.contains('transferred') ||
        lower.contains('withdrawn') ||
        (lower.contains('account') &&
            (lower.contains('debit') ||
                lower.contains('credit') ||
                lower.contains('transfer') ||
                lower.contains('withdraw')));

    if (!isWhitelistedSender && !hasStrongTransactionKeyword) {
      return false;
    }

    return hasBankIndicator;
  }

  /// Detect subscription / plan / recharge SMS that mention amounts
  /// but are NOT actual bank transaction alerts.
  static bool _isSubscriptionOrPlanSms(String lowerBody) {
    // ── Subscription / plan renewals ──
    final hasSubKeyword = lowerBody.contains('subscription') ||
        lowerBody.contains('subscribe') ||
        lowerBody.contains('renew') ||
        lowerBody.contains('membership');

    final hasSubContext = lowerBody.contains('activated') ||
        lowerBody.contains('expire') ||
        lowerBody.contains('valid till') ||
        lowerBody.contains('valid for') ||
        lowerBody.contains('enjoy') ||
        lowerBody.contains('watch') ||
        lowerBody.contains('stream') ||
        lowerBody.contains('download') ||
        lowerBody.contains('premium') ||
        lowerBody.contains('upgrade');

    if (hasSubKeyword && hasSubContext) return true;

    // Also reject if body explicitly mentions OTT / service names
    final hasOttName = lowerBody.contains('hotstar') ||
        lowerBody.contains('netflix') ||
        lowerBody.contains('spotify') ||
        lowerBody.contains('jiocinema') ||
        lowerBody.contains('zee5') ||
        lowerBody.contains('sonyliv') ||
        lowerBody.contains('amazon prime') ||
        lowerBody.contains('youtube premium') ||
        lowerBody.contains('disney+');

    if (hasOttName && hasSubKeyword) return true;

    // ── Recharge / data pack ──
    final hasRechargeKeyword = lowerBody.contains('recharge') ||
        lowerBody.contains('data pack') ||
        lowerBody.contains('talktime') ||
        lowerBody.contains('validity');

    final hasRechargeContext = lowerBody.contains('gb') ||
        lowerBody.contains('unlimited') ||
        (lowerBody.contains('days') && lowerBody.contains('valid'));

    if (hasRechargeKeyword && hasRechargeContext) return true;

    return false;
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

  // ═══════════════════════════════════════════════════════════
  //  INTELLIGENT PARSER BRIDGE
  // ═══════════════════════════════════════════════════════════

  /// Parse an SMS using the intelligent [SmsTransactionParser].
  ///
  /// Returns a [ParsedTransaction] if the message is a valid
  /// financial transaction, or `null` if it should be ignored.
  /// This provides richer output than the legacy [_parseSms]
  /// method, including category inference and confidence scoring.
  static ParsedTransaction? parseTransaction({
    required String body,
    required String sender,
    required DateTime timestamp,
  }) {
    return SmsTransactionParser.parse(
      body: body,
      sender: sender,
      timestamp: timestamp,
    );
  }

  /// Parse a raw platform-channel SMS map using the intelligent parser.
  static ParsedTransaction? parseTransactionRaw(Map<String, String> data) {
    return SmsTransactionParser.parseRaw(data);
  }

  /// Convert a [ParsedTransaction] back to a [BankSms] for backward
  /// compatibility with existing code that expects [BankSms] objects.
  static BankSms? parsedToBankSms(ParsedTransaction parsed, {
    required String sender,
    required String body,
  }) {
    return BankSms(
      sender: sender,
      body: body,
      timestamp: parsed.timestamp,
      amount: parsed.amount,
      refNumber: parsed.upiRef,
      accountHint: parsed.accountHint,
      isCredit: parsed.isIncome,
      payeeName: parsed.merchant,
    );
  }
}
