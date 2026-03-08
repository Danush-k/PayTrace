import 'package:flutter/foundation.dart';

import 'category_engine.dart';

// ═════════════════════════════════════════════════════════════════════
//  SMS TRANSACTION PARSER
//
//  A robust, production-grade parser that extracts structured financial
//  transaction data from Indian bank SMS messages.
//
//  Design principles:
//    1. Whitelist approach — only accept messages with strong banking
//       signals (account refs, UPI keywords, bank language).
//    2. Blacklist layer — reject promotional / OTT / subscription SMS
//       even if they slip past the whitelist (defense in depth).
//    3. Multi-regex extraction — try multiple patterns for each field
//       (amount, merchant, ref), returning the highest-confidence hit.
//    4. Category inference — map extracted merchant names to spending
//       categories using the existing CategoryEngine.
// ═════════════════════════════════════════════════════════════════════

/// The result of parsing a single SMS message.
/// Returns `null` from [SmsTransactionParser.parse] when the message
/// is not a valid financial transaction.
class ParsedTransaction {
  /// Monetary value of the transaction.
  final double amount;

  /// Extracted merchant / payee / payer name.
  final String merchant;

  /// `expense` (money sent) or `income` (money received).
  final String type;

  /// Auto-inferred spending category (from [CategoryEngine]).
  final String category;

  /// Timestamp of the SMS (or best-effort extraction from body).
  final DateTime timestamp;

  /// UPI reference number, if found.
  final String? upiRef;

  /// Last 4 digits of account, if found.
  final String? accountHint;

  /// Raw UPI ID / VPA extracted from the message body.
  final String? upiId;

  /// Confidence score (0.0 – 1.0) indicating how certain the parser
  /// is that this is a real transaction.
  final double confidence;

  const ParsedTransaction({
    required this.amount,
    required this.merchant,
    required this.type,
    required this.category,
    required this.timestamp,
    this.upiRef,
    this.accountHint,
    this.upiId,
    this.confidence = 1.0,
  });

  /// True when the transaction represents money leaving the account.
  bool get isExpense => type == 'expense';

  /// True when the transaction represents money entering the account.
  bool get isIncome => type == 'income';

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'merchant': merchant,
        'type': type,
        'category': category,
        'timestamp': timestamp.toIso8601String(),
        if (upiRef != null) 'upiRef': upiRef,
        if (accountHint != null) 'accountHint': accountHint,
        if (upiId != null) 'upiId': upiId,
        'confidence': confidence,
      };

  @override
  String toString() =>
      'ParsedTransaction($type ₹$amount → $merchant [$category] '
      'confidence=${(confidence * 100).toStringAsFixed(0)}%)';
}

/// Intelligent SMS transaction parser.
///
/// Usage:
/// ```dart
/// final result = SmsTransactionParser.parse(
///   body: smsBody,
///   sender: smsSender,
///   timestamp: smsTimestamp,
/// );
/// if (result != null) {
///   print('₹${result.amount} ${result.type} → ${result.merchant}');
/// }
/// ```
class SmsTransactionParser {
  SmsTransactionParser._();

  // ─────────────────────────────────────────────────────────
  //  KEYWORD DICTIONARIES
  // ─────────────────────────────────────────────────────────

  /// Keywords that unambiguously signal a banking transaction.
  ///
  /// Requirement: a message is a valid transaction if it contains a
  /// currency amount AND at least one of these keywords.
  /// Groups:
  ///   • Transaction verbs : debited, credited, sent, received,
  ///                         transferred, deposited, withdrawn, spent, paid
  ///   • Payment networks  : upi, imps, neft, rtgs
  ///   • Reference markers : txn, ref no
  static const _bankingKeywords = <String>[
    // Transaction verbs
    'debited',
    'credited',
    'sent',
    'received',
    'transferred',
    'deposited',
    'withdrawn',
    'spent',
    'paid',
    // Payment networks
    'upi',
    'imps',
    'neft',
    'rtgs',
    // Reference markers
    'txn',
    'ref no',
  ];

  // Kept for Gate 3 (must-have transaction keyword check).
  static const _transactionKeywords = _bankingKeywords;

  /// Known financial sender IDs.
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

  /// Promotional / spam keywords — if ANY of these appear we
  /// reject the message *unless* it also contains very strong
  /// banking language (debited/credited + a/c).
  ///
  /// Core promo set (per requirements): offer, discount, sale,
  /// cashback, coupon. Additional high-confidence spam signals
  /// are also included.
  static const _promoKeywords = <String>[
    'offer',      // special offer, limited offer
    'sale',       // big sale, flash sale
    'discount',   // flat discount, extra discount
    'cashback',   // earn cashback, get cashback
    'coupon',     // coupon code, use coupon
    'reward',     // claim reward
    'voucher',    // gift voucher
    'congrat',    // congratulations
    'winner',     // you are a winner
    'lucky',      // lucky draw
    'win ',       // win prizes (space avoids matching "window")
    'claim',      // claim your reward
  ];

  /// Known non-financial SMS senders.
  static const _nonFinancialSenders = <String>[
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

  /// Expense keywords — money leaving the account.
  static const _expenseKeywords = <String>[
    'debited',
    'sent',
    'paid',
    'spent',
    'transferred',
    'withdrawn',
    'purchase',
    'debit',
  ];

  /// Income keywords — money entering the account.
  static const _incomeKeywords = <String>[
    'credited',
    'received',
    'deposited',
    'added to',
    'credit',
  ];

  /// Optional context words — their presence boosts confidence score
  /// but is NOT required for a message to be accepted.
  /// Corresponds to: A/c, account, ref no, txn id
  static const _bankContextKeywords = <String>[
    'a/c',
    'acct',
    'account',
    'avl bal',
    'available bal',
    'ref no',
    'txn id',
    'vpa',
    'upi',
    'imps',
    'neft',
    'rtgs',
    'txn',
  ];

  // ─────────────────────────────────────────────────────────
  //  PUBLIC API
  // ─────────────────────────────────────────────────────────

  /// Parse an SMS message and return a [ParsedTransaction] if it is
  /// a valid financial transaction, or `null` if it should be ignored.
  ///
  /// Parameters:
  /// - [body]: The full SMS text.
  /// - [sender]: The SMS sender ID (e.g. "BK-SBIINB").
  /// - [timestamp]: When the SMS was received.
  static ParsedTransaction? parse({
    required String body,
    required String sender,
    required DateTime timestamp,
  }) {
    final lower = body.toLowerCase();
    final senderLower = sender.toLowerCase();
    final normalizedSender = sender
      .replaceFirst(RegExp(r'^[A-Z]{2}-'), '')
      .toUpperCase();

    // ═══ GATE 1: Reject known non-financial senders ═══
    for (final name in _nonFinancialSenders) {
      if (senderLower.contains(name)) {
        _log('REJECT [sender] $sender is non-financial');
        return null;
      }
    }

    // ═══ GATE 1b: Unknown sender must contain at least one banking keyword ═══
    // Requirement: amount + ONE banking keyword is sufficient.
    // Bank context words (a/c, account, ref no, txn id) are optional —
    // they boost confidence but are not required.
    final isWhitelistedSender =
        _financialSenderWhitelist.contains(normalizedSender) ||
        _financialSenderWhitelist.any(normalizedSender.contains);
    final hasBankingKeyword =
        _bankingKeywords.any((kw) => lower.contains(kw));

    if (!isWhitelistedSender && !hasBankingKeyword) {
      _log('REJECT [sender-weak] unknown sender with no banking keyword');
      return null;
    }

    // hasBankContext is kept for confidence scoring only.
    final hasBankContext = _bankContextKeywords.any((kw) => lower.contains(kw));

    // ═══ GATE 2: Must contain a currency amount ═══
    final amount = _extractAmount(body);
    if (amount == null || amount <= 0) {
      _log('REJECT [no-amount] no valid amount found');
      return null;
    }

    // ═══ GATE 3: Must contain at least one transaction keyword ═══
    final hasTransactionKeyword =
        _transactionKeywords.any((kw) => lower.contains(kw));
    if (!hasTransactionKeyword) {
      _log('REJECT [no-txn-keyword] no transaction keyword found');
      return null;
    }

    // ═══ GATE 4: Reject promotional messages ═══
    if (_isPromotional(lower)) {
      _log('REJECT [promo] promotional content detected');
      return null;
    }

    // ═══ GATE 5: Reject OTP / verification ═══
    if (_isOtp(lower)) {
      _log('REJECT [otp] OTP or verification message');
      return null;
    }

    // ═══ GATE 6: Reject subscription / plan notifications ═══
    if (_isSubscriptionNotification(lower)) {
      _log('REJECT [subscription] subscription/plan notification');
      return null;
    }

    // ═══ GATE 7: Reject balance-only / mini-statement SMS ═══
    if (_isBalanceOnly(lower)) {
      _log('REJECT [balance] balance inquiry / mini statement');
      return null;
    }

    // ═══ GATE 8: Reject EMI / loan reminders ═══
    if (_isEmiReminder(lower)) {
      _log('REJECT [emi] EMI / loan reminder');
      return null;
    }

    // ── All gates passed — extract structured data ──

    final type = _classifyType(lower);
    final merchant = _extractMerchant(body) ?? _fallbackMerchant(sender);
    final upiRef = _extractUpiRef(body);
    final accountHint = _extractAccountHint(body);
    final upiId = _extractUpiId(body);
    final confidence = _calculateConfidence(
      lower: lower,
      hasAmount: true,
      hasTransactionKeyword: hasTransactionKeyword,
      hasBankContext: hasBankContext,
      hasUpiRef: upiRef != null,
      hasMerchant: merchant != _fallbackMerchant(sender),
    );

    // ═══ Infer category ═══
    final category = type == 'income'
        ? 'Income'
        : CategoryEngine.categorize(
            payeeName: merchant,
            upiId: upiId ?? '',
          );

    final result = ParsedTransaction(
      amount: amount,
      merchant: merchant,
      type: type,
      category: category,
      timestamp: timestamp,
      upiRef: upiRef,
      accountHint: accountHint,
      upiId: upiId,
      confidence: confidence,
    );

    _log('PARSED $result');
    return result;
  }

  /// Convenience method: parses a raw SMS map (as received from
  /// the platform channel) and returns a [ParsedTransaction].
  static ParsedTransaction? parseRaw(Map<String, String> data) {
    final sender = data['sender'] ?? '';
    final body = data['body'] ?? '';
    final timestampStr = data['timestamp'] ?? '0';
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      int.tryParse(timestampStr) ?? 0,
    );
    if (body.isEmpty) return null;
    return parse(body: body, sender: sender, timestamp: timestamp);
  }

  /// Batch-parse a list of SMS messages. Skips non-transactions
  /// automatically.
  static List<ParsedTransaction> parseBatch(
    List<Map<String, String>> messages,
  ) {
    final results = <ParsedTransaction>[];
    for (final msg in messages) {
      final result = parseRaw(msg);
      if (result != null) results.add(result);
    }
    return results;
  }

  // ─────────────────────────────────────────────────────────
  //  GATE HELPERS (private)
  // ─────────────────────────────────────────────────────────

  /// Returns `true` if the message is promotional / marketing.
  /// Exception: if the SMS has *strong* banking language
  /// (debited/credited + a/c), we allow it through because some
  /// banks include words like "offer" in the footer of real
  /// transaction alerts.
  static bool _isPromotional(String lower) {
    final hasPromo = _promoKeywords.any((kw) => lower.contains(kw));
    if (!hasPromo) return false;

    // Strong banking override: debited/credited + account reference
    final hasStrongBank = (lower.contains('debited') ||
            lower.contains('credited') ||
            lower.contains('transferred') ||
            lower.contains('withdrawn')) &&
        (lower.contains('a/c') ||
            lower.contains('acct') ||
            lower.contains('account'));
    if (hasStrongBank) {
      _log('PROMO override — strong banking language present');
      return false;
    }

    return true;
  }

  /// OTP / verification messages.
  static bool _isOtp(String lower) =>
      lower.contains('otp') ||
      lower.contains('one time password') ||
      lower.contains('verification code') ||
      lower.contains('one-time password');

  /// Subscription / plan / membership notifications that mention
  /// amounts but are NOT bank transaction alerts.
  static bool _isSubscriptionNotification(String lower) {
    final hasSubKeyword = lower.contains('subscription') ||
        lower.contains('subscribe') ||
        lower.contains('renew') ||
        lower.contains('membership') ||
        lower.contains('plan activated') ||
        lower.contains('plan expires');

    if (!hasSubKeyword) return false;

    // If it's clearly a bank debit/credit *for* the subscription,
    // allow it through (e.g. "₹499 debited from A/c for subscription").
    final hasBankTxn = (lower.contains('debited') ||
            lower.contains('credited')) &&
        (lower.contains('a/c') || lower.contains('upi'));
    if (hasBankTxn) return false;

    return true;
  }

  /// Balance inquiry or mini-statement SMS.
  static bool _isBalanceOnly(String lower) {
    final isBalance = lower.contains('available bal') ||
        lower.contains('avl bal') ||
        lower.contains('mini statement') ||
        lower.contains('balance is rs') ||
        lower.contains('balance:') ||
        lower.contains('bal rs');

    if (!isBalance) return false;

    // Allow if the SMS also describes a transaction.
    final hasTransaction = lower.contains('debited') ||
        lower.contains('credited') ||
        lower.contains('transferred') ||
        lower.contains('received') ||
        lower.contains('paid') ||
        lower.contains('sent') ||
        lower.contains('spent') ||
        lower.contains('withdrawn') ||
        lower.contains('purchase') ||
        lower.contains('txn');
    return !hasTransaction;
  }

  /// EMI / loan / credit-card bill reminders.
  static bool _isEmiReminder(String lower) =>
      lower.contains('emi due') ||
      lower.contains('loan repayment') ||
      lower.contains('pay your emi') ||
      (lower.contains('credit card') &&
          (lower.contains('bill') || lower.contains('due')));

  // ─────────────────────────────────────────────────────────
  //  TYPE CLASSIFICATION
  // ─────────────────────────────────────────────────────────

  /// Classify the transaction as `expense` or `income`.
  ///
  /// Priority order:
  ///   1. Strong expense keywords (debited, withdrawn)
  ///   2. Strong income keywords (credited, deposited)
  ///   3. Medium keywords with context
  ///   4. Default to `expense` (most bank SMS are debits)
  static String _classifyType(String lower) {
    // ── Credit card *payment* SMS should be expense ──
    // "Credit card payment of Rs.5000 debited from A/c"
    if (lower.contains('credit card') && lower.contains('debited')) {
      return 'expense';
    }

    // ── Strong income signals ──
    if (lower.contains('credited') ||
        lower.contains('deposited') ||
        lower.contains('added to')) {
      // "credited" can appear as "credited to your a/c" (income)
      // or "your a/c debited … credited to beneficiary" (expense!)
      // If BOTH debited and credited appear, check which comes first.
      if (lower.contains('debited')) {
        final debitIdx = lower.indexOf('debited');
        final creditIdx = lower.indexOf('credited');
        // The primary action is whichever appears first.
        return debitIdx < creditIdx ? 'expense' : 'income';
      }
      return 'income';
    }

    // ── Strong expense signals ──
    if (lower.contains('debited') ||
        lower.contains('withdrawn') ||
        lower.contains('transferred')) {
      return 'expense';
    }

    // ── Received = income ──
    if (lower.contains('received')) return 'income';

    // ── Check remaining keywords from dictionaries ──
    final hasExpense = _expenseKeywords.any((kw) => lower.contains(kw));
    final hasIncome = _incomeKeywords.any((kw) => lower.contains(kw));

    if (hasIncome && !hasExpense) return 'income';
    if (hasExpense) return 'expense';

    // Default: expense (most bank alerts are debit notifications)
    return 'expense';
  }

  // ─────────────────────────────────────────────────────────
  //  AMOUNT EXTRACTION
  // ─────────────────────────────────────────────────────────

  /// Extract the monetary amount from the SMS body.
  ///
  /// Handles:
  /// - ₹500, ₹1,500.00
  /// - Rs.500.00, Rs 1500
  /// - INR 500.00, INR 1,50,000
  /// - "debited by Rs.150.00"
  /// - "transaction of Rs 500"
  static double? _extractAmount(String text) {
    final patterns = [
      // ₹ symbol (most common in modern SMS)
      RegExp(r'[₹]\s?([\d,]+\.?\d{0,2})'),
      // Rs or Rs. followed by amount
      RegExp(r'Rs\.?\s?([\d,]+\.?\d{0,2})', caseSensitive: false),
      // INR followed by amount
      RegExp(r'INR\s?([\d,]+\.?\d{0,2})', caseSensitive: false),
      // "of Rs X" / "for Rs X" / "by Rs X"
      RegExp(
        r'(?:of|for|by|with)\s+(?:Rs\.?|INR|₹)\s?([\d,]+\.?\d{0,2})',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final raw = match.group(1)?.replaceAll(',', '');
        if (raw != null) {
          final value = double.tryParse(raw);
          if (value != null && value > 0) return value;
        }
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────
  //  MERCHANT / PAYEE EXTRACTION
  // ─────────────────────────────────────────────────────────

  /// Extract the merchant or payee/payer name from the SMS body.
  ///
  /// Tried patterns (in priority order):
  ///   1. Info: UPI/.../NAME/vpa — SBI / HDFC / ICICI style
  ///   2. "to NAME via UPI" / "from NAME via UPI"
  ///   3. "to NAME Ref" / "from NAME Ref"
  ///   4. VPA with parenthesized name: "person@ybl (John Doe)"
  ///   5. "at MERCHANT" pattern (for POS / card transactions)
  ///   6. Bare VPA as fallback: "to person@ybl"
  static String? _extractMerchant(String text) {
    final patterns = [
      // ── P1: UPI Info field ──
      // "Info: UPI/P2P/412345678901/JOHN DOE/person@ybl/SBI"
      _NamePattern(
        RegExp(
          r'(?:Info|info)\s*:?\s*UPI/[A-Za-z0-9]+/\d+/([A-Za-z][A-Za-z\s.]+?)/[a-zA-Z0-9._-]+@',
          caseSensitive: false,
        ),
        cleanup: true,
      ),

      // ── P2: "UPI/P2P/ref/NAME/vpa" or "UPI/P2M/ref/MERCHANT/vpa" ──
      _NamePattern(
        RegExp(
          r'UPI/[A-Za-z0-9]+/\d+/([A-Za-z][A-Za-z\s.]{1,30})/[a-zA-Z0-9._-]+@',
          caseSensitive: false,
        ),
        cleanup: true,
      ),

      // ── P3: "to/for NAME via UPI/IMPS/NEFT" ──
      _NamePattern(
        RegExp(
          r'(?:to|for)\s+([A-Za-z][A-Za-z\s.]+)\s+(?:via\s+)?(?:UPI|IMPS|NEFT)',
          caseSensitive: false,
        ),
        cleanup: true,
      ),

      // ── P3b: "From NAME via UPI" — sentence-start credit pattern ──
      // More specific than P4; matches "From ANKIT VERMA via UPI."
      _NamePattern(
        RegExp(
          r'[.!]\s*[Ff]rom\s+([A-Z][A-Za-z\s.]{2,30})\s+(?:via\s+)?(?:UPI|IMPS|NEFT)',
        ),
        cleanup: true,
      ),

      // ── P3c: "to NAME from A/c" — matches "sent to MERCHANT from A/c" ──
      _NamePattern(
        RegExp(
          r'(?:to|for)\s+([A-Za-z][A-Za-z\s.]{2,30})\s+from\s+(?:A/c|a/c|acct|account)',
          caseSensitive: false,
        ),
        cleanup: true,
      ),

      // ── P3d: "by NAME" in credit context ── 
      // "Rs 500 credited to your account by RAHUL"
      _NamePattern(
        RegExp(
          r'(?:credited|received)\s+.*?\s+by\s+([A-Za-z][A-Za-z\s.]{2,30})(?:\s*(?:\.|$|via|on|Ref|UPI|IMPS|NEFT))',
          caseSensitive: false,
        ),
        cleanup: true,
      ),

      // ── P4: "from/by NAME via UPI/IMPS/NEFT" (credits) ──
      // Require at least 4 chars of name to avoid matching "by UPI"
      _NamePattern(
        RegExp(
          r'(?:from|by)\s+([A-Za-z][A-Za-z\s.]{3,})\s+(?:via\s+)?(?:UPI|IMPS|NEFT)',
          caseSensitive: false,
        ),
        cleanup: true,
      ),

      // ── P5: "to/from NAME Ref" ──
      _NamePattern(
        RegExp(
          r'(?:to|from|by)\s+([A-Za-z][A-Za-z\s.]{2,30})\s*(?:Ref|ref|REF|UPI)',
          caseSensitive: false,
        ),
        cleanup: true,
      ),

      // ── P6: "at MERCHANT on" (POS / card spend) ──
      _NamePattern(
        RegExp(
          r"(?:at|@)\s+([A-Za-z][A-Za-z\s.&'\-]{2,30})\s+(?:on|for)",
          caseSensitive: false,
        ),
        cleanup: true,
      ),

      // ── P7: "VPA person@bank (NAME)" — parenthesized name ──
      _NamePattern(
        RegExp(
          r'(?:VPA\s+)?[a-zA-Z0-9._-]+@[a-zA-Z]+\s*\(([A-Za-z][A-Za-z\s.]+?)\)',
          caseSensitive: false,
        ),
        cleanup: true,
      ),

      // ── P8: Bare VPA as fallback — "to person@ybl" ──
      _NamePattern(
        RegExp(
          r'(?:to|from)\s+(?:VPA\s+)?([a-zA-Z0-9._-]+@[a-zA-Z]+)',
          caseSensitive: false,
        ),
        cleanup: false, // VPAs don't need name cleanup
      ),
    ];

    for (final p in patterns) {
      final match = p.pattern.firstMatch(text);
      if (match != null) {
        var name = match.group(1)?.trim();
        if (name == null || name.length < 2 || name.length > 40) continue;

        if (p.cleanup) {
          name = _cleanMerchantName(name);
        }
        if (name != null && name.length >= 2 && !_isBankingJunkName(name)) {
          return name;
        }
      }
    }
    return null;
  }

  /// Clean trailing prepositions, junk words, and extra whitespace
  /// from an extracted merchant name.
  static String? _cleanMerchantName(String raw) {
    var name = raw
        // Strip leading transfer-type prefixes
        .replaceAll(
          RegExp(
            r'^(?:IMPS|NEFT|RTGS|UPI)\s+(?:transfer\s+)?(?:to|from)\s+',
            caseSensitive: false,
          ),
          '',
        )
        // Strip trailing prepositions / junk
        .replaceAll(
          RegExp(
            r'\s+(?:via|on|in|at|is|was|has|the|for|and|or|ref|upi|imps|neft|Ref\s*(?:No|no)?)\.?\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    // Apply trailing cleanup again (in case first pass left a partial)
    name = name
        .replaceAll(
          RegExp(
            r'\s+(?:via|on|in|at|is|was|has|the|for|and|or|ref|upi|imps|neft)\.?\s*$',
            caseSensitive: false,
          ),
          '',
        )
        // Strip any trailing punctuation (period, comma, colon)
        .replaceAll(RegExp(r'[.,;:\s]+$'), '')
        .trim();

    // Reject if the "name" is just a number or too short.
    if (name.length < 2 || RegExp(r'^\d+$').hasMatch(name)) return null;
    return name;
  }

  /// Returns `true` if the extracted name is actually a banking
  /// keyword / junk that should not be used as a merchant name.
  static bool _isBankingJunkName(String name) {
    const junkNames = {
      'upi', 'imps', 'neft', 'rtgs', 'txn', 'ref', 'vpa',
      'bank', 'transfer', 'transaction', 'payment', 'debit',
      'credit', 'a/c', 'acct', 'account',
    };
    return junkNames.contains(name.toLowerCase().trim().replaceAll('.', ''));
  }

  /// Fallback merchant name derived from the SMS sender ID.
  /// "BK-SBIINB" → "SBI", "AD-HDFCBK" → "HDFC Bank", etc.
  static String _fallbackMerchant(String sender) {
    var clean = sender.replaceAll(RegExp(r'^[A-Z]{2}-'), '');
    const bankMap = {
      'SBIINB': 'SBI',
      'SBINOB': 'SBI',
      'HDFCBK': 'HDFC Bank',
      'ICICIB': 'ICICI Bank',
      'AXISBK': 'Axis Bank',
      'KOTAKB': 'Kotak Bank',
      'PNBSMS': 'PNB',
      'BOIIND': 'Bank of India',
      'CANBNK': 'Canara Bank',
      'UCOBNK': 'UCO Bank',
      'IABORB': 'IOB',
      'BOBSMS': 'Bank of Baroda',
      'INDBNK': 'Indian Bank',
      'FEDBKN': 'Federal Bank',
      'YESBNK': 'Yes Bank',
      'IDFCFB': 'IDFC First',
      'PAYTMB': 'Paytm',
    };
    return bankMap[clean] ?? clean;
  }

  // ─────────────────────────────────────────────────────────
  //  UPI REFERENCE EXTRACTION
  // ─────────────────────────────────────────────────────────

  /// Extract UPI reference / transaction number from SMS.
  ///
  /// Handles:
  /// - "UPI Ref No 123456789012"
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

    for (final p in patterns) {
      final match = p.firstMatch(text);
      if (match != null) return match.group(1);
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────
  //  ACCOUNT HINT EXTRACTION
  // ─────────────────────────────────────────────────────────

  /// Extract last 4 digits of the account number.
  ///
  /// Handles:
  /// - "A/c XX1234"
  /// - "a/c *1234"
  /// - "account ending 1234"
  static String? _extractAccountHint(String text) {
    final patterns = [
      RegExp(r'[Aa]/[Cc]\s*(?:[Nn]o)?\.?\s*[*xX]*(\d{4})\b'),
      RegExp(r'account\s+(?:ending|no\.?)\s*[*xX]*(\d{4})\b',
          caseSensitive: false),
    ];

    for (final p in patterns) {
      final match = p.firstMatch(text);
      if (match != null) return match.group(1);
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────
  //  UPI ID EXTRACTION
  // ─────────────────────────────────────────────────────────

  /// Extract the UPI VPA from the SMS body.
  static String? _extractUpiId(String text) {
    // Priority 1: Info: field
    final infoPattern = RegExp(
      r'(?:Info|info)\s*:?.*?([a-zA-Z0-9._-]+@(?:ybl|upi|apl|okhdfcbank|okicici|oksbi|okaxis|paytm|fbl|ibl|axl|sbi|waicici|wahdfcbank|barodampay|unionbankofindia|kotak|indus|federal|csbpay|dbs|rbl|allbank|aubank|equitas|idfcbank|hsbc|bandhan|jupiteraxis)[a-z]*)',
      caseSensitive: false,
    );
    final m1 = infoPattern.firstMatch(text);
    if (m1 != null) return m1.group(1);

    // Priority 2: UPI slash format
    final slashPattern = RegExp(
      r'UPI/[A-Za-z0-9]+/\d+/(?:[^/]+/)?([a-zA-Z0-9._-]+@[a-zA-Z]{3,})',
      caseSensitive: false,
    );
    final m2 = slashPattern.firstMatch(text);
    if (m2 != null) {
      final c = m2.group(1)!;
      if (!c.contains('.com') && !c.contains('.in')) return c;
    }

    // Priority 3: Known VPA handles
    final knownHandles = RegExp(
      r'\b([a-zA-Z0-9._-]+@(?:ybl|upi|apl|okhdfcbank|okicici|oksbi|okaxis|paytm|fbl|ibl|axl|sbi|waicici|wahdfcbank|barodampay|unionbankofindia|kotak|indus|federal|csbpay|dbs|rbl|allbank|aubank|equitas|idfcbank|hsbc|bandhan|jupiteraxis)[a-z]*)',
    );
    final m3 = knownHandles.firstMatch(text);
    if (m3 != null) return m3.group(1);

    // Priority 4: Broad VPA pattern (3+ char handle, not email)
    final broad = RegExp(r'\b([a-zA-Z0-9._-]+@[a-zA-Z]{3,})\b');
    final m4 = broad.firstMatch(text);
    if (m4 != null) {
      final c = m4.group(1)!;
      if (!c.contains('.com') &&
          !c.contains('.in') &&
          !c.contains('.org') &&
          !c.contains('.net')) {
        return c;
      }
    }

    return null;
  }

  // ─────────────────────────────────────────────────────────
  //  CONFIDENCE SCORING
  // ─────────────────────────────────────────────────────────

  /// Calculate a 0.0–1.0 confidence score based on available signals.
  static double _calculateConfidence({
    required String lower,
    required bool hasAmount,
    required bool hasTransactionKeyword,
    required bool hasBankContext,
    required bool hasUpiRef,
    required bool hasMerchant,
  }) {
    double score = 0.0;

    // Base: amount + transaction keyword (already required by gates)
    if (hasAmount) score += 0.25;
    if (hasTransactionKeyword) score += 0.20;

    // Banking context (a/c, UPI, etc.)
    if (hasBankContext) score += 0.20;

    // UPI reference number
    if (hasUpiRef) score += 0.15;

    // Merchant name extracted
    if (hasMerchant) score += 0.10;

    // Strong transaction verbs
    if (lower.contains('debited') || lower.contains('credited')) {
      score += 0.10;
    }

    return score.clamp(0.0, 1.0);
  }

  // ─────────────────────────────────────────────────────────
  //  LOGGING
  // ─────────────────────────────────────────────────────────

  static void _log(String message) {
    debugPrint('SmsTransactionParser: $message');
  }
}

/// Internal helper to pair a regex with a cleanup flag.
class _NamePattern {
  final RegExp pattern;
  final bool cleanup;
  const _NamePattern(this.pattern, {this.cleanup = true});
}
