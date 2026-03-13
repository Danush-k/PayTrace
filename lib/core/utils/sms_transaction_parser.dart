import 'package:flutter/foundation.dart';

import 'category_engine.dart';
import 'regex_pattern_library.dart';
import 'transaction_extractor.dart';

// ═════════════════════════════════════════════════════════════════════
//  SMS TRANSACTION PARSER  (v2 — powered by RegexPatternLibrary)
//
//  A robust, production-grade parser that extracts structured financial
//  transaction data from Indian bank SMS messages.
//
//  v2 changes:
//   • Merchant extraction now uses 100+ regex patterns via
//     [RegexPatternLibrary] and [TransactionExtractor].
//   • Transaction mode detection (UPI/IMPS/NEFT/RTGS/Card/ATM/Wallet).
//   • Merchant name normalization (SWIGGY → Swiggy).
//   • Bank name detection from sender ID.
//   • All original gates and filtering logic preserved.
//   • Backward-compatible [ParsedTransaction] model retained.
//
//  Design principles:
//    1. Whitelist approach — only accept messages with strong banking
//       signals (account refs, UPI keywords, bank language).
//    2. Blacklist layer — reject promotional / OTT / subscription SMS
//       even if they slip past the whitelist (defense in depth).
//    3. Multi-regex extraction — try 100+ patterns for merchant name,
//       returning the highest-priority match.
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

  /// Transaction mode: UPI, IMPS, NEFT, RTGS, Card, ATM, Wallet.
  final String? transactionMode;

  /// Bank name derived from sender ID.
  final String? bankName;

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
    this.transactionMode,
    this.bankName,
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
        if (transactionMode != null) 'transactionMode': transactionMode,
        if (bankName != null) 'bankName': bankName,
        'confidence': confidence,
      };

  @override
  String toString() =>
      'ParsedTransaction($type ₹$amount → $merchant [$category] '
      'mode=$transactionMode bank=$bankName '
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
  static const _bankingKeywords = <String>[
    'debited', 'credited', 'sent', 'received',
    'transferred', 'transfer', 'deposited', 'withdrawn', 
    'spent', 'paid', 'purchase', 'used at', 'txn at',
    'payment', 'payment successful', 'txn of', 'sent to', 'paid to',
    'upi', 'imps', 'neft', 'rtgs', 'vpa',
    'txn', 'ref no', 'ref:', 'trans id',
  ];

  static const _transactionKeywords = _bankingKeywords;

  /// Known financial sender IDs.
  static const _financialSenderWhitelist = <String>{
    'AXISBK', 'HDFCBK', 'ICICIB', 'SBIBNK', 'SBIINB', 'SBINOB',
    'PAYTMB', 'PHONEPE', 'GPAY', 'KOTAKB', 'PNBSMS', 'CANBNK',
    'BOBSMS', 'INDBNK', 'IDFCFB', 'IOBCHN', 'IABORB', 'IOBBNK',
    'YESBNK', 'FEDBKN', 'UCOBNK', 'BOIIND', 'UBINBK', 'UNIONB',
    'CENTBK', 'MAHABK', 'RBLBNK', 'BANDHN', 'INDUSB', 'DCBBKN',
    'KRNBNK', 'TMBBKS', 'KVBBNK', 'CSBBNK', 'SOUBNK', 'DHANLX',
    'JKBANK', 'HDFCBN', 'ICICBK', 'AXSBNK', 'KOTKBK', 'PNBBNK',
    'CNRBNK', 'BARBOD', 'INDBKS', 'FEDBNK', 'YESBKN', 'IDFCBK',
    'BOISTR', 'SBISMS',
  };

  /// Promotional / spam keywords.
  static const _promoKeywords = <String>[
    'offer', 'sale', 'discount', 'cashback', 'coupon',
    'reward', 'voucher', 'congrat', 'winner', 'lucky',
    'win ', 'claim',
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

  /// Optional context words — boost confidence but not required.
  static const _bankContextKeywords = <String>[
    'a/c', 'acct', 'account', 'avl bal', 'available bal',
    'ref no', 'txn id', 'vpa', 'upi', 'imps', 'neft', 'rtgs', 'txn',
  ];

  // ─────────────────────────────────────────────────────────
  //  PUBLIC API
  // ─────────────────────────────────────────────────────────

  /// Parse an SMS message and return a [ParsedTransaction] if it is
  /// a valid financial transaction, or `null` if it should be ignored.
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

    // ═══ GATE 1b: Unknown sender must contain banking keyword ═══
    final isWhitelistedSender =
        _financialSenderWhitelist.contains(normalizedSender) ||
        _financialSenderWhitelist.any(normalizedSender.contains);
    final hasBankingKeyword =
        _bankingKeywords.any((kw) => lower.contains(kw));

    if (!isWhitelistedSender && !hasBankingKeyword) {
      _log('REJECT [sender-weak] unknown sender with no banking keyword');
      return null;
    }

    final hasBankContext =
        _bankContextKeywords.any((kw) => lower.contains(kw));

    // ═══ GATE 2: Must contain a currency amount ═══
    final amount = TransactionExtractor.extractAmount(body);
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

    // ═══ NEW: Use TransactionExtractor for merchant extraction ═══
    // This is the core fix — uses 100+ patterns instead of ~8.
    final extractedMerchant = TransactionExtractor.extractMerchant(
      body,
      sender: sender,
    );
    final merchant = extractedMerchant ?? _fallbackMerchant(sender);

    final upiRef = TransactionExtractor.extractReference(body);
    final accountHint = TransactionExtractor.extractAccountHint(body);
    final upiId = TransactionExtractor.extractUpiId(body);
    final transactionMode = RegexPatternLibrary.detectTransactionMode(body);
    final bankName = RegexPatternLibrary.detectBankFromSender(sender);

    final confidence = _calculateConfidence(
      lower: lower,
      hasAmount: true,
      hasTransactionKeyword: hasTransactionKeyword,
      hasBankContext: hasBankContext,
      hasUpiRef: upiRef != null,
      hasMerchant: extractedMerchant != null,
      hasTransactionMode: transactionMode != null,
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
      transactionMode: transactionMode,
      bankName: bankName,
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

  static bool _isPromotional(String lower) {
    final hasPromo = _promoKeywords.any((kw) => lower.contains(kw));
    if (!hasPromo) return false;

    // Strong banking override
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

  static bool _isOtp(String lower) =>
      lower.contains('otp') ||
      lower.contains('one time password') ||
      lower.contains('verification code') ||
      lower.contains('one-time password');

  static bool _isSubscriptionNotification(String lower) {
    final hasSubKeyword = lower.contains('subscription') ||
        lower.contains('subscribe') ||
        lower.contains('renew') ||
        lower.contains('membership') ||
        lower.contains('plan activated') ||
        lower.contains('plan expires');

    if (!hasSubKeyword) return false;

    final hasBankTxn = (lower.contains('debited') ||
            lower.contains('credited')) &&
        (lower.contains('a/c') || lower.contains('upi'));
    if (hasBankTxn) return false;

    return true;
  }

  static bool _isBalanceOnly(String lower) {
    final isBalance = lower.contains('available bal') ||
        lower.contains('avl bal') ||
        lower.contains('mini statement') ||
        lower.contains('balance is rs') ||
        lower.contains('balance:') ||
        lower.contains('bal rs');

    if (!isBalance) return false;

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

  static bool _isEmiReminder(String lower) =>
      lower.contains('emi due') ||
      lower.contains('loan repayment') ||
      lower.contains('pay your emi') ||
      (lower.contains('credit card') &&
          (lower.contains('bill') || lower.contains('due')));

  // ─────────────────────────────────────────────────────────
  //  TYPE CLASSIFICATION
  // ─────────────────────────────────────────────────────────

  static String _classifyType(String lower) {
    // Credit card payment SMS should be expense
    if (lower.contains('credit card') && lower.contains('debited')) {
      return 'expense';
    }

    // Strong income signals
    if (lower.contains('credited') ||
        lower.contains('deposited') ||
        lower.contains('added to')) {
      if (lower.contains('debited')) {
        final debitIdx = lower.indexOf('debited');
        final creditIdx = lower.indexOf('credited');
        return debitIdx < creditIdx ? 'expense' : 'income';
      }
      return 'income';
    }

    // Strong expense signals
    if (lower.contains('debited') ||
        lower.contains('withdrawn') ||
        lower.contains('transferred')) {
      return 'expense';
    }

    if (lower.contains('received')) return 'income';

    // Check keyword dictionaries
    const expenseKeywords = [
      'debited', 'sent', 'paid', 'spent', 'transferred',
      'withdrawn', 'purchase', 'debit',
    ];
    const incomeKeywords = [
      'credited', 'received', 'deposited', 'added to', 'credit',
    ];

    final hasExpense = expenseKeywords.any((kw) => lower.contains(kw));
    final hasIncome = incomeKeywords.any((kw) => lower.contains(kw));

    if (hasIncome && !hasExpense) return 'income';
    if (hasExpense) return 'expense';

    return 'expense';
  }

  // ─────────────────────────────────────────────────────────
  //  FALLBACK MERCHANT NAME
  // ─────────────────────────────────────────────────────────

  /// Fallback merchant name from sender ID.
  static String _fallbackMerchant(String sender) {
    final bankName = RegexPatternLibrary.detectBankFromSender(sender);
    if (bankName != null) return bankName;

    // Clean and return as-is
    return sender.replaceAll(RegExp(r'^[A-Z]{2}-'), '');
  }

  // ─────────────────────────────────────────────────────────
  //  CONFIDENCE SCORING
  // ─────────────────────────────────────────────────────────

  static double _calculateConfidence({
    required String lower,
    required bool hasAmount,
    required bool hasTransactionKeyword,
    required bool hasBankContext,
    required bool hasUpiRef,
    required bool hasMerchant,
    bool hasTransactionMode = false,
  }) {
    double score = 0.0;

    if (hasAmount) score += 0.20;
    if (hasTransactionKeyword) score += 0.15;
    if (hasBankContext) score += 0.15;
    if (hasUpiRef) score += 0.15;
    if (hasMerchant) score += 0.15;
    if (hasTransactionMode) score += 0.10;

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
