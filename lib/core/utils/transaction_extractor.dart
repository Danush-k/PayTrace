import 'package:flutter/foundation.dart';

import 'regex_pattern_library.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  TRANSACTION EXTRACTOR UTILITY
//
//  A high-performance extraction engine that uses RegexPatternLibrary
//  to extract structured financial data from Indian bank SMS messages.
//
//  Features:
//   • Merchant name extraction using 100+ patterns
//   • Merchant name normalization (SWIGGY → Swiggy)
//   • Transaction mode detection (UPI/IMPS/Card/ATM/etc.)
//   • Amount, reference, and account hint extraction
//   • Performance-optimized for batch processing (1000+ SMS)
//   • Comprehensive junk name filtering
// ═══════════════════════════════════════════════════════════════════════════

/// Result of a full transaction extraction pass.
class ExtractionResult {
  /// The extracted amount, if any.
  final double? amount;

  /// The extracted merchant/receiver name, cleaned and normalized.
  final String? merchant;

  /// Transaction mode: UPI, IMPS, NEFT, RTGS, Card, ATM, Wallet.
  final String? transactionMode;

  /// UPI reference or other reference number.
  final String? referenceNumber;

  /// Last 4 digits of account or card.
  final String? accountHint;

  /// Bank name derived from sender ID.
  final String? bankName;

  /// The UPI VPA, if found in the message.
  final String? upiId;

  /// Transaction type: 'debit' or 'credit'.
  final String? transactionType;

  const ExtractionResult({
    this.amount,
    this.merchant,
    this.transactionMode,
    this.referenceNumber,
    this.accountHint,
    this.bankName,
    this.upiId,
    this.transactionType,
  });

  @override
  String toString() =>
      'ExtractionResult(amount=$amount, merchant=$merchant, '
      'mode=$transactionMode, bank=$bankName, type=$transactionType, '
      'ref=$referenceNumber, acct=$accountHint, upi=$upiId)';
}

/// The main extraction engine.
///
/// Usage:
/// ```dart
/// final result = TransactionExtractor.extract(
///   body: smsBody,
///   sender: smsSender,
/// );
/// if (result.merchant != null) {
///   print('Merchant: ${result.merchant}');
/// }
/// ```
class TransactionExtractor {
  TransactionExtractor._();

  // ─────────────────────────────────────────────────────────
  //  PUBLIC API
  // ─────────────────────────────────────────────────────────

  /// Extract all available transaction fields from an SMS body.
  ///
  /// [body] — The full SMS text.
  /// [sender] — The SMS sender ID (e.g. "BK-SBIINB").
  static ExtractionResult extract({
    required String body,
    required String sender,
  }) {
    return ExtractionResult(
      amount: extractAmount(body),
      merchant: extractMerchant(body, sender: sender),
      transactionMode: RegexPatternLibrary.detectTransactionMode(body),
      referenceNumber: extractReference(body),
      accountHint: extractAccountHint(body),
      bankName: RegexPatternLibrary.detectBankFromSender(sender),
      upiId: extractUpiId(body),
      transactionType: detectTransactionType(body),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  MERCHANT NAME EXTRACTION
  // ─────────────────────────────────────────────────────────

  /// Extract the merchant/receiver name from SMS body using the
  /// full 100+ pattern library.
  ///
  /// Returns a cleaned, normalized merchant name, or null if
  /// no merchant could be extracted.
  ///
  /// [sender] is used only as a fallback source; it is NOT used
  /// to generate the merchant name (that's the whole point of
  /// this implementation — avoiding sender ID as the name).
  static String? extractMerchant(String body, {String? sender}) {
    for (final pattern in RegexPatternLibrary.merchantPatterns) {
      final match = pattern.regex.firstMatch(body);
      if (match == null) continue;

      var name = match.group(pattern.captureGroup)?.trim();
      if (name == null || name.length < 2 || name.length > 45) continue;

      // Apply cleanup if the pattern requests it.
      if (pattern.cleanupResult) {
        name = cleanMerchantName(name);
      }

      if (name == null || name.length < 2) continue;

      // Reject if the "name" is a banking keyword or junk.
      if (_isBankingJunkName(name)) continue;

      // Reject if the name is just a bank name (sender ID leak).
      if (_isBankName(name)) continue;

      // Normalize the merchant name (e.g. SWIGGY → Swiggy).
      return normalizeMerchantName(name);
    }

    return null; // No merchant found — caller should use fallback.
  }

  // ─────────────────────────────────────────────────────────
  //  MERCHANT NAME CLEANING & NORMALIZATION
  // ─────────────────────────────────────────────────────────

  /// Clean trailing/leading junk from an extracted merchant name.
  ///
  /// Removes:
  ///  • Leading transfer-type prefixes (IMPS transfer to, UPI to)
  ///  • Trailing prepositions (via, on, in, at, is, was, for)
  ///  • Trailing banking keywords (UPI, IMPS, NEFT, Ref)
  ///  • Multiple spaces
  ///  • Trailing punctuation
  static String? cleanMerchantName(String raw) {
    var name = raw
        // Strip leading transfer-type prefixes
        .replaceAll(
          RegExp(
            r'^(?:IMPS|NEFT|RTGS|UPI)\s+(?:transfer\s+)?(?:to|from)\s+',
            caseSensitive: false,
          ),
          '',
        )
        // Strip leading prepositions that might be accidentally captured
        .replaceAll(
          RegExp(
            r'^(?:for|at|to|from|by|towards|of)\s+',
            caseSensitive: false,
          ),
          '',
        )
        // Strip leading "Mr/Mrs/Ms/Shri/Smt"
        .replaceAll(
          RegExp(
            r'^(?:Mr\.?|Mrs\.?|Ms\.?|Shri\.?|Smt\.?|Dr\.?)\s+',
            caseSensitive: false,
          ),
          '',
        )
        // Strip trailing prepositions / junk words
        .replaceAll(
          RegExp(
            r'\s+(?:via|on|in|at|is|was|has|the|for|and|or|ref|upi|imps|neft|rtgs|Ref\s*(?:No|no)?|with|using|through|thru)\.?\s*$',
            caseSensitive: false,
          ),
          '',
        )
        // Strip trailing punctuation
        .replaceAll(RegExp(r'[.,;:\-!\s]+$'), '')
        // Collapse multiple spaces
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    // Apply trailing cleanup again (first pass may have left a partial).
    name = name
        .replaceAll(
          RegExp(
            r'\s+(?:via|on|in|at|is|was|has|the|for|and|or|ref|upi|imps|neft|rtgs)\.?\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'[.,;:\-!\s]+$'), '')
        .trim();

    // Reject if the "name" is just a number or too short.
    if (name.length < 2 || RegExp(r'^\d+$').hasMatch(name)) return null;

    return name;
  }

  /// Normalize a merchant name for display consistency.
  ///
  /// Rules:
  ///  1. Known merchants get their canonical casing (SWIGGY → Swiggy).
  ///  2. All-uppercase names get Title Case (MANIKANDAN → Manikandan).
  ///  3. Mixed-case names are left unchanged.
  static String normalizeMerchantName(String name) {
    // Check known merchant database first.
    final canonical = _knownMerchants[name.toLowerCase().trim()];
    if (canonical != null) return canonical;

    // If the name is all-uppercase, convert to Title Case.
    if (name == name.toUpperCase() && name.length > 1) {
      return _toTitleCase(name);
    }

    // If the name is all-lowercase, convert to Title Case.
    if (name == name.toLowerCase() && name.length > 1) {
      return _toTitleCase(name);
    }

    return name;
  }

  /// Convert a string to Title Case.
  /// "MANIKANDAN" → "Manikandan"
  /// "john doe" → "John Doe"
  static String _toTitleCase(String input) {
    return input
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          if (word.length == 1) return word.toUpperCase();
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  // ─────────────────────────────────────────────────────────
  //  AMOUNT EXTRACTION
  // ─────────────────────────────────────────────────────────

  /// Extract the monetary amount from SMS body.
  static double? extractAmount(String text) {
    for (final pattern in RegexPatternLibrary.amountPatterns) {
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
  //  REFERENCE NUMBER EXTRACTION
  // ─────────────────────────────────────────────────────────

  /// Extract reference number from SMS body.
  static String? extractReference(String text) {
    for (final pattern in RegexPatternLibrary.referencePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) return match.group(1);
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────
  //  ACCOUNT HINT EXTRACTION
  // ─────────────────────────────────────────────────────────

  /// Extract last 4 digits of account/card number.
  static String? extractAccountHint(String text) {
    for (final pattern in RegexPatternLibrary.accountHintPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) return match.group(1);
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────
  //  UPI ID EXTRACTION
  // ─────────────────────────────────────────────────────────

  /// Extract UPI VPA from SMS body.
  static String? extractUpiId(String text) {
    // Priority 1: Info field
    final infoPattern = RegExp(
      r'(?:Info|info)\s*:?.*?([a-zA-Z0-9._-]+@(?:ybl|upi|apl|okhdfcbank|okicici|oksbi|okaxis|paytm|fbl|ibl|axl|sbi|waicici|wahdfcbank|barodampay|unionbankofindia|kotak|indus|federal|csbpay|dbs|rbl|allbank|aubank|equitas|idfcbank|hsbc|bandhan|jupiteraxis)[a-z]*)',
      caseSensitive: false,
    );
    final infoMatch = infoPattern.firstMatch(text);
    if (infoMatch != null) return infoMatch.group(1);

    // Priority 2: UPI slash format
    final slashPattern = RegExp(
      r'UPI/[A-Za-z0-9]+/\d+/(?:[^/]+/)?([a-zA-Z0-9._-]+@[a-zA-Z]{3,})',
      caseSensitive: false,
    );
    final slashMatch = slashPattern.firstMatch(text);
    if (slashMatch != null) {
      final c = slashMatch.group(1)!;
      if (!c.contains('.com') && !c.contains('.in')) return c;
    }

    // Priority 3: Known VPA handles
    final knownHandles = RegExp(
      r'\b([a-zA-Z0-9._-]+@(?:ybl|upi|apl|okhdfcbank|okicici|oksbi|okaxis|paytm|fbl|ibl|axl|sbi|waicici|wahdfcbank|barodampay|unionbankofindia|kotak|indus|federal|csbpay|dbs|rbl|allbank|aubank|equitas|idfcbank|hsbc|bandhan|jupiteraxis)[a-z]*)',
    );
    final knownMatch = knownHandles.firstMatch(text);
    if (knownMatch != null) return knownMatch.group(1);

    // Priority 4: Broad VPA pattern
    final broad = RegExp(r'\b([a-zA-Z0-9._-]+@[a-zA-Z]{3,})\b');
    final broadMatch = broad.firstMatch(text);
    if (broadMatch != null) {
      final c = broadMatch.group(1)!;
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
  //  TRANSACTION TYPE DETECTION
  // ─────────────────────────────────────────────────────────

  /// Detect whether this is a debit or credit transaction.
  /// Returns 'debit' or 'credit'.
  static String detectTransactionType(String text) {
    final lower = text.toLowerCase();

    // Credit card payment that says "debited" → debit
    if (lower.contains('credit card') && lower.contains('debited')) {
      return 'debit';
    }

    // Strong credit signals
    if (lower.contains('credited') ||
        lower.contains('deposited') ||
        lower.contains('added to')) {
      if (lower.contains('debited')) {
        final debitIdx = lower.indexOf('debited');
        final creditIdx = lower.indexOf('credited');
        return debitIdx < creditIdx ? 'debit' : 'credit';
      }
      return 'credit';
    }

    // Strong debit signals
    if (lower.contains('debited') ||
        lower.contains('withdrawn') ||
        lower.contains('transferred')) {
      return 'debit';
    }

    if (lower.contains('received')) return 'credit';

    // Check keyword dictionaries
    const debitWords = [
      'debited', 'sent', 'paid', 'spent', 'transferred',
      'withdrawn', 'purchase', 'debit',
    ];
    const creditWords = [
      'credited', 'received', 'deposited', 'added to', 'credit',
    ];

    final hasDebit = debitWords.any((kw) => lower.contains(kw));
    final hasCredit = creditWords.any((kw) => lower.contains(kw));

    if (hasCredit && !hasDebit) return 'credit';
    if (hasDebit) return 'debit';

    return 'debit'; // Default: most bank alerts are debits
  }

  // ─────────────────────────────────────────────────────────
  //  JUNK DETECTION HELPERS
  // ─────────────────────────────────────────────────────────

  /// Returns true if the name is a banking keyword that shouldn't
  /// be used as a merchant name.
  static bool _isBankingJunkName(String name) {
    final lower = name.toLowerCase().trim().replaceAll('.', '');
    return _junkNames.contains(lower);
  }

  static const _junkNames = <String>{
    'upi', 'imps', 'neft', 'rtgs', 'txn', 'ref', 'vpa',
    'bank', 'transfer', 'transaction', 'payment', 'debit',
    'credit', 'a/c', 'acct', 'account', 'your', 'self',
    'balance', 'avl bal', 'avl', 'bal', 'available',
    'dear customer', 'customer', 'dear', 'sir', 'madam',
    'atm', 'pos', 'card', 'rupees', 'inr', 'rs',
    'success', 'successful', 'completed', 'done',
    'info', 'details', 'alert', 'notification',
    'not you', 'if not',
  };

  /// Returns true if the name is a known bank name.
  static bool _isBankName(String name) {
    return _bankNames.contains(name) ||
        _bankNames.contains(name.toUpperCase()) ||
        _bankNames.any(
            (bn) => bn.toLowerCase() == name.toLowerCase());
  }

  static const _bankNames = <String>{
    'SBI', 'HDFC Bank', 'ICICI Bank', 'Axis Bank',
    'Kotak Bank', 'Kotak Mahindra Bank', 'PNB', 'IOB',
    'Bank of India', 'Canara Bank', 'UCO Bank',
    'Bank of Baroda', 'Indian Bank', 'Federal Bank',
    'Yes Bank', 'IDFC First', 'IDFC First Bank',
    'Paytm', 'Paytm Payments Bank',
    'Union Bank', 'Central Bank', 'Bank of Maharashtra',
    'RBL Bank', 'Bandhan Bank', 'IndusInd Bank',
  };

  // ─────────────────────────────────────────────────────────
  //  KNOWN MERCHANT NORMALIZATION DATABASE
  // ─────────────────────────────────────────────────────────

  /// Map of lowercase merchant names → canonical display names.
  static const _knownMerchants = <String, String>{
    // Food & Delivery
    'swiggy': 'Swiggy',
    'zomato': 'Zomato',
    'dunzo': 'Dunzo',
    'blinkit': 'Blinkit',
    'bigbasket': 'BigBasket',
    'grofers': 'Grofers',
    'zepto': 'Zepto',
    'dominos': "Domino's",
    "domino's": "Domino's",
    'mcdonalds': "McDonald's",
    "mcdonald's": "McDonald's",
    'kfc': 'KFC',
    'subway': 'Subway',
    'starbucks': 'Starbucks',
    'pizza hut': 'Pizza Hut',
    'burger king': 'Burger King',

    // E-commerce
    'amazon': 'Amazon',
    'amazon pay': 'Amazon Pay',
    'flipkart': 'Flipkart',
    'myntra': 'Myntra',
    'ajio': 'AJIO',
    'nykaa': 'Nykaa',
    'meesho': 'Meesho',
    'croma': 'Croma',
    'tata cliq': 'Tata CLiQ',
    'snapdeal': 'Snapdeal',
    'pepperfry': 'Pepperfry',
    'ikea': 'IKEA',
    'decathlon': 'Decathlon',

    // Transport
    'uber': 'Uber',
    'ola': 'Ola',
    'rapido': 'Rapido',
    'uber eats': 'Uber Eats',

    // Telecom
    'airtel': 'Airtel',
    'jio': 'Jio',
    'bsnl': 'BSNL',
    'vodafone': 'Vodafone',
    'vi': 'Vi',

    // Entertainment
    'netflix': 'Netflix',
    'spotify': 'Spotify',
    'hotstar': 'Hotstar',
    'disney+ hotstar': 'Disney+ Hotstar',
    'prime video': 'Prime Video',
    'youtube': 'YouTube',
    'youtube premium': 'YouTube Premium',
    'bookmyshow': 'BookMyShow',

    // Travel
    'irctc': 'IRCTC',
    'makemytrip': 'MakeMyTrip',
    'goibibo': 'Goibibo',
    'cleartrip': 'Cleartrip',
    'yatra': 'Yatra',
    'redbus': 'RedBus',

    // Fuel
    'indian oil': 'Indian Oil',
    'hp petrol': 'HP Petrol',
    'bharat petroleum': 'Bharat Petroleum',
    'shell': 'Shell',
    'reliance petrol': 'Reliance Petrol',

    // Utilities
    'bescom': 'BESCOM',
    'bwssb': 'BWSSB',
    'tata power': 'Tata Power',
    'adani electricity': 'Adani Electricity',

    // Healthcare
    'apollo': 'Apollo',
    'practo': 'Practo',
    'pharmeasy': 'PharmEasy',
    'netmeds': 'Netmeds',
    '1mg': '1mg',
    'medplus': 'MedPlus',

    // Education
    'unacademy': 'Unacademy',
    'byjus': "BYJU'S",
    "byju's": "BYJU'S",
    'vedantu': 'Vedantu',
    'coursera': 'Coursera',
    'udemy': 'Udemy',

    // Payments
    'google pay': 'Google Pay',
    'gpay': 'Google Pay',
    'phonepe': 'PhonePe',
    'paytm': 'Paytm',
    'bhim': 'BHIM',
    'whatsapp pay': 'WhatsApp Pay',

    // Retail
    'dmart': 'DMart',
    'big bazaar': 'Big Bazaar',
    'reliance retail': 'Reliance Retail',
    'more supermarket': 'More Supermarket',
    'spencer': 'Spencer',
    'lifestyle': 'Lifestyle',

    // Insurance
    'lic': 'LIC',
    'star health': 'Star Health',
    'max bupa': 'Max Bupa',
    'hdfc ergo': 'HDFC Ergo',

    // Government
    'electricity board': 'Electricity Board',
    'water board': 'Water Board',
    'municipal': 'Municipal Corporation',
  };

  // ─────────────────────────────────────────────────────────
  //  BATCH PROCESSING
  // ─────────────────────────────────────────────────────────

  /// Batch-extract from a list of SMS messages.
  ///
  /// Optimized for processing thousands of messages:
  ///  • Patterns are pre-compiled (done once at class load)
  ///  • Short-circuits on first match per extraction
  ///  • Runs synchronously (no async overhead)
  static List<ExtractionResult> extractBatch(
    List<Map<String, String>> messages,
  ) {
    final results = <ExtractionResult>[];
    for (final msg in messages) {
      final body = msg['body'] ?? '';
      final sender = msg['sender'] ?? '';
      if (body.isEmpty) continue;
      results.add(extract(body: body, sender: sender));
    }
    debugPrint(
      'TransactionExtractor: Batch extracted ${results.length} results '
      'from ${messages.length} messages',
    );
    return results;
  }
}
