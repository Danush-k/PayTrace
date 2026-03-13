import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../core/utils/sms_transaction_parser.dart';
import '../data/database/app_database.dart';
import 'contact_lookup_service.dart';
import 'merchant_learning_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  HISTORICAL SMS SCANNER SERVICE
//
//  Performs a one-shot full scan of the last 90 days of SMS messages
//  from both the inbox and sent folders.
//
//  Pipeline:
//    1. Fetch raw SMS from Android ContentResolver (both URIs)
//    2. TransactionFilter — three explicit gates:
//         Gate 1  Currency symbol or keyword is present (₹ / Rs / INR)
//         Gate 2  At least one transaction keyword present
//                 (debited / credited / sent / received / UPI /
//                  txn / IMPS / NEFT / RTGS)
//         Gate 3  No promotional keywords
//                 (offer / discount / cashback / coupon / sale)
//    3. SmsTransactionParser — structured extraction:
//         amount · merchant · type · timestamp · reference number
//    4. Three-layer dedup (ref → debit-window → reimport-guard)
//    5. Store to AppDatabase with payee upsert
//
//  Progress is reported via an [onProgress] callback so the UI can
//  display "Scanning messages…" / "Detecting transactions…" /
//  "Analyzing spending patterns…" in the right order.
// ═══════════════════════════════════════════════════════════════════════════

// ── Progress model ──────────────────────────────────────────────────────────

/// Coarse phase of the scan passed to the UI.
enum ScanPhase {
  /// Fetching raw bytes from the SMS content provider.
  fetching,

  /// Running the [TransactionFilter] over each message.
  filtering,

  /// Running [SmsTransactionParser] to extract structured fields.
  parsing,

  /// Writing accepted records to the database.
  storing,

  /// Scan is complete.
  done,
}

/// Snapshot of scan state delivered via the [onProgress] callback.
class ScanProgress {
  const ScanProgress({
    required this.phase,
    this.total = 0,
    this.filtered = 0,
    this.parsed = 0,
    this.imported = 0,
  });

  final ScanPhase phase;

  /// Total raw SMS fetched from the device.
  final int total;

  /// Messages that passed the [TransactionFilter].
  final int filtered;

  /// Messages successfully parsed by [SmsTransactionParser].
  final int parsed;

  /// Unique transactions written to the database.
  final int imported;

  @override
  String toString() =>
      'ScanProgress(${phase.name} total=$total filtered=$filtered '
      'parsed=$parsed imported=$imported)';
}

/// Final summary returned by [HistoricalSmsScannerService.scanHistorical].
class HistoricalScanResult {
  const HistoricalScanResult({
    required this.totalSms,
    required this.filteredSms,
    required this.parsedSms,
    required this.imported,
    required this.skipped,
    required this.durationMs,
  });

  /// Raw SMS messages fetched from the device.
  final int totalSms;

  /// Messages that passed all [TransactionFilter] gates.
  final int filteredSms;

  /// Messages successfully decoded by [SmsTransactionParser].
  final int parsedSms;

  /// Unique transactions written to the database.
  final int imported;

  /// Transactions rejected by the dedup layers.
  final int skipped;

  /// Wall-clock time the scan took (milliseconds).
  final int durationMs;

  @override
  String toString() =>
      'HistoricalScanResult(total=$totalSms filtered=$filteredSms '
      'parsed=$parsedSms imported=$imported skipped=$skipped '
      'duration=${durationMs}ms)';
}

// ── Transaction filter ───────────────────────────────────────────────────────

/// Explicit three-gate filter for financial SMS messages.
///
/// | Gate | Rule                                            |
/// |------|-------------------------------------------------|
/// | 1    | Message contains a **currency** symbol/keyword  |
/// | 2    | Message contains a **transaction** keyword      |
/// | 3    | Message does NOT contain a **promo** keyword    |
///
/// Any extra promotional content that also has strong banking language
/// (debited/credited + a/c reference) is allowed through Gate 3 so
/// that real bank alerts with footer marketing text are not rejected.
class TransactionFilter {
  TransactionFilter._();

  // ── Gate 1: Currency ─────────────────────────────────────────────────────

  /// Symbols / token matches that indicate a monetary value is present.
  static const _currencyPatterns = [
    '₹',
    'rs.',
    'rs ',
    'inr',
  ];

  static bool _hasCurrency(String lower) {
    for (final token in _currencyPatterns) {
      if (lower.contains(token)) return true;
    }
    return false;
  }

  // ── Gate 2: Transaction keyword ──────────────────────────────────────────

  /// Keywords whose presence indicates an actual financial transaction.
  /// These map directly to the requirements specification.
  static const _transactionKeywords = <String>[
    'debited',
    'credited',
    'sent',
    'received',
    'upi',
    'txn',
    'imps',
    'neft',
    'rtgs',
    'transferred',
    'withdrawn',
    'deposited',
    'purchase',
    'paid',
    'spent',
  ];

  static bool _hasTransactionKeyword(String lower) {
    for (final kw in _transactionKeywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }

  // ── Gate 3: Promotional rejection ────────────────────────────────────────

  /// Keywords whose presence marks a message as promotional/marketing.
  /// Directly from the requirements specification plus common additions.
  static const _promoKeywords = <String>[
    'offer',
    'discount',
    'cashback',
    'coupon',
    'sale',
    'win ',
    'winner',
    'reward',
    'congrat',
    'earn ',
    'free ',
    'gift',
    'voucher',
    'lucky',
    'claim ',
    'bonus',
    'limited time',
    'valid till',
  ];

  /// Returns `true` when the message contains promotional keywords.
  ///
  /// **Override**: if the same message has *strong* banking language
  /// (debited/credited + an account reference), it is treated as a
  /// real bank alert that happens to have a marketing footer.
  static bool _isPromotional(String lower) {
    final hasPromo = _promoKeywords.any((kw) => lower.contains(kw));
    if (!hasPromo) return false;

    // Strong banking override — real transaction with promo footer
    final hasStrongBank =
        (lower.contains('debited') || lower.contains('credited')) &&
            (lower.contains('a/c') ||
                lower.contains('acct') ||
                lower.contains('account'));
    if (hasStrongBank) return false; // let through

    return true;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Run all three gates.  Returns `true` if the message should be
  /// forwarded to [SmsTransactionParser].
  ///
  /// Rejection reason is returned via [reason] for diagnostics.
  static bool accept(String body, {String? outReason}) {
    final lower = body.toLowerCase();

    if (!_hasCurrency(lower)) {
      debugPrint('TransactionFilter: REJECT [no-currency]');
      return false;
    }

    if (!_hasTransactionKeyword(lower)) {
      debugPrint('TransactionFilter: REJECT [no-txn-keyword]');
      return false;
    }

    if (_isPromotional(lower)) {
      debugPrint('TransactionFilter: REJECT [promo]');
      return false;
    }

    return true;
  }
}

// ── Main service ─────────────────────────────────────────────────────────────

/// Service that orchestrates the full historical SMS scan pipeline.
///
/// Call [scanHistorical] once after onboarding permissions are granted.
/// For incremental, everyday syncs use `SmsSyncService.sync()` instead.
class HistoricalSmsScannerService {
  HistoricalSmsScannerService._();

  // ── Constants ──────────────────────────────────────────────────────────────

  static const _channel = MethodChannel('com.paytrace.paytrace/upi');
  static const _storage = FlutterSecureStorage();
  static const _processedHashesKey = 'hist_sms_processed_hashes_v1';
  static const _maxStoredHashes = 6000;
  static const _uuid = Uuid();

  /// Hard 90-day scan window — always the full history.
  static const _scanWindow = Duration(days: 90);

  // ── Public entry point ────────────────────────────────────────────────────

  /// Scan the last 90 days of inbox + sent SMS, filter, parse, and store.
  ///
  /// [onProgress] is called at key milestones so the UI can update its
  /// loading message in real-time.
  ///
  /// Returns a [HistoricalScanResult] with detailed statistics.
  static Future<HistoricalScanResult> scanHistorical(
    AppDatabase db, {
    void Function(ScanProgress)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    debugPrint('HistoricalSMS: ── Starting 90-day historical scan ──');
    _reportProgress(onProgress, const ScanProgress(phase: ScanPhase.fetching));

    // ── 1. Pre-load device contacts for name resolution ──────────────────
    await ContactLookupService.preloadContacts();

    // ── 2. Fetch raw SMS from both inbox + sent ───────────────────────────
    final sinceMs =
        DateTime.now().subtract(_scanWindow).millisecondsSinceEpoch;

    List<Map<String, String>> rawList = [];
    try {
      final result =
          await _channel.invokeMethod<List<dynamic>>('readRecentSms', {
        'since': sinceMs,
      });
      if (result != null) {
        rawList =
            result.map((e) => Map<String, String>.from(e as Map)).toList();
      }
    } on PlatformException catch (e) {
      debugPrint('HistoricalSMS: Platform error fetching SMS — ${e.message}');
    }

    final totalSms = rawList.length;
    debugPrint('HistoricalSMS: Fetched $totalSms raw SMS in ${_scanWindow.inDays} days');

    _reportProgress(
      onProgress,
      ScanProgress(phase: ScanPhase.filtering, total: totalSms),
    );

    // ── 3. TransactionFilter ─────────────────────────────────────────────
    final filtered = rawList.where((msg) {
      final body = msg['body'] ?? '';
      return body.isNotEmpty && TransactionFilter.accept(body);
    }).toList();

    final filteredCount = filtered.length;
    debugPrint('HistoricalSMS: $filteredCount SMS passed TransactionFilter');

    _reportProgress(
      onProgress,
      ScanProgress(
        phase: ScanPhase.parsing,
        total: totalSms,
        filtered: filteredCount,
      ),
    );

    // ── 4. SmsTransactionParser — structured extraction ───────────────────
    final processedHashes = await _loadProcessedHashes();
    var hashesDirty = false;

    int imported = 0;
    int skipped = 0;

    for (final msg in filtered) {
      final body = msg['body'] ?? '';
      final sender = msg['sender'] ?? '';
      final timestampStr = msg['timestamp'] ?? '0';
      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(timestampStr) ?? 0,
      );

      // Hash-based batch dedup — prevents importing the same SMS twice
      // when scanHistorical is called more than once.
      final hash = _smsHash(body, timestamp);
      if (processedHashes.contains(hash)) {
        skipped++;
        continue;
      }

      // Run through intelligent parser (amount + merchant + type + ref)
      final parsed = SmsTransactionParser.parse(
        body: body,
        sender: sender,
        timestamp: timestamp,
      );

      if (parsed == null) {
        // Parser rejected — confidence too low or missing fields.
        debugPrint('HistoricalSMS: Parser REJECTED from $sender');
        skipped++;
        continue;
      }

      _reportProgress(
        onProgress,
        ScanProgress(
          phase: ScanPhase.storing,
          total: totalSms,
          filtered: filteredCount,
          parsed: imported + skipped,
          imported: imported,
        ),
      );

      // ── 5. Three-layer dedup ──────────────────────────────────────────
      final direction = parsed.isIncome ? 'CREDIT' : 'DEBIT';

      // Layer 1 — UPI reference match (strongest)
      if (parsed.upiRef != null && parsed.upiRef!.isNotEmpty) {
        final existing = await db.findTransactionByRef(parsed.upiRef!);
        if (existing != null) {
          debugPrint(
              'HistoricalSMS: SKIP [ref] ref=${parsed.upiRef}');
          skipped++;
          continue;
        }
      }

      // Layer 2 — DEBIT: same amount ± 5 min window
      if (parsed.isExpense) {
        final isDup = await db.isDuplicateDebit(
          amount: parsed.amount,
          timestamp: parsed.timestamp,
        );
        if (isDup) {
          debugPrint(
            'HistoricalSMS: SKIP [debit-dup] ₹${parsed.amount} '
            'at ${parsed.timestamp}',
          );
          skipped++;
          continue;
        }
      }

      // Layer 3 — SMS reimport guard (same amount + direction ± 1 min)
      final isSmsReimport = await db.isDuplicateSmsImport(
        amount: parsed.amount,
        direction: direction,
        timestamp: parsed.timestamp,
      );
      if (isSmsReimport) {
        debugPrint(
          'HistoricalSMS: SKIP [reimport] $direction ₹${parsed.amount}',
        );
        skipped++;
        continue;
      }

      // ── 6. Resolve payee metadata ─────────────────────────────────────
      final payeeUpiId = parsed.upiId ?? _sanitizeSender(sender);
      final payeeName = await _resolvePayeeName(
        db: db,
        parsedMerchant: parsed.merchant,
        payeeUpiId: payeeUpiId,
        sender: sender,
      );

      final category = parsed.isIncome
          ? 'Income'
          : await MerchantLearningService.categorize(
              db,
              payeeName: payeeName,
              upiId: payeeUpiId,
            );

      // ── 7. Insert transaction ─────────────────────────────────────────
      final id = _uuid.v4();
      await db.insertTransaction(TransactionsCompanion(
        id: Value(id),
        payeeUpiId: Value(payeeUpiId),
        payeeName: Value(payeeName),
        amount: Value(parsed.amount),
        transactionRef: Value(
          parsed.upiRef ??
              'SMS_HIST_${timestamp.millisecondsSinceEpoch}',
        ),
        approvalRefNo: Value(parsed.upiRef),
        status: const Value('SUCCESS'),
        paymentMode: const Value('SMS_IMPORT'),
        category: Value(category),
        direction: Value(direction),
        transactionNote: Value(_extractNote(body)),
        createdAt: Value(timestamp),
        updatedAt: Value(DateTime.now()),
      ));

      // ── 8. Upsert payee ───────────────────────────────────────────────
      await _upsertPayee(db, payeeUpiId, payeeName, timestamp);

      // Mark as processed so subsequent scans skip this SMS
      processedHashes.add(hash);
      hashesDirty = true;
      imported++;

      debugPrint(
        'HistoricalSMS: IMPORTED $direction ₹${parsed.amount} → '
        '$payeeName [${parsed.category}]',
      );
    }

    if (hashesDirty) {
      await _saveProcessedHashes(processedHashes);
    }

    stopwatch.stop();
    final result = HistoricalScanResult(
      totalSms: totalSms,
      filteredSms: filteredCount,
      parsedSms: imported + skipped,
      imported: imported,
      skipped: skipped,
      durationMs: stopwatch.elapsedMilliseconds,
    );

    debugPrint('HistoricalSMS: ── Scan complete ── $result');

    _reportProgress(
      onProgress,
      ScanProgress(
        phase: ScanPhase.done,
        total: totalSms,
        filtered: filteredCount,
        parsed: imported + skipped,
        imported: imported,
      ),
    );

    return result;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static void _reportProgress(
    void Function(ScanProgress)? cb,
    ScanProgress progress,
  ) {
    if (cb != null) {
      try {
        cb(progress);
      } catch (_) {}
    }
  }

  /// Resolve the best display name for a payee:
  ///   1. Device contact lookup via UPI ID
  ///   2. Existing payee record in DB
  ///   3. Parser-extracted merchant name
  ///   4. Cleaned sender ID
  static Future<String> _resolvePayeeName({
    required AppDatabase db,
    required String parsedMerchant,
    required String payeeUpiId,
    required String sender,
  }) async {
    // 1. Device contacts (preloaded earlier)
    final contactName =
        await ContactLookupService.lookupFromUpiId(payeeUpiId);
    if (contactName != null && contactName.isNotEmpty) return contactName;

    // 2. Existing payee in DB
    final existingPayee = await db.getPayeeByUpiId(payeeUpiId);
    if (existingPayee != null && existingPayee.name.isNotEmpty) {
      if (!_kBankNames.contains(existingPayee.name)) {
        return existingPayee.name;
      }
    }

    // 3. Parser-extracted merchant name
    if (parsedMerchant.isNotEmpty && !_kBankNames.contains(parsedMerchant)) {
      return parsedMerchant;
    }

    // 4. Fallback: cleaned sender ID
    return _sanitizeSender(sender);
  }

  /// Upsert a payee, upgrading the name if better data is available.
  static Future<void> _upsertPayee(
    AppDatabase db,
    String payeeUpiId,
    String payeeName,
    DateTime timestamp,
  ) async {
    final phone = ContactLookupService.extractPhoneNumber(payeeUpiId);
    final existing = await db.getPayeeByUpiId(payeeUpiId);

    if (existing != null) {
      await db.incrementPayeeCount(existing.id);

      // Upgrade name if the stored one is a generic bank code
      final currentIsBankName = _kBankNames.contains(existing.name);
      if (currentIsBankName && !_kBankNames.contains(payeeName)) {
        await db.updatePayeeName(existing.id, payeeName);
      }
      if (phone != null &&
          (existing.phone == null || existing.phone!.isEmpty)) {
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

  /// Map abbreviated sender IDs to human-readable bank names.
  static String _sanitizeSender(String sender) {
    final clean = sender.replaceAll(RegExp(r'^[A-Z]{2}-'), '');
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
      'BOBSMS': 'Bank of Baroda',
      'BARBOD': 'Bank of Baroda',
      'CANBNK': 'Canara Bank',
      'CNRBNK': 'Canara Bank',
      'INDBNK': 'Indian Bank',
      'INDBKS': 'Indian Bank',
      'IDFCFB': 'IDFC First',
      'IDFCBK': 'IDFC First',
      'IOBCHN': 'IOB',
      'IABORB': 'IOB',
      'IOBBNK': 'IOB',
      'YESBNK': 'Yes Bank',
      'YESBKN': 'Yes Bank',
      'FEDBKN': 'Federal Bank',
      'FEDBNK': 'Federal Bank',
      'UCOBNK': 'UCO Bank',
      'BOIIND': 'Bank of India',
      'BOISTR': 'Bank of India',
      'UBINBK': 'Union Bank',
      'UNIONB': 'Union Bank',
      'CENTBK': 'Central Bank',
      'MAHABK': 'Bank of Maharashtra',
      'RBLBNK': 'RBL Bank',
      'BANDHN': 'Bandhan Bank',
      'INDUSB': 'IndusInd Bank',
      'PAYTMB': 'Paytm',
    };
    return bankMap[clean] ?? clean;
  }

  /// Extract a short human-readable note from the SMS body (≤ 60 chars).
  static String? _extractNote(String body) {
    final match = RegExp(
      r'(?:to|from|by)\s+([A-Za-z0-9@._\s]{2,30})',
      caseSensitive: false,
    ).firstMatch(body);
    if (match != null) {
      final snippet = match.group(0)?.trim();
      if (snippet != null && snippet.length <= 60) return snippet;
    }
    return body.length > 60 ? '${body.substring(0, 60)}…' : body;
  }

  // ── Hash-based processed-SMS ledger ──────────────────────────────────────

  static String _smsHash(String body, DateTime timestamp) {
    final payload =
        '${timestamp.millisecondsSinceEpoch}|${body.trim().toLowerCase()}';
    return sha1.convert(utf8.encode(payload)).toString();
  }

  static Future<LinkedHashSet<String>> _loadProcessedHashes() async {
    try {
      final raw = await _storage.read(key: _processedHashesKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return LinkedHashSet<String>.from(decoded.whereType<String>());
        }
      }
    } catch (_) {}
    return LinkedHashSet<String>();
  }

  static Future<void> _saveProcessedHashes(
      LinkedHashSet<String> hashes) async {
    while (hashes.length > _maxStoredHashes) {
      hashes.remove(hashes.first);
    }
    await _storage.write(
      key: _processedHashesKey,
      value: jsonEncode(hashes.toList(growable: false)),
    );
  }

  // ── Static data ───────────────────────────────────────────────────────────

  static const _kBankNames = {
    'SBI',
    'HDFC Bank',
    'ICICI Bank',
    'Axis Bank',
    'Kotak Bank',
    'PNB',
    'Bank of India',
    'Canara Bank',
    'UCO Bank',
    'IOB',
    'Bank of Baroda',
    'Indian Bank',
    'Federal Bank',
    'Yes Bank',
    'IDFC First',
    'Paytm',
  };
}
