// ═══════════════════════════════════════════════════════════════════════════
//  REGEX PATTERN LIBRARY — 100+ Indian Bank SMS Transaction Patterns
//
//  A comprehensive, production-grade pattern library for extracting
//  financial transaction data from Indian bank SMS messages.
//
//  Covers:
//   • All major Indian banks (SBI, HDFC, ICICI, Axis, IOB, PNB, etc.)
//   • All transaction modes (UPI, IMPS, NEFT, RTGS, Card, ATM, Wallet)
//   • All transaction types (debit, credit, purchase, withdrawal)
//   • Merchant/receiver name extraction
//   • Amount extraction (₹, Rs, INR)
//   • Reference number extraction
//   • Account number extraction
//   • Transaction mode detection
//
//  Architecture:
//   • Patterns are grouped by extraction purpose
//   • Each pattern has a priority (lower = higher priority)
//   • Patterns are pre-compiled for performance
//   • Merchant name cleaning is built into extraction
// ═══════════════════════════════════════════════════════════════════════════

/// Represents a single regex pattern with metadata for extraction.
class BankSmsPattern {
  /// Pre-compiled regex pattern.
  final RegExp regex;

  /// The capture group index that holds the extracted value.
  final int captureGroup;

  /// Priority (lower = tried first). Ties are broken by insertion order.
  final int priority;

  /// Human-readable description for debugging.
  final String description;

  /// Whether to apply merchant name cleanup after extraction.
  final bool cleanupResult;

  const BankSmsPattern({
    required this.regex,
    this.captureGroup = 1,
    this.priority = 50,
    required this.description,
    this.cleanupResult = true,
  });
}

/// The central pattern library for Indian bank SMS parsing.
///
/// All patterns are pre-compiled and sorted by priority at class load time,
/// so runtime matching is just a linear scan over compiled regexes.
class RegexPatternLibrary {
  RegexPatternLibrary._();

  // ═══════════════════════════════════════════════════════════════
  //  MERCHANT / RECEIVER NAME EXTRACTION PATTERNS (100+)
  // ═══════════════════════════════════════════════════════════════

  /// Master list of merchant/receiver extraction patterns.
  ///
  /// Organized by priority tier:
  ///   Tier 1 (P1-P10):   Structured formats (Info:, UPI/ slash notation)
  ///   Tier 2 (P11-P30):  Explicit keyword patterns ("to NAME via UPI")
  ///   Tier 3 (P31-P50):  Medium-context patterns ("at MERCHANT", "for")
  ///   Tier 4 (P51-P80):  Bank-specific patterns (SBI, HDFC, ICICI, etc.)
  ///   Tier 5 (P81-P100): Fallback patterns (VPA, generic)
  ///   Tier 6 (P101+):    Ultra-fallback / edge cases
  static final List<BankSmsPattern> merchantPatterns = _buildMerchantPatterns();

  static List<BankSmsPattern> _buildMerchantPatterns() {
    final patterns = <BankSmsPattern>[
      // ─────────────────────────────────────────────────────────
      //  TIER 1: STRUCTURED UPI FORMATS (highest confidence)
      // ─────────────────────────────────────────────────────────

      // P1: Info: UPI/TYPE/REF/NAME/VPA/BANK — SBI/HDFC/ICICI standard
      BankSmsPattern(
        regex: RegExp(
          r'(?:Info|info)\s*:?\s*UPI/[A-Za-z0-9]+/\d+/([A-Za-z][A-Za-z\s.]{1,35})/[a-zA-Z0-9._-]+@',
          caseSensitive: false,
        ),
        priority: 1,
        description: 'Info: UPI/.../NAME/vpa@bank',
      ),

      // P2: UPI/P2P/REF/NAME/VPA or UPI/P2M/REF/MERCHANT/VPA
      BankSmsPattern(
        regex: RegExp(
          r'UPI/[A-Za-z0-9]+/\d+/([A-Za-z][A-Za-z\s.]{1,35})/[a-zA-Z0-9._-]+@',
          caseSensitive: false,
        ),
        priority: 2,
        description: 'UPI/P2P/ref/NAME/vpa',
      ),

      // P3: Info field with name after last slash before bank code
      // "Info: UPI/CR/412345678901/ANKIT VERMA/9876543210@ybl/Yes Bank"
      BankSmsPattern(
        regex: RegExp(
          r'Info\s*:?\s*UPI/(?:CR|DR|P2P|P2M)/\d+/([A-Za-z][A-Za-z\s.]+?)/',
          caseSensitive: false,
        ),
        priority: 3,
        description: 'Info: UPI/CR|DR/ref/NAME/',
      ),

      // P4: UPI info with name between slashes (variant with multiple fields)
      // "UPI/412345678901/MANIKANDAN/mani@ybl"
      BankSmsPattern(
        regex: RegExp(
          r'UPI/\d{6,14}/([A-Za-z][A-Za-z\s.]{1,30})/[a-zA-Z0-9._-]+@',
          caseSensitive: false,
        ),
        priority: 4,
        description: 'UPI/ref/NAME/vpa',
      ),

      // P5: UPI Info with reversed order — VPA then name
      // Some banks: "Info: UPI/123/person@ybl/JOHN DOE"
      BankSmsPattern(
        regex: RegExp(
          r'UPI/\d+/[a-zA-Z0-9._-]+@[a-zA-Z]+/([A-Za-z][A-Za-z\s.]{1,30})',
          caseSensitive: false,
        ),
        priority: 5,
        description: 'UPI/ref/vpa@bank/NAME',
      ),

      // ─────────────────────────────────────────────────────────
      //  TIER 2: "TO NAME" / "FROM NAME" KEYWORD PATTERNS
      // ─────────────────────────────────────────────────────────

      // P11: "paid to NAME via UPI" / "paid to NAME UPI"
      BankSmsPattern(
        regex: RegExp(
          r'paid\s+to\s+([A-Za-z][A-Za-z\s.]{1,35}?)\s+(?:via\s+)?(?:UPI|IMPS|NEFT|RTGS)',
          caseSensitive: false,
        ),
        priority: 11,
        description: 'paid to NAME via UPI',
      ),

      // P12: "sent to NAME via UPI"
      BankSmsPattern(
        regex: RegExp(
          r'sent\s+to\s+([A-Za-z][A-Za-z\s.]{1,35}?)\s+(?:via\s+)?(?:UPI|IMPS|NEFT|RTGS)',
          caseSensitive: false,
        ),
        priority: 12,
        description: 'sent to NAME via UPI',
      ),

      // P13: "transferred to NAME via UPI/IMPS/NEFT"
      BankSmsPattern(
        regex: RegExp(
          r'transferred\s+to\s+([A-Za-z][A-Za-z\s.&,]{1,35}?)\s+(?:via\s+)?(?:UPI|IMPS|NEFT|RTGS)',
          caseSensitive: false,
        ),
        priority: 13,
        description: 'transferred to NAME via mode',
      ),

      // P14: "debited to NAME" / "to account of NAME"
      BankSmsPattern(
        regex: RegExp(
          r'(?:debited|deducted)\s+(?:to\s+|(?:a/c\s+of\s+|account\s+of\s+))(?!(?:[Ff]or\s+|[Rr]s\.?))([A-Za-z][A-Za-z\s.&,]{2,35}?)(?:\s+(?:via|on|Ref|UPI|IMPS|NEFT|RTGS|w\.?e\.?f|towards|for[.\s])|\s*[.])',
          caseSensitive: false,
        ),
        priority: 14,
        description: 'debited to NAME',
      ),

      // P15: "credited from NAME" / "received from NAME"
      BankSmsPattern(
        regex: RegExp(
          r'(?:credited|received)\s+from\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:via|on|Ref|UPI|IMPS|NEFT|RTGS|in\s+your)|[.,]|\s*$)',
          caseSensitive: false,
        ),
        priority: 15,
        description: 'credited from NAME',
      ),

      // P16: "credited by NAME" — also handles "credited to a/c XX by NAME"
      BankSmsPattern(
        regex: RegExp(
          r'credited(?:\s+to\s+(?:your\s+)?(?:a/c|acct|account)\s*[*xX\d]+)?\s+(?:\S+\s+)?by\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:via|on|Ref|UPI|IMPS|NEFT|RTGS)|[-\u2013]\s*(?:UPI|IMPS|NEFT)|[.,]|\s*$)',
          caseSensitive: false,
        ),
        priority: 16,
        description: 'credited by NAME (incl. credited to a/c XX by NAME)',
      ),

      // P16a: "credited with INR X from NAME" (IOB, ICICI common format)
      BankSmsPattern(
        regex: RegExp(
          r'credited\s+with\s+(?:Rs\.?|INR|\u20b9)\s*[\d,.]+\s+from\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:via|on|Ref|UPI|IMPS|NEFT)|[.,]|\s*$)',
          caseSensitive: false,
        ),
        priority: 16,
        description: 'credited with INR X from NAME',
      ),

      // P16b: "Received Rs.X from NAME" — BHIM / GPay / direct
      BankSmsPattern(
        regex: RegExp(
          r'[Rr]eceived\s+(?:Rs\.?|INR|\u20b9)\s*[\d,.]+\s+from\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:via|on|Ref|UPI|IMPS|NEFT)|[.,]|\s*$)',
          caseSensitive: false,
        ),
        priority: 16,
        description: 'Received Rs.X from NAME',
      ),

      // P16c: "NAME has sent you Rs.X" — Google Pay / PhonePe credit
      BankSmsPattern(
        regex: RegExp(
          r'^([A-Za-z][A-Za-z\s.]{2,35}?)\s+has\s+sent\s+you\s+(?:Rs\.?|INR|\u20b9)',
          caseSensitive: false,
          multiLine: true,
        ),
        priority: 16,
        description: 'NAME has sent you Rs.X (GPay/PhonePe style)',
      ),

      // P16d: "from NAME using UPI/IMPS" — credit via payment mode
      BankSmsPattern(
        regex: RegExp(
          r'from\s+([A-Za-z][A-Za-z\s.]{2,35}?)\s+using\s+(?:UPI|IMPS|NEFT|RTGS)',
          caseSensitive: false,
        ),
        priority: 16,
        description: 'from NAME using UPI',
      ),

      // P16e: "amount received from NAME" — Indian Bank / Canara / IOB
      BankSmsPattern(
        regex: RegExp(
          r'(?:an\s+)?(?:amount|amt)\s+(?:of\s+)?(?:Rs\.?|INR|\u20b9)\s*[\d,.]+\s+(?:has\s+been\s+)?received\s+from\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:via|on|Ref|UPI|IMPS)|[.,]|\s*$)',
          caseSensitive: false,
        ),
        priority: 16,
        description: 'amount received from NAME',
      ),

      // P16f: "credited to your a/c from NAME" — SBI / PNB
      BankSmsPattern(
        regex: RegExp(
          r'credited\s+to\s+your\s+(?:a/c|acct|account)\s*[*xX\d]+\s+from\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:via|on|Ref|UPI|IMPS)|[.,]|\s*$)',
          caseSensitive: false,
        ),
        priority: 16,
        description: 'SBI: credited to your a/c from NAME',
      ),

      // P16g: "You have received Rs.X from NAME" — polite bank format
      BankSmsPattern(
        regex: RegExp(
          r'[Yy]ou\s+ha(?:ve|s)\s+received\s+(?:Rs\.?|INR|\u20b9)\s*[\d,.]+\s+from\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:via|on|Ref|UPI|IMPS)|[.,]|\s*$)',
          caseSensitive: false,
        ),
        priority: 16,
        description: 'You have received Rs.X from NAME',
      ),

      // P16h: amount credited by NAME-UPI (SBI style "credited by NAME-UPI")
      BankSmsPattern(
        regex: RegExp(
          r'(?:Rs\.?|INR|\u20b9)\s*[\d,.]+\s+credited\s+by\s+([A-Za-z][A-Za-z\s.]{2,35}?)[-\u2013]\s*(?:UPI|IMPS|NEFT)',
          caseSensitive: false,
        ),
        priority: 16,
        description: 'SBI: Rs.X credited by NAME-UPI',
      ),

      // P17: "to NAME from A/c" — "sent ₹500 to MERCHANT from A/c XX1234"
      BankSmsPattern(
        regex: RegExp(
          r'to\s+([A-Za-z][A-Za-z\s.]{2,35}?)\s+from\s+(?:A/c|a/c|acct|account|your)',
          caseSensitive: false,
        ),
        priority: 17,
        description: 'to NAME from A/c',
      ),

      // P18: "for NAME" before UPI/Ref
      BankSmsPattern(
        regex: RegExp(
          r'for\s+([A-Za-z][A-Za-z\s.]{2,35}?)\s+(?:via\s+)?(?:UPI|IMPS|NEFT|RTGS)',
          caseSensitive: false,
        ),
        priority: 18,
        description: 'for NAME via UPI',
      ),

      // P19: "to NAME" (generic, before markers)
      BankSmsPattern(
        regex: RegExp(
          r'\bto\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+)(?:via|on|at|Ref|ref|REF|UPI|IMPS|NEFT)',
          caseSensitive: false,
        ),
        priority: 19,
        description: 'to NAME Ref',
      ),

      // P20: "from NAME" before markers (for credits)
      BankSmsPattern(
        regex: RegExp(
          r'\bfrom\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+)(?:to|via|on|at|Ref|ref|REF|UPI|IMPS|NEFT)',
          caseSensitive: false,
        ),
        priority: 20,
        description: 'from NAME Ref',
      ),

      // P21: "From NAME via UPI." — sentence-start credit pattern
      BankSmsPattern(
        regex: RegExp(
          r'[.!]\s*[Ff]rom\s+([A-Z][A-Za-z\s.]{2,35})\s+(?:via\s+)?(?:UPI|IMPS|NEFT)',
        ),
        priority: 21,
        description: '.From NAME via UPI.',
      ),

      // P22: "towards NAME" — some banks use "towards" instead of "to"
      BankSmsPattern(
        regex: RegExp(
          r'towards\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:via|on|Ref|UPI|IMPS|NEFT|RTGS|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 22,
        description: 'towards NAME',
      ),

      // P23: "trf to NAME" — common in bank SMS
      BankSmsPattern(
        regex: RegExp(
          r'(?:trf|transfer|xfer)\s+to\s+([A-Za-z][A-Za-z\s.&,]{2,35}?)(?:\s+(?:via|Ref|UPI|IMPS|NEFT|RTGS|[.(])|\s*$)',
          caseSensitive: false,
        ),
        priority: 23,
        description: 'trf to NAME',
      ),

      // P23c: "paid ... to NAME, UPI Ref" (Canara style with comma)
      BankSmsPattern(
        regex: RegExp(
          r'paid\s+(?:thru\s+)?(?:A/C|a/c)\s+[*xX\d]+\s+on\s+[\d-]+\s+[\d:]+\s+to\s+([A-Za-z][A-Za-z\s.&]{1,35}?),?\s+UPI\s+Ref',
          caseSensitive: false,
        ),
        priority: 11,
        description: 'Canara: paid to NAME, UPI Ref',
      ),

      // P23b: "credited to NAME" — HDFC / Generic
      BankSmsPattern(
        regex: RegExp(
          r'credited\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:via|Ref|UPI|IMPS|NEFT|RTGS|[.(])|\s*$)',
          caseSensitive: false,
        ),
        priority: 23,
        description: 'credited to NAME',
      ),

      // P24: "paid NAME" (without "to") — "Rs.500 paid SWIGGY"
      BankSmsPattern(
        regex: RegExp(
          r'paid\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:via|on|Ref|UPI|IMPS|using|[.(])|\s*$)',
          caseSensitive: false,
        ),
        priority: 24,
        description: 'paid NAME',
      ),

      // P25: "sent NAME" (without "to")
      BankSmsPattern(
        regex: RegExp(
          r'sent\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:via|on|Ref|UPI|IMPS|[.(])|\s*$)',
          caseSensitive: false,
        ),
        priority: 25,
        description: 'sent NAME',
      ),

      // ─────────────────────────────────────────────────────────
      //  TIER 3: MERCHANT / POS / CARD PATTERNS
      // ─────────────────────────────────────────────────────────

      // P31: "at MERCHANT on DATE" — POS / card transactions
      BankSmsPattern(
        regex: RegExp(
          r"(?:at|@)\s+([A-Za-z][A-Za-z\s.&'\-]{2,35})\s+(?:on|for|dated)",
          caseSensitive: false,
        ),
        priority: 31,
        description: 'at MERCHANT on date',
      ),

      // P32: "at MERCHANT using Card" / "at MERCHANT using Debit Card"
      BankSmsPattern(
        regex: RegExp(
          r"(?:at|@)\s+([A-Za-z][A-Za-z\s.&'\-]{2,35})\s+using\s+(?:Debit|Credit|HDFC|ICICI|SBI|Axis)?\s*(?:Card|card)",
          caseSensitive: false,
        ),
        priority: 32,
        description: 'at MERCHANT using Card',
      ),

      // P33: "debited at MERCHANT" — simplified POS pattern
      BankSmsPattern(
        regex: RegExp(
          r"debited\s+at\s+([A-Za-z][A-Za-z\s.&'\-]{2,35}?)(?:\s+(?:on|for|using|Ref|[.])|\s*$)",
          caseSensitive: false,
        ),
        priority: 33,
        description: 'debited at MERCHANT',
      ),

      // P34: "spent at MERCHANT"
      BankSmsPattern(
        regex: RegExp(
          r"spent\s+at\s+([A-Za-z][A-Za-z\s.&'\-]{2,35}?)(?:\s+(?:on|for|using|Ref|[.])|\s*$)",
          caseSensitive: false,
        ),
        priority: 34,
        description: 'spent at MERCHANT',
      ),

      // P35: "purchase at MERCHANT" / "purchased at MERCHANT"
      BankSmsPattern(
        regex: RegExp(
          r"purchas(?:e|ed)\s+at\s+([A-Za-z][A-Za-z\s.&'\-]{2,35}?)(?:\s+(?:on|for|using|Ref|[.])|\s*$)",
          caseSensitive: false,
        ),
        priority: 35,
        description: 'purchase at MERCHANT',
      ),

      // P36: "used at MERCHANT" — "Card XX1234 used at SWIGGY"
      BankSmsPattern(
        regex: RegExp(
          r"used\s+at\s+([A-Za-z][A-Za-z\s.&'\-]{2,35}?)(?:\s+(?:on|for|Ref|[.])|\s*$)",
          caseSensitive: false,
        ),
        priority: 36,
        description: 'used at MERCHANT',
      ),

      // P37: "txn at MERCHANT" / "transaction at MERCHANT"
      BankSmsPattern(
        regex: RegExp(
          r"(?:txn|transaction)\s+at\s+([A-Za-z][A-Za-z\s.&'\-]{2,35}?)(?:\s+(?:on|for|Ref|[.])|\s*$)",
          caseSensitive: false,
        ),
        priority: 37,
        description: 'txn at MERCHANT',
      ),

      // P38: "towards MERCHANT" (card/EMI context)
      BankSmsPattern(
        regex: RegExp(
          r"towards\s+([A-Za-z][A-Za-z\s.&'\-]{2,35}?)(?:\s+(?:on|for|Ref|[.])|\s*$)",
          caseSensitive: false,
        ),
        priority: 38,
        description: 'towards MERCHANT (card)',
      ),

      // P39: "for purchase at MERCHANT"
      BankSmsPattern(
        regex: RegExp(
          r"for\s+(?:purchase|payment|txn)\s+at\s+([A-Za-z][A-Za-z\s.&'\-]{2,35}?)(?:\s+(?:on|Ref|[.])|\s*$)",
          caseSensitive: false,
        ),
        priority: 39,
        description: 'for purchase at MERCHANT',
      ),

      // P40: "ATM withdrawal at LOCATION" / "ATM WDL at LOCATION"
      BankSmsPattern(
        regex: RegExp(
          r"(?:ATM|atm)\s+(?:withdrawal|wdl|cash\s+withdrawal|WDL)\s+(?:at|from)\s+([A-Za-z][A-Za-z\s.0-9]{2,35}?)(?:\s+(?:on|Ref|[.])|\s*$)",
          caseSensitive: false,
        ),
        priority: 40,
        description: 'ATM withdrawal at LOCATION',
      ),

      // ─────────────────────────────────────────────────────────
      //  TIER 4: BANK-SPECIFIC PATTERNS
      // ─────────────────────────────────────────────────────────

      // ── SBI Patterns ──

      // P51: SBI "Your a/c XX1234 debited for Rs.100 transfer to NAME"
      BankSmsPattern(
        regex: RegExp(
          r'transfer\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:via|Ref|ref|UPI|IMPS|NEFT|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 51,
        description: 'SBI: transfer to NAME',
      ),

      // P52: SBI "Rs.500 credited by NAME-UPI"
      BankSmsPattern(
        regex: RegExp(
          r'credited\s+by\s+([A-Za-z][A-Za-z\s.]{2,30}?)[-\s]+(?:UPI|IMPS|NEFT)',
          caseSensitive: false,
        ),
        priority: 52,
        description: 'SBI: credited by NAME-UPI',
      ),

      // P53: SBI "debited by Rs.500 for NAME" / "debited for NAME"
      BankSmsPattern(
        regex: RegExp(
          r'debited\s+(?:by\s+(?:Rs\.?|INR|₹)\s*[\d,.]+\s+)?for\s+([A-Z][A-Za-z\s.]{2,35}?)(?:\s+(?:Ref|ref|UPI|IMPS|NEFT|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 53,
        description: 'SBI: debited for NAME',
      ),

      // ── HDFC Patterns ──

      // P54: HDFC "Rs X debited from a/c **1234 to YY on DD-MM-YY"
      BankSmsPattern(
        regex: RegExp(
          r'debited\s+from\s+a/c\s+[*xX\d]+\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)\s+on',
          caseSensitive: false,
        ),
        priority: 54,
        description: 'HDFC: debited from a/c to NAME on',
      ),

      // P55: HDFC "Money sent to NAME, Ref No XXXX"
      BankSmsPattern(
        regex: RegExp(
          r'[Mm]oney\s+sent\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)[,.]?\s*(?:Ref|ref|REF)',
          caseSensitive: false,
        ),
        priority: 55,
        description: 'HDFC: Money sent to NAME, Ref',
      ),

      // P56: HDFC "You have done a UPI txn. Amt Rs.500 sent to NAME"
      BankSmsPattern(
        regex: RegExp(
          r'(?:Amt|Amount)\s+(?:Rs\.?|INR|₹)\s*[\d,.]+\s+sent\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:Ref|ref|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 56,
        description: 'HDFC: Amt Rs.X sent to NAME',
      ),

      // ── ICICI Patterns ──

      // P57: ICICI "Your Acct XX1234 debited INR X on DD-MMM-YY to NAME"
      BankSmsPattern(
        regex: RegExp(
          r'debited\s+(?:INR|Rs\.?|₹)\s*[\d,.]+\s+on\s+[\d-]+\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:Ref|ref|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 57,
        description: 'ICICI: debited INR X on DATE to NAME',
      ),

      // P58: ICICI "Acct XX credited with INR X by NAME on DATE"
      BankSmsPattern(
        regex: RegExp(
          r'credited\s+with\s+(?:INR|Rs\.?|₹)\s*[\d,.]+\s+by\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+on|\s+Ref|\s*[.])',
          caseSensitive: false,
        ),
        priority: 58,
        description: 'ICICI: credited with INR X by NAME',
      ),

      // P59: ICICI "Money transferred to NAME from Acct XX"
      BankSmsPattern(
        regex: RegExp(
          r'[Mm]oney\s+transferred\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)\s+from',
          caseSensitive: false,
        ),
        priority: 59,
        description: 'ICICI: Money transferred to NAME from',
      ),

      // ── Axis Bank Patterns ──

      // P60: Axis "Rs.X debited from A/c no. XX1234 to NAME on DATE"
      BankSmsPattern(
        regex: RegExp(
          r'from\s+[Aa]/[Cc]\s+(?:no\.?\s+)?[*xX\d]+\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+on|\s+Ref)',
          caseSensitive: false,
        ),
        priority: 60,
        description: 'Axis: from A/c to NAME on',
      ),

      // P61: Axis "Payment of Rs.X to NAME successful"
      BankSmsPattern(
        regex: RegExp(
          r'[Pp]ayment\s+of\s+(?:Rs\.?|INR|₹)\s*[\d,.]+\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)\s+(?:successful|completed|done)',
          caseSensitive: false,
        ),
        priority: 61,
        description: 'Axis: Payment of Rs.X to NAME successful',
      ),

      // P61b: Axis/ICICI "Payment of Rs.X successful to NAME"
      BankSmsPattern(
        regex: RegExp(
          r'[Pp]ayment\s+of\s+(?:Rs\.?|INR|₹)\s*[\d,.]+\s+(?:successful|completed|done)\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:via|Ref|ref|UPI|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 61,
        description: 'Axis: Payment of Rs.X successful to NAME',
      ),

      // ── IOB Patterns ──

      // P62: IOB "Rs.X debited from A/c XXXX1234 to NAME via UPI"
      BankSmsPattern(
        regex: RegExp(
          r'debited\s+from\s+(?:A/c|a/c|Acct)\s+[*xX\d]+\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:via|Ref|UPI|IMPS|NEFT|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 62,
        description: 'IOB: debited from A/c to NAME',
      ),

      // P63: IOB "INR X paid to NAME via UPI Ref No XXX"
      BankSmsPattern(
        regex: RegExp(
          r'(?:INR|Rs\.?|₹)\s*[\d,.]+\s+paid\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:via|Ref|ref|UPI|IMPS|NEFT|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 63,
        description: 'IOB: INR X paid to NAME via',
      ),

      // ── PNB Patterns ──

      // P64: PNB "Dear Customer, Rs.X has been debited to NAME from A/c"
      BankSmsPattern(
        regex: RegExp(
          r'has\s+been\s+debited\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)\s+from',
          caseSensitive: false,
        ),
        priority: 64,
        description: 'PNB: has been debited to NAME from',
      ),

      // ── Canara Bank Generic Patterns ──

      // P72: "CREDITED to your account [AC]" (Canara generic)
      BankSmsPattern(
        regex: RegExp(
          r'(?:CREDITED|DEBITED)\s+to\s+your\s+account\s+[*xX]*(\d{3,4})',
          caseSensitive: true,
        ),
        priority: 72,
        description: 'Canara: CREDITED/DEBITED to your account XXX',
      ),

      // P73: "... credited with Rs.X from a/c no. XX1234" (Canara account credit)
      BankSmsPattern(
        regex: RegExp(
          r'credited\s+with\s+(?:Rs\.?|INR|₹)\s*[\d,.]+\s+from\s+a/c\s+no\.\s+[*xX]*(\d{3,4})',
          caseSensitive: false,
        ),
        priority: 73,
        description: 'Canara: credited from a/c no. XXX',
      ),

      // P65: PNB "Rs.X transferred to NAME through UPI"
      BankSmsPattern(
        regex: RegExp(
          r'transferred\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)\s+(?:through|via|thru)\s+(?:UPI|IMPS|NEFT|RTGS)',
          caseSensitive: false,
        ),
        priority: 65,
        description: 'PNB: transferred to NAME through UPI',
      ),

      // ── Kotak Patterns ──

      // P66: Kotak "Rs.X sent to NAME from A/c XX1234"
      BankSmsPattern(
        regex: RegExp(
          r'sent\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)\s+from\s+(?:A/c|a/c|your)',
          caseSensitive: false,
        ),
        priority: 66,
        description: 'Kotak: sent to NAME from A/c',
      ),

      // P67: Kotak "Transaction of Rs.X to NAME is successful"
      BankSmsPattern(
        regex: RegExp(
          r'[Tt]ransaction\s+of\s+(?:Rs\.?|INR|₹)\s*[\d,.]+\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)\s+(?:is\s+)?(?:successful|completed)',
          caseSensitive: false,
        ),
        priority: 67,
        description: 'Kotak: Transaction of Rs.X to NAME',
      ),

      // ── Yes Bank Patterns ──

      // P68: Yes Bank "Rs.X debited against UPI txn to NAME"
      BankSmsPattern(
        regex: RegExp(
          r'debited\s+against\s+(?:UPI\s+)?(?:txn|transaction)\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:Ref|ref|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 68,
        description: 'Yes Bank: debited against UPI txn to NAME',
      ),

      // ── Canara Bank Patterns ──

      // P69: Canara "Rs.X debited from your account for payment to NAME"
      BankSmsPattern(
        regex: RegExp(
          r'for\s+payment\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:via|Ref|ref|UPI|IMPS|NEFT|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 69,
        description: 'Canara: payment to NAME',
      ),

      // ── Union Bank Patterns ──

      // P70: Union "Amt Rs.X debited from A/c and credited to NAME"
      BankSmsPattern(
        regex: RegExp(
          r'(?:debited|deducted)\s+.*?credited\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:Ref|ref|UPI|IMPS|NEFT|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 70,
        description: 'Union: debited...credited to NAME',
      ),

      // ── BOB (Bank of Baroda) Patterns ──

      // P71: BOB "Rs.X has been debited to your a/c towards NAME"
      BankSmsPattern(
        regex: RegExp(
          r'debited\s+to\s+your\s+a/c\s+towards\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:Ref|ref|UPI|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 71,
        description: 'BOB: debited towards NAME',
      ),

      // ── Indian Bank Patterns ──

      // P72: Indian Bank "Rs.X debited from A/c XX to beneficiary NAME"
      BankSmsPattern(
        regex: RegExp(
          r'(?:to\s+)?beneficiary\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:via|Ref|ref|UPI|IMPS|NEFT|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 72,
        description: 'Indian Bank: beneficiary NAME',
      ),

      // P73: Indian Bank "payment to NAME for Rs.X"
      BankSmsPattern(
        regex: RegExp(
          r'payment\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)\s+for\s+(?:Rs\.?|INR|₹)',
          caseSensitive: false,
        ),
        priority: 73,
        description: 'Indian Bank: payment to NAME for Rs',
      ),

      // ── Federal Bank Patterns ──

      // P74: Federal "Rs.X sent via UPI to NAME"
      BankSmsPattern(
        regex: RegExp(
          r'sent\s+via\s+(?:UPI|IMPS|NEFT)\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:Ref|ref|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 74,
        description: 'Federal: sent via UPI to NAME',
      ),

      // ── IDFC First Patterns ──

      // P75: IDFC "Rs.X paid to NAME from a/c XX"
      BankSmsPattern(
        regex: RegExp(
          r'paid\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)\s+from\s+(?:A/c|a/c)',
          caseSensitive: false,
        ),
        priority: 75,
        description: 'IDFC: paid to NAME from a/c',
      ),

      // ── Generic Bank Patterns ──

      // P76: "Your a/c debited by Rs.X for txn to NAME"
      BankSmsPattern(
        regex: RegExp(
          r'for\s+(?:txn|transaction)\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:Ref|ref|UPI|IMPS|NEFT|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 76,
        description: 'Generic: for txn to NAME',
      ),

      // P77: "UPI payment to NAME successful"
      BankSmsPattern(
        regex: RegExp(
          r'(?:UPI|IMPS|NEFT)\s+payment\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)\s+(?:successful|completed|done)',
          caseSensitive: false,
        ),
        priority: 77,
        description: 'UPI payment to NAME successful',
      ),

      // P78: "Fund transfer to NAME"
      BankSmsPattern(
        regex: RegExp(
          r'[Ff]und\s+transfer\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:is|was|has|Ref|ref|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 78,
        description: 'Fund transfer to NAME',
      ),

      // P79: "NEFT/RTGS to NAME credited/debited"
      BankSmsPattern(
        regex: RegExp(
          r'(?:NEFT|RTGS|IMPS)\s+(?:to|from)\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:credited|debited|successful|Ref|ref|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 79,
        description: 'NEFT/RTGS to NAME',
      ),

      // P80: "withdrawn at ATM LOCATION" (simple)
      BankSmsPattern(
        regex: RegExp(
          r'withdrawn\s+(?:at|from)\s+(?:ATM\s+)?([A-Za-z][A-Za-z\s.0-9]{2,35}?)(?:\s+(?:on|Ref|ref|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 80,
        description: 'withdrawn at ATM LOCATION',
      ),

      // ─────────────────────────────────────────────────────────
      //  TIER 5: VPA / GENERIC FALLBACK PATTERNS
      // ─────────────────────────────────────────────────────────

      // P81: "VPA person@bank (NAME)" — parenthesized name after VPA
      BankSmsPattern(
        regex: RegExp(
          r'(?:VPA\s+)?[a-zA-Z0-9._-]+@[a-zA-Z]+\s*\(([A-Za-z][A-Za-z\s.]+?)\)',
          caseSensitive: false,
        ),
        priority: 81,
        description: 'VPA person@bank (NAME)',
      ),

      // P82: "to NAME on DATE" — generic to-pattern with date
      BankSmsPattern(
        regex: RegExp(
          r'\bto\s+([A-Za-z][A-Za-z\s.]{2,35}?)\s+on\s+\d',
          caseSensitive: false,
        ),
        priority: 82,
        description: 'to NAME on DATE',
      ),

      // P83: "from NAME on DATE" — generic from-pattern with date
      BankSmsPattern(
        regex: RegExp(
          r'\bfrom\s+([A-Za-z][A-Za-z\s.]{2,35}?)\s+on\s+\d',
          caseSensitive: false,
        ),
        priority: 83,
        description: 'from NAME on DATE',
      ),

      // P84: "by NAME on DATE"
      BankSmsPattern(
        regex: RegExp(
          r'\bby\s+([A-Za-z][A-Za-z\s.]{2,35}?)\s+on\s+\d',
          caseSensitive: false,
        ),
        priority: 84,
        description: 'by NAME on DATE',
      ),

      // P85: "to NAME." — name before end of sentence
      BankSmsPattern(
        regex: RegExp(
          r'\bto\s+([A-Za-z][A-Za-z\s.]{2,35}?)\s*[.]',
          caseSensitive: false,
        ),
        priority: 85,
        description: 'to NAME.',
      ),

      // P86: "Beneficiary: NAME" — some banks use label format
      BankSmsPattern(
        regex: RegExp(
          r'[Bb]eneficiary\s*[:=]\s*([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:Ref|ref|A/c|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 86,
        description: 'Beneficiary: NAME',
      ),

      // P87: "Payee: NAME" — label format
      BankSmsPattern(
        regex: RegExp(
          r'[Pp]ayee\s*[:=]\s*([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:Ref|ref|A/c|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 87,
        description: 'Payee: NAME',
      ),

      // P88: "Merchant: NAME" — label format
      BankSmsPattern(
        regex: RegExp(
          r"[Mm]erchant\s*[:=]\s*([A-Za-z][A-Za-z\s.&'\-]{2,35}?)(?:\s+(?:Ref|ref|Txn|[.])|\s*$)",
          caseSensitive: false,
        ),
        priority: 88,
        description: 'Merchant: NAME',
      ),

      // P89: "Sender: NAME" — for credits
      BankSmsPattern(
        regex: RegExp(
          r'[Ss]ender\s*[:=]\s*([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:Ref|ref|A/c|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 89,
        description: 'Sender: NAME',
      ),

      // P90: "Receiver: NAME" — label format
      BankSmsPattern(
        regex: RegExp(
          r'[Rr]eceiver\s*[:=]\s*([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:Ref|ref|A/c|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 90,
        description: 'Receiver: NAME',
      ),

      // ─────────────────────────────────────────────────────────
      //  TIER 6: WALLET / APP-SPECIFIC PATTERNS
      // ─────────────────────────────────────────────────────────

      // P91: "Payment to NAME via Paytm/GPay/PhonePe"
      BankSmsPattern(
        regex: RegExp(
          r'[Pp]ayment\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)\s+(?:via|through|using)\s+(?:Paytm|GPay|Google Pay|PhonePe|BHIM|Amazon Pay|WhatsApp)',
          caseSensitive: false,
        ),
        priority: 91,
        description: 'Payment to NAME via App',
      ),

      // P92: "Wallet: Rs.X paid to NAME"
      BankSmsPattern(
        regex: RegExp(
          r'(?:Wallet|wallet)\s*:?\s*(?:Rs\.?|INR|₹)\s*[\d,.]+\s+paid\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s*$|\s+(?:Ref|ref|[.]))',
          caseSensitive: false,
        ),
        priority: 92,
        description: 'Wallet: Rs.X paid to NAME',
      ),

      // P93: "Money sent to NAME via UPI"
      BankSmsPattern(
        regex: RegExp(
          r'[Mm]oney\s+sent\s+to\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:via|Ref|ref|UPI|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 93,
        description: 'Money sent to NAME',
      ),

      // P94: "Money received from NAME"
      BankSmsPattern(
        regex: RegExp(
          r'[Mm]oney\s+received\s+from\s+([A-Za-z][A-Za-z\s.]{2,35}?)(?:\s+(?:via|Ref|ref|UPI|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 94,
        description: 'Money received from NAME',
      ),

      // ─────────────────────────────────────────────────────────
      //  TIER 7: ULTRA-FALLBACK PATTERNS
      // ─────────────────────────────────────────────────────────

      // P101: Generic "to NAME" with 3+ char name (very broad)
      BankSmsPattern(
        regex: RegExp(
          r'\bto\s+([A-Za-z][A-Za-z\s.]{2,30}?)(?:\s+(?:Avl|avl|Bal|bal|A/c|Ref|ref|on|is|was|for|UPI|IMPS|NEFT|RTGS|successfully|completed|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 101,
        description: 'Fallback: to NAME (broad)',
      ),

      // P102: Generic "from NAME" with 3+ char name
      BankSmsPattern(
        regex: RegExp(
          r'\bfrom\s+([A-Za-z][A-Za-z\s.]{2,30}?)(?:\s+(?:Avl|avl|Bal|bal|A/c|Ref|ref|on|is|was|for|UPI|IMPS|NEFT|RTGS|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 102,
        description: 'Fallback: from NAME (broad)',
      ),

      // P103: "by NAME" fallback
      BankSmsPattern(
        regex: RegExp(
          r'\bby\s+([A-Za-z][A-Za-z\s.]{2,30}?)(?:\s+(?:Avl|avl|Bal|bal|A/c|Ref|ref|on|is|was|for|UPI|IMPS|NEFT|RTGS|[.])|\s*$)',
          caseSensitive: false,
        ),
        priority: 103,
        description: 'Fallback: by NAME (broad)',
      ),

      // P104: Bare VPA as final fallback — "to person@ybl"
      BankSmsPattern(
        regex: RegExp(
          r'(?:to|from)\s+(?:VPA\s+)?([a-zA-Z0-9._-]+@[a-zA-Z]+)',
          caseSensitive: false,
        ),
        priority: 104,
        description: 'Fallback: bare VPA',
        cleanupResult: false,
      ),

      // P105: Standalone VPA in text body
      BankSmsPattern(
        regex: RegExp(
          r'\b([a-zA-Z][a-zA-Z0-9._-]*@(?:ybl|upi|apl|okhdfcbank|okicici|oksbi|okaxis|paytm))\b',
          caseSensitive: false,
        ),
        priority: 105,
        description: 'Fallback: standalone VPA handle',
        cleanupResult: false,
      ),
    ];

    // Sort by priority for deterministic matching order.
    patterns.sort((a, b) => a.priority.compareTo(b.priority));
    return patterns;
  }

  // ═══════════════════════════════════════════════════════════════
  //  TRANSACTION MODE DETECTION PATTERNS
  // ═══════════════════════════════════════════════════════════════

  /// Detect the transaction mode from SMS body text.
  ///
  /// Returns one of: UPI, IMPS, NEFT, RTGS, Card, ATM, Wallet, or null.
  static String? detectTransactionMode(String text) {
    final lower = text.toLowerCase();

    // Check in priority order (most specific first)
    for (final entry in _modePatterns) {
      if (entry.pattern.hasMatch(lower)) {
        return entry.mode;
      }
    }
    return null;
  }

  static final _modePatterns = [
    _ModePattern(RegExp(r'\bupi\b', caseSensitive: false), 'UPI'),
    _ModePattern(RegExp(r'\bimps\b', caseSensitive: false), 'IMPS'),
    _ModePattern(RegExp(r'\bneft\b', caseSensitive: false), 'NEFT'),
    _ModePattern(RegExp(r'\brtgs\b', caseSensitive: false), 'RTGS'),
    _ModePattern(RegExp(r'(?:debit|credit)\s*card', caseSensitive: false), 'Card'),
    _ModePattern(RegExp(r'\bcard\s+(?:ending|no\.?|number|xx)', caseSensitive: false), 'Card'),
    _ModePattern(RegExp(r'\bpos\b', caseSensitive: false), 'Card'),
    _ModePattern(RegExp(r'\batm\b', caseSensitive: false), 'ATM'),
    _ModePattern(RegExp(r'cash\s+with(?:drawal|drawn)', caseSensitive: false), 'ATM'),
    _ModePattern(RegExp(r'\bwallet\b', caseSensitive: false), 'Wallet'),
    _ModePattern(RegExp(r'\b(?:paytm|phonepe|gpay|google\s*pay|amazon\s*pay|whatsapp)\b', caseSensitive: false), 'UPI'),
  ];

  // ═══════════════════════════════════════════════════════════════
  //  BANK NAME DETECTION
  // ═══════════════════════════════════════════════════════════════

  /// Map sender ID to a human-readable bank name.
  static String? detectBankFromSender(String sender) {
    final clean = sender.replaceAll(RegExp(r'^[A-Z]{2}-'), '').toUpperCase();
    return _senderToBankMap[clean];
  }

  static const _senderToBankMap = <String, String>{
    'SBIINB': 'SBI',
    'SBINOB': 'SBI',
    'SBIBNK': 'SBI',
    'SBISMS': 'SBI',
    'HDFCBK': 'HDFC Bank',
    'HDFCBN': 'HDFC Bank',
    'ICICIB': 'ICICI Bank',
    'ICICBK': 'ICICI Bank',
    'AXISBK': 'Axis Bank',
    'AXSBNK': 'Axis Bank',
    'IOBCHN': 'IOB',
    'IABORB': 'IOB',
    'IOBBNK': 'IOB',
    'KOTAKB': 'Kotak Mahindra Bank',
    'KOTKBK': 'Kotak Mahindra Bank',
    'PNBSMS': 'PNB',
    'PNBBNK': 'PNB',
    'CANBNK': 'Canara Bank',
    'CNRBNK': 'Canara Bank',
    'BOBSMS': 'Bank of Baroda',
    'BARBOD': 'Bank of Baroda',
    'INDBNK': 'Indian Bank',
    'INDBKS': 'Indian Bank',
    'FEDBKN': 'Federal Bank',
    'FEDBNK': 'Federal Bank',
    'YESBNK': 'Yes Bank',
    'YESBKN': 'Yes Bank',
    'IDFCFB': 'IDFC First Bank',
    'IDFCBK': 'IDFC First Bank',
    'UCOBNK': 'UCO Bank',
    'BOIIND': 'Bank of India',
    'BOISTR': 'Bank of India',
    'UBINBK': 'Union Bank',
    'UNIONB': 'Union Bank',
    'CENTBK': 'Central Bank',
    'MAHABK': 'Bank of Maharashtra',
    'DENABN': 'Dena Bank',
    'SYNBNK': 'Syndicate Bank',
    'ANDRBN': 'Andhra Bank',
    'ALLABD': 'Allahabad Bank',
    'PAYTMB': 'Paytm Payments Bank',
    'PHONEPE': 'PhonePe',
    'GPAY': 'Google Pay',
    'RBLBNK': 'RBL Bank',
    'BANDHN': 'Bandhan Bank',
    'INDUSB': 'IndusInd Bank',
    'DCBBKN': 'DCB Bank',
    'KRNBNK': 'Karnataka Bank',
    'TMBBKS': 'TMB Bank',
    'KVBBNK': 'KVB Bank',
    'CSBBNK': 'CSB Bank',
    'SOUBNK': 'South Indian Bank',
    'LKBBNK': 'Lakshmi Vilas Bank',
    'DHANLX': 'Dhanlaxmi Bank',
    'JKBANK': 'J&K Bank',
  };

  // ═══════════════════════════════════════════════════════════════
  //  AMOUNT EXTRACTION PATTERNS
  // ═══════════════════════════════════════════════════════════════

  /// Ordered list of amount extraction patterns.
  /// These are tried in sequence; first match wins.
  static final amountPatterns = <RegExp>[
    // ₹ symbol (most common in modern SMS)
    RegExp(r'[₹]\s?([\d,]+\.?\d{0,2})'),
    // Rs. or Rs followed by amount
    RegExp(r'Rs\.?\s?([\d,]+\.?\d{0,2})', caseSensitive: false),
    // INR followed by amount
    RegExp(r'INR\s?([\d,]+\.?\d{0,2})', caseSensitive: false),
    // "of Rs X" / "for Rs X" / "by Rs X" / "with Rs X"
    RegExp(
      r'(?:of|for|by|with)\s+(?:Rs\.?|INR|₹)\s?([\d,]+\.?\d{0,2})',
      caseSensitive: false,
    ),
    // Amount followed by currency (reversed: "500.00 INR")
    RegExp(r'([\d,]+\.?\d{0,2})\s*(?:INR|Rs\.?)', caseSensitive: false),
  ];

  // ═══════════════════════════════════════════════════════════════
  //  REFERENCE NUMBER EXTRACTION PATTERNS
  // ═══════════════════════════════════════════════════════════════

  static final referencePatterns = <RegExp>[
    RegExp(r'UPI\s*(?:Ref|ref)\.?\s*(?:No|no)?\.?\s*:?\s*(\d{8,14})',
        caseSensitive: false),
    RegExp(r'UPI/\w+/(\d{8,14})', caseSensitive: false),
    RegExp(r'Ref\s*(?:No|no)?\.?\s*:?\s*(\d{8,14})', caseSensitive: false),
    RegExp(r'TxnId\s*:?\s*(\d{8,14})', caseSensitive: false),
    RegExp(r'Txn\s*(?:No|no)?\.?\s*:?\s*(\d{8,14})', caseSensitive: false),
    RegExp(r'(?:IMPS|NEFT|RTGS)\s*(?:Ref|ref)?\s*:?\s*(\d{8,14})',
        caseSensitive: false),
    RegExp(r'Transaction\s*(?:ID|Id|id|No|no)\s*:?\s*(\d{8,14})',
        caseSensitive: false),
    RegExp(r'Approval\s*(?:Code|code|No|no)\s*:?\s*(\d{6,14})',
        caseSensitive: false),
  ];

  // ═══════════════════════════════════════════════════════════════
  //  ACCOUNT HINT EXTRACTION PATTERNS
  // ═══════════════════════════════════════════════════════════════

  static final accountHintPatterns = <RegExp>[
    RegExp(r'[Aa]/[Cc]\s*(?:[Nn]o)?\.?\s*[*xX]*(\d{3,4})\b'),
    RegExp(r'account\s+(?:ending|no\.?|number)?\s*[*xX]*(\d{3,4})\b',
        caseSensitive: false),
    RegExp(r'[Aa]cct\s*(?:[Nn]o)?\.?\s*[*xX]*(\d{3,4})\b'),
    RegExp(r'\*{2,}(\d{3,4})\b'),
    RegExp(r'XX(\d{3,4})\b'),
  ];
}

/// Internal helper for mode detection.
class _ModePattern {
  final RegExp pattern;
  final String mode;
  const _ModePattern(this.pattern, this.mode);
}
