import 'dart:collection';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../data/database/app_database.dart';
import '../core/utils/merchant_identity.dart';
import '../core/utils/regex_pattern_library.dart';
import '../core/utils/sms_transaction_parser.dart';
import 'contact_lookup_service.dart';
import 'merchant_learning_service.dart';
import 'sms_service.dart';

/// SMS Sync Service — scans bank SMS on app open and auto-imports
/// all UPI transactions (debits + credits) into the database.
///
/// Dedup strategy (multi-layer):
///   Layer 1: UPI ref number match (strongest, catches most app-tracked txns)
///   Layer 2: DEBIT — amount + timestamp (±5 min), ignores payee name mismatch
///   Layer 3: SMS reimport guard — amount + direction + SMS_IMPORT mode (±1 min)
///
/// Filters:
///   - Skips OTP, promotional, balance-check, and non-transaction SMS
///   - Only imports SMS with valid parsed amount > 0
///
/// Persists the last-sync timestamp in secure storage.
class SmsSyncService {
  SmsSyncService._();

  static const _storage = FlutterSecureStorage();
  static const _lastSyncKey = 'sms_sync_last_timestamp';
  static const _processedHashesKey = 'sms_sync_processed_hashes_v1';
  static const _maxStoredHashes = 4000;
  static const _uuid = Uuid();

  /// Run the full sync pipeline. Returns the count of newly imported transactions.
  static Future<int> sync(AppDatabase db) async {
    try {
      // 1. Check SMS permission
      final hasPerm = await SmsService.hasSmsPermission();
      if (!hasPerm) {
        debugPrint('PayTrace SMS Sync: No SMS permission — skipping');
        return 0;
      }

      // 2. Get last sync timestamp (default: 30 days ago for first run)
      final lastSync = await _getLastSyncTime();
      debugPrint('PayTrace SMS Sync: Starting since $lastSync');

      // 2b. Pre-load device contacts once for O(1) name lookups
      await ContactLookupService.preloadContacts();

      // 3. Read all SMS since last sync
      final smsList = await SmsService.readRecentSms(since: lastSync);
      debugPrint('PayTrace SMS Sync: Found ${smsList.length} bank SMS');

      if (smsList.isEmpty) {
        await _saveLastSyncTime(DateTime.now());
        return 0;
      }

      // 4. Filter: only valid UPI transaction SMS (not junk)
      final transactionSms = smsList
          .where((sms) =>
              _isValidTransactionSms(sms) &&
              sms.amount != null &&
              sms.amount! > 0)
          .toList();

      debugPrint('PayTrace SMS Sync: ${transactionSms.length} valid UPI transactions');

      // 4b. Hash-based dedup (body + timestamp) to avoid re-importing
      // the same SMS across sync cycles and within the same scan batch.
      final processedHashes = await _loadProcessedSmsHashes();
      var processedHashesDirty = false;

      int imported = 0;

      for (final sms in transactionSms) {
        try {
          final smsHash = _smsHash(sms.body, sms.timestamp);
          if (processedHashes.contains(smsHash)) {
            continue;
          }

          // Use the intelligent parser for import; falls back gracefully
          final wasImported = await _importSmsParsed(db, sms);
          if (wasImported) {
            imported++;
            processedHashes.add(smsHash);
            processedHashesDirty = true;
          }
        } catch (e, st) {
          // KEY FIX: Catch error per-SMS so one crash doesn't kill the batch
          debugPrint('PayTrace SMS Sync: FAILED TO IMPORT INDIVIDUAL SMS: $e\n$st');
        }
      }

      if (processedHashesDirty) {
        await _saveProcessedSmsHashes(processedHashes);
      }

      // 5. Save the sync timestamp
      await _saveLastSyncTime(DateTime.now());
      debugPrint('PayTrace SMS Sync: Imported $imported new transactions');
      return imported;
    } catch (e) {
      debugPrint('PayTrace SMS Sync: CRITICAL SERVICE ERROR — $e');
      return 0;
    }
  }

  /// Validate that an SMS is a real UPI transaction (not junk).
  static bool _isValidTransactionSms(BankSms sms) {
    // Must be a debit or credit transaction
    if (!SmsService.isUpiTransactionSms(sms)) return false;

    final lower = sms.body.toLowerCase();

    // ── Reject non-transaction SMS ──

    // OTP / verification codes
    if (lower.contains('otp') ||
        lower.contains('one time password') ||
        lower.contains('verification code')) {
      return false;
    }

    // Promotional / marketing (Only block banks if it's purely an offer with no CR/DR action)
    if (lower.contains('offer') ||
        lower.contains('cashback') ||
        lower.contains('congratulations') ||
        lower.contains('win ') ||
        lower.contains('discount') ||
        lower.contains('coupon')) {
      
      // If it's a bank and contains 'debited' or 'credited', it's a REAL transaction (e.g. cashback)
      final isBankSender = SmsService.isWhitelistedSender(sms.sender);
      if (isBankSender && (lower.contains('debited') || lower.contains('credited'))) {
         // Keep it
      } else {
        return false;
      }
    }

    // Subscription / plan / renewal notifications (OTT, telecom, etc.)
    if (lower.contains('subscription') ||
        lower.contains('renew') ||
        lower.contains('plan activated') ||
        lower.contains('plan expires') ||
        lower.contains('membership')) {
      // Allow if it's clearly a bank debit/credit for the subscription
      if (!lower.contains('debited') &&
          !lower.contains('credited') &&
          !lower.contains('a/c') &&
          !lower.contains('upi')) {
        return false;
      }
    }

    // Known non-financial service names in SMS body
    final nonFinancialServices = [
      'hotstar', 'netflix', 'spotify', 'jiocinema', 'zee5',
      'sonyliv', 'amazon prime', 'youtube premium', 'disney+',
      'wynk', 'gaana',
    ];
    for (final svc in nonFinancialServices) {
      if (lower.contains(svc)) {
        // Only block if SMS lacks strong bank debit/credit language
        if (!lower.contains('debited') &&
            !lower.contains('credited') &&
            !lower.contains('a/c')) {
          return false;
        }
      }
    }

    // Balance check / mini statement
    if (lower.contains('available bal') ||
        lower.contains('avl bal') ||
        lower.contains('avail.bal') ||
        lower.contains('mini statement') ||
        lower.contains('balance is rs') ||
        lower.contains('balance:')) {
      // Balance SMS that also mentions a transaction are OK
      if (!lower.contains('debited') &&
          !lower.contains('credited') &&
          !lower.contains('transferred') &&
          !lower.contains('received')) {
        return false;
      }
    }

    // EMI / loan reminders
    if (lower.contains('emi due') ||
        lower.contains('loan repayment') ||
        lower.contains('pay your emi')) {
      return false;
    }

    // Credit card bill alerts (not actual transactions)
    if (lower.contains('credit card') &&
        (lower.contains('bill') || lower.contains('due'))) {
      return false;
    }

    // Card inactivity alerts (Canara Bank: "Debit Card ending 9001 has not been used")
    if (lower.contains('card') &&
        (lower.contains('not been used') ||
         lower.contains('inactive') ||
         lower.contains('keep it active') ||
         lower.contains('inactiv'))) {
      return false;
    }

    return true;
  }

  /// Import a single SMS as a transaction (with multi-layer dedup).
  /// Legacy import path — kept as fallback for edge cases where the
  /// intelligent parser may be too aggressive. Called by [_importSmsParsed]
  /// when needed.
  // ignore: unused_element
  static Future<bool> _importSms(AppDatabase db, BankSms sms) async {
    try {
      final direction = sms.isCredit ? 'CREDIT' : 'DEBIT';

      // ═══ LAYER 1: UPI ref number match ═══
      if (sms.refNumber != null && sms.refNumber!.isNotEmpty) {
        final existing = await db.findTransactionByRef(sms.refNumber!);
        if (existing != null) {
          debugPrint('PayTrace SMS Sync: SKIP [ref] ref=${sms.refNumber}');
          return false;
        }
      }

      // ═══ LAYER 2: DEBIT amount + time match ═══
      // For debits, check if ANY transaction (app-tracked or SMS) exists
      // with the same amount in a ±5 min window. This catches the main
      // duplicate problem: app tracks "₹500 to merchant@ybl" while SMS
      // says "₹500 debited from A/c XX1234" — different payee, same txn.
      if (!sms.isCredit) {
        final isDup = await db.isDuplicateDebit(
          amount: sms.amount!,
          timestamp: sms.timestamp,
        );
        if (isDup) {
          debugPrint('PayTrace SMS Sync: SKIP [debit-dup] ₹${sms.amount} at ${sms.timestamp}');
          return false;
        }
      }

      // ═══ LAYER 3: SMS reimport guard ═══
      // Prevents the same SMS from creating a duplicate across multiple syncs.
      final legacyPayeeUpiId = _extractUpiId(sms.body) ?? 'sms::${_sanitizeSender(sms.sender)}';
      final isSmsReimport = await db.isDuplicateSmsImport(
        amount: sms.amount!,
        direction: direction,
        timestamp: sms.timestamp,
        payeeUpiId: legacyPayeeUpiId,
      );
      if (isSmsReimport) {
        debugPrint('PayTrace SMS Sync: SKIP [reimport] $direction ₹${sms.amount}');
        return false;
      }

      // ═══ Resolve payee info ═══
      // Bug fix: prefix synthetic IDs with 'sms::' — never bare bank sender
      final payeeUpiId = _extractUpiId(sms.body) ??
          'sms::${_sanitizeSender(sms.sender)}';
      final payeeName = await _resolvePayeeName(db, sms, payeeUpiId);

      // Build stable merchantKey FIRST — needed for category lookup
      final bankName = RegexPatternLibrary.detectBankFromSender(sms.sender);
      final mKey = MerchantIdentity.buildKey(
        upiId: payeeUpiId,
        payeeName: payeeName,
        accountHint: sms.accountHint,
        bankName: bankName,
      );

      // ═══ Auto-categorize ═══
      final category = sms.isCredit
          ? 'Income'
          : await MerchantLearningService.categorize(
              db,
              payeeName: payeeName,
              upiId: payeeUpiId,
              merchantKey: mKey,
            );

      // ═══ Insert transaction ═══
      final id = _uuid.v4();
      final note = _extractTransactionNote(sms);

      await db.insertTransaction(TransactionsCompanion(
        id: Value(id),
        payeeUpiId: Value(payeeUpiId),
        payeeName: Value(payeeName),
        amount: Value(sms.amount!),
        transactionRef: Value(sms.refNumber ?? 'SMS_${sms.timestamp.millisecondsSinceEpoch}'),
        approvalRefNo: Value(sms.refNumber),
        status: const Value('SUCCESS'),
        paymentMode: const Value('SMS_IMPORT'),
        category: Value(category),
        direction: Value(direction),
        merchantKey: Value(mKey),
        transactionNote: Value(note),
        createdAt: Value(sms.timestamp),
        updatedAt: Value(DateTime.now()),
      ));

      // ═══ Upsert payee ═══
      await _upsertPayee(db, payeeUpiId, payeeName, sms.timestamp);

      debugPrint(
        'PayTrace SMS Sync: IMPORTED $direction ₹${sms.amount} '
        '${sms.isCredit ? "from" : "to"} $payeeName [mKey=$mKey]',
      );
      return true;
    } catch (e) {
      debugPrint('PayTrace SMS Sync: Error importing — $e');
      return false;
    }
  }

  /// Resolve the best payee/payer name from SMS.
  /// Priority order (fixed):
  ///   1. SMS-extracted name — most specific to this individual transaction
  ///   2. Existing payee in DB (user may have manually edited it)
  ///      skipped if it's a bank name / 'Unknown' / app label
  ///   3. Contact lookup — ONLY for phone-number VPAs
  ///   4. UPI ID local-part → readable name (alpha only)
  ///   5. Cleaned bank sender
  static Future<String> _resolvePayeeName(
    AppDatabase db,
    BankSms sms,
    String payeeUpiId,
  ) async {
    // 1. SMS-extracted merchant/person name (most specific for this txn)
    if (sms.payeeName != null &&
        sms.payeeName!.isNotEmpty &&
        !_bankNames.contains(sms.payeeName!)) {
      debugPrint('PayTrace SMS Sync: Name from SMS → ${sms.payeeName}');
      return sms.payeeName!;
    }

    // 2. Existing payee in DB — but skip bank names and generic values
    final existingPayee = await db.getPayeeByUpiId(payeeUpiId);
    if (existingPayee != null && existingPayee.name.isNotEmpty) {
      if (!_bankNames.contains(existingPayee.name) &&
          existingPayee.name != 'Unknown' &&
          !existingPayee.name.startsWith('Payment via ')) {
        debugPrint('PayTrace SMS Sync: Name from DB → ${existingPayee.name}');
        return existingPayee.name;
      }
    }

    // 3. Contact lookup — ONLY for phone-number VPAs (9876543210@ybl)
    final localPart = payeeUpiId.contains('@')
        ? payeeUpiId.split('@').first
        : payeeUpiId;
    final isPhoneVpa = RegExp(r'^\d{8,}$').hasMatch(localPart);
    if (isPhoneVpa) {
      final contactName = await ContactLookupService.lookupFromUpiId(payeeUpiId);
      if (contactName != null && contactName.isNotEmpty) {
        debugPrint('PayTrace SMS Sync: Name from CONTACTS → $contactName');
        return contactName;
      }
    }

    // 4. UPI ID → readable name (alpha local-part only)
    final upiId = _extractUpiId(sms.body);
    if (upiId != null) {
      final lp = upiId.split('@').first;
      if (RegExp(r'[a-zA-Z]').hasMatch(lp)) {
        final name = lp
            .replaceAll(RegExp(r'[._-]'), ' ')
            .split(' ')
            .map((w) =>
                w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
            .join(' ');
        if (name.length >= 2) return name;
      }
    }

    // 5. Fall back to cleaned bank sender
    return _sanitizeSender(sms.sender);
  }

  /// Known bank names — skip reusing these from payee DB
  static const _bankNames = {
    'SBI', 'HDFC Bank', 'ICICI Bank', 'Axis Bank', 'Kotak Bank',
    'PNB', 'Bank of India', 'Canara Bank', 'UCO Bank', 'IOB',
    'Bank of Baroda', 'Indian Bank', 'Federal Bank', 'Yes Bank',
    'IDFC First', 'Paytm',
  };

  /// Clean bank sender names like "BK-SBIINB" -> "SBI"
  static String _sanitizeSender(String sender) {
    // Remove common prefixes like "BK-", "AD-", "VM-", "VD-", etc.
    var clean = sender.replaceAll(RegExp(r'^[A-Z]{2}-'), '');

    // Map common bank codes to readable names
    const bankMap = {
      'SBIINB': 'SBI',
      'SBINOB': 'SBI',
      'SBISMS': 'SBI',
      'SBIBNK': 'SBI',
      'HDFCBK': 'HDFC Bank',
      'HDFCBN': 'HDFC Bank',
      'ICICIB': 'ICICI Bank',
      'ICICBK': 'ICICI Bank',
      'AXISBK': 'Axis Bank',
      'AXSBNK': 'Axis Bank',
      'KOTAKB': 'Kotak Bank',
      'KOTKBK': 'Kotak Bank',
      'PNBSMS': 'PNB',
      'PNBBNK': 'PNB',
      'BOIIND': 'Bank of India',
      'BOISTR': 'Bank of India',
      'CANBNK': 'Canara Bank',
      'CNRBNK': 'Canara Bank',
      'UCOBNK': 'UCO Bank',
      'IOBCHN': 'IOB',
      'IABORB': 'IOB',
      'IOBBNK': 'IOB',
      'BOBSMS': 'Bank of Baroda',
      'BARBOD': 'Bank of Baroda',
      'INDBNK': 'Indian Bank',
      'INDBKS': 'Indian Bank',
      'FEDBKN': 'Federal Bank',
      'FEDBNK': 'Federal Bank',
      'YESBNK': 'Yes Bank',
      'YESBKN': 'Yes Bank',
      'IDFCFB': 'IDFC First',
      'IDFCBK': 'IDFC First',
      'UBINBK': 'Union Bank',
      'UNIONB': 'Union Bank',
      'CENTBK': 'Central Bank',
      'MAHABK': 'Bank of Maharashtra',
      'RBLBNK': 'RBL Bank',
      'BANDHN': 'Bandhan Bank',
      'INDUSB': 'IndusInd Bank',
      'PAYTMB': 'Paytm',
    };

    if (bankMap.containsKey(clean)) return bankMap[clean]!;
    return clean;
  }

  /// Extract a clean transaction note from SMS body.
  /// Stores key info without the full raw dump.
  static String? _extractTransactionNote(BankSms sms) {
    final body = sms.body;

    // Try to extract "to PERSON" or "from PERSON" snippet
    final toMatch = RegExp(r'(?:to|from|by)\s+([A-Za-z0-9@._\s]{2,30})',
            caseSensitive: false)
        .firstMatch(body);

    if (toMatch != null) {
      final snippet = toMatch.group(0)?.trim();
      if (snippet != null && snippet.length <= 50) return snippet;
    }

    // Fallback: first 60 chars of SMS
    return body.length > 60 ? '${body.substring(0, 60)}...' : body;
  }

  /// Extract UPI ID from SMS body.
  static String? _extractUpiId(String text) {
    // ── Priority 1: Extract VPA from Info: field ──
    // "Info: UPI/P2P/412345678901/JOHN DOE/person@ybl/SBI"
    // "Info: UPI/DR/412345678901/person@ybl/SBI"
    final infoPattern = RegExp(
      r'(?:Info|info)\s*:?.*?([a-zA-Z0-9._-]+@(?:ybl|upi|apl|okhdfcbank|okicici|oksbi|okaxis|paytm|fbl|ibl|axl|sbi|waicici|wahdfcbank|barodampay|unionbankofindia|kotak|indus|federal|csbpay|dbs|rbl|allbank|aubank|equitas|idfcbank|hsbc|bandhan|jupiteraxis)[a-z]*)',
      caseSensitive: false,
    );
    final infoMatch = infoPattern.firstMatch(text);
    if (infoMatch != null) return infoMatch.group(1);

    // ── Priority 2: UPI slash-separated format anywhere in text ──
    // "UPI/P2P/412345678901/person@ybl" or "UPI/DR/ref/person@bank"
    final slashPattern = RegExp(
      r'UPI/[A-Za-z0-9]+/\d+/(?:[^/]+/)?([a-zA-Z0-9._-]+@[a-zA-Z]{3,})',
      caseSensitive: false,
    );
    final slashMatch = slashPattern.firstMatch(text);
    if (slashMatch != null) {
      final candidate = slashMatch.group(1)!;
      if (!candidate.contains('.com') && !candidate.contains('.in')) {
        return candidate;
      }
    }

    // ── Priority 3: Known bank VPA handles ──
    final pattern = RegExp(r'\b([a-zA-Z0-9._-]+@(?:ybl|upi|apl|okhdfcbank|okicici|oksbi|okaxis|paytm|fbl|ibl|axl|sbi|waicici|wahdfcbank|barodampay|unionbankofindia|kotak|indus|federal|csbpay|dbs|rbl|allbank|aubank|equitas|idfcbank|hsbc|bandhan|jupiteraxis)[a-z]*)');
    final match = pattern.firstMatch(text);
    if (match != null) return match.group(1);

    // ── Priority 4: Broader UPI pattern (3+ char handle) ──
    final broad = RegExp(r'\b([a-zA-Z0-9._-]+@[a-zA-Z]{3,})\b');
    final broadMatch = broad.firstMatch(text);
    if (broadMatch != null) {
      final candidate = broadMatch.group(1)!;
      // Exclude email-like addresses
      if (!candidate.contains('.com') &&
          !candidate.contains('.in') &&
          !candidate.contains('.org') &&
          !candidate.contains('.net')) {
        return candidate;
      }
    }

    return null;
  }

  /// Upsert payee record.
  /// On insert: sets name, UPI ID, phone (if extractable).
  /// On update: upgrades name if the existing one is a bank code, and sets
  ///            phone if it was previously missing.
  static Future<void> _upsertPayee(
    AppDatabase db,
    String payeeUpiId,
    String payeeName,
    DateTime timestamp,
  ) async {
    // Extract phone number from UPI ID (may be null for merchant VPAs)
    final phone = ContactLookupService.extractPhoneNumber(payeeUpiId);

    final existing = await db.getPayeeByUpiId(payeeUpiId);
    if (existing != null) {
      // Always increment count and update last-paid
      await db.incrementPayeeCount(existing.id);

      // Upgrade name only if the existing name is a bank code / generic label.
      // Do NOT upgrade a real person/merchant name with a shorter or generic value.
      final existingIsBankName = _bankNames.contains(existing.name);
      final existingIsSynthetic = existing.name.startsWith('sms::') ||
          existing.name.startsWith('notif::') ||
          existing.name.startsWith('unknown::') ||
          existing.name.length <= 4;
      final newIsReal = !_bankNames.contains(payeeName) &&
          payeeName != payeeUpiId &&
          payeeName.isNotEmpty &&
          !payeeName.startsWith('sms::') &&
          !payeeName.startsWith('notif::');

      if ((existingIsBankName || existingIsSynthetic) && newIsReal) {
        await db.updatePayeeName(existing.id, payeeName);
        debugPrint(
          'PayTrace SMS Sync: Upgraded payee name "${existing.name}" → "$payeeName"',
        );
      }

      // Set phone if previously missing
      if (phone != null && (existing.phone == null || existing.phone!.isEmpty)) {
        await db.updatePayeePhone(existing.id, phone);
      }
    } else {
      await db.upsertPayee(PayeesCompanion(
        id: Value(_uuid.v4()),
        upiId: Value(payeeUpiId),
        name: Value(payeeName),
        phone: phone != null ? Value(phone) : const Value.absent(),
        transactionCount: const Value(1),
        lastPaidAt: Value(timestamp),
      ));
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  INTELLIGENT PARSER IMPORT
  // ═══════════════════════════════════════════════════════════

  /// Import a single SMS using the intelligent [SmsTransactionParser].
  ///
  /// This provides richer categorization and confidence scoring
  /// compared to the legacy [_importSms] flow. Falls back to
  /// [_importSms] if the parser rejects the message but legacy
  /// heuristics accept it (belt-and-suspenders).
  static Future<bool> _importSmsParsed(AppDatabase db, BankSms sms) async {
    final parsed = SmsTransactionParser.parse(
      body: sms.body,
      sender: sms.sender,
      timestamp: sms.timestamp,
    );

    if (parsed == null) {
      // Parser rejected — skip (don't fall back to legacy to avoid
      // false positives that the parser was designed to eliminate).
      debugPrint(
        'PayTrace SMS Sync: Parser REJECTED SMS from ${sms.sender}',
      );
      return false;
    }

    // Low-confidence results: still import but log for review.
    if (parsed.confidence < 0.5) {
      debugPrint(
        'PayTrace SMS Sync: LOW confidence '
        '(${(parsed.confidence * 100).toStringAsFixed(0)}%) '
        'for ₹${parsed.amount} ${parsed.type}',
      );
    }

    try {
      final direction = parsed.isIncome ? 'CREDIT' : 'DEBIT';

      // ═══ Dedup — same 3 layers as legacy ═══
      if (parsed.upiRef != null && parsed.upiRef!.isNotEmpty) {
        final existing = await db.findTransactionByRef(parsed.upiRef!);
        if (existing != null) {
          debugPrint('PayTrace SMS Sync: SKIP [ref] ref=${parsed.upiRef}');
          return false;
        }
      }

      if (parsed.isExpense) {
        final isDup = await db.isDuplicateDebit(
          amount: parsed.amount,
          timestamp: parsed.timestamp,
        );
        if (isDup) {
          debugPrint(
            'PayTrace SMS Sync: SKIP [debit-dup] '
            '₹${parsed.amount} at ${parsed.timestamp}',
          );
          return false;
        }
      }

      // Resolve payeeUpiId early so the dedup check can use it.
      final payeeUpiId =
          parsed.upiId ?? _extractUpiId(sms.body) ?? _sanitizeSender(sms.sender);

      // Use the parser-extracted merchant name as the primary name source.
      // _resolvePayeeName may upgrade it via contacts/DB if available.
      final parsedMerchant = parsed.merchant;
      // Override sms.payeeName with the parser-extracted merchant so
      // _resolvePayeeName prioritises SMS-extracted names correctly.
      final smsWithMerchant = BankSms(
        sender: sms.sender,
        body: sms.body,
        timestamp: sms.timestamp,
        amount: sms.amount,
        refNumber: sms.refNumber,
        accountHint: sms.accountHint,
        isCredit: sms.isCredit,
        payeeName: parsedMerchant.isNotEmpty ? parsedMerchant : sms.payeeName,
      );
      final payeeName = await _resolvePayeeName(db, smsWithMerchant, payeeUpiId);

      // Build stable merchantKey BEFORE insert and category lookup.
      final bankName = RegexPatternLibrary.detectBankFromSender(sms.sender);
      final mKey = MerchantIdentity.buildKey(
        upiId: payeeUpiId,
        payeeName: payeeName,
        accountHint: sms.accountHint,
        bankName: bankName,
      );

      // Use the merchant key for category lookup so learned categories apply.
      final category = parsed.category == 'Income'
          ? 'Income'
          : await MerchantLearningService.categorize(
              db,
              payeeName: payeeName,
              upiId: payeeUpiId,
              merchantKey: mKey,
            );

      // ─── SMS PRIORITY OVERRIDE ───
      // Before checking for standard SMS duplicates, check if the real-time NotificationListener
      // caught this payment first. If so, OVERWRITE it with this high-fidelity SMS data.
      final matchingNotifId = await db.findMatchingNotificationImport(
        amount: parsed.amount,
        direction: direction,
        timestamp: parsed.timestamp,
      );

      if (matchingNotifId != null) {
        await db.upgradeTransactionFromSms(
          transactionId: matchingNotifId,
          payeeUpiId: payeeUpiId,
          payeeName: payeeName,
          merchantKey: mKey,
          category: category,
        );
        debugPrint(
          'PayTrace SMS Sync: UPGRADED Notification ID $matchingNotifId '
          'with SMS data: $direction ₹${parsed.amount} → $payeeName',
        );
        return true; // We successfully handled this SMS.
      }

      final isSmsReimport = await db.isDuplicateSmsImport(
        amount: parsed.amount,
        direction: direction,
        timestamp: parsed.timestamp,
        payeeUpiId: payeeUpiId,
      );
      if (isSmsReimport) {
        debugPrint(
          'PayTrace SMS Sync: SKIP [reimport] '
          '$direction ₹${parsed.amount}',
        );
        return false;
      }

      final id = _uuid.v4();
      final note = _extractTransactionNote(sms);

      await db.insertTransaction(TransactionsCompanion(
        id: Value(id),
        payeeUpiId: Value(payeeUpiId),
        payeeName: Value(payeeName),
        amount: Value(parsed.amount),
        transactionRef: Value(
          parsed.upiRef ??
              'SMS_${sms.timestamp.millisecondsSinceEpoch}',
        ),
        approvalRefNo: Value(parsed.upiRef),
        status: const Value('SUCCESS'),
        paymentMode: const Value('SMS_IMPORT'),
        category: Value(category),
        direction: Value(direction),
        merchantKey: Value(mKey),   // ← was missing; fixes rename-all + category batch-update
        transactionNote: Value(note),
        createdAt: Value(parsed.timestamp),
        updatedAt: Value(DateTime.now()),
      ));

      await _upsertPayee(db, payeeUpiId, payeeName, parsed.timestamp);

      debugPrint(
        'PayTrace SMS Sync: IMPORTED (parser) $direction '
        '₹${parsed.amount} ${parsed.isIncome ? "from" : "to"} '
        '$payeeName [${parsed.category}] mKey=$mKey '
        'confidence=${(parsed.confidence * 100).toStringAsFixed(0)}%',
      );
      return true;
    } catch (e) {
      debugPrint('PayTrace SMS Sync: Parser import error — $e');
      return false;
    }
  }

  /// Get the last sync timestamp from secure storage.
  static Future<DateTime> _getLastSyncTime() async {
    try {
      final stored = await _storage.read(key: _lastSyncKey);
      if (stored != null) {
        final ms = int.tryParse(stored);
        if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
      }
    } catch (_) {}
    return DateTime.now().subtract(const Duration(days: 90));
  }

  /// Save the last sync timestamp.
  static Future<void> _saveLastSyncTime(DateTime time) async {
    await _storage.write(
      key: _lastSyncKey,
      value: time.millisecondsSinceEpoch.toString(),
    );
  }

  static Future<LinkedHashSet<String>> _loadProcessedSmsHashes() async {
    try {
      final raw = await _storage.read(key: _processedHashesKey);
      if (raw == null || raw.isEmpty) return LinkedHashSet<String>();
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return LinkedHashSet<String>.from(
          decoded.whereType<String>(),
        );
      }
    } catch (_) {}
    return LinkedHashSet<String>();
  }

  static Future<void> _saveProcessedSmsHashes(LinkedHashSet<String> hashes) async {
    while (hashes.length > _maxStoredHashes) {
      hashes.remove(hashes.first);
    }

    await _storage.write(
      key: _processedHashesKey,
      value: jsonEncode(hashes.toList(growable: false)),
    );
  }

  static String _smsHash(String body, DateTime timestamp) {
    final payload =
        '${timestamp.millisecondsSinceEpoch}|${body.trim().toLowerCase()}';
    return sha1.convert(utf8.encode(payload)).toString();
  }
}
