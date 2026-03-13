import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/utils/merchant_identity.dart';
import '../data/database/app_database.dart';
import 'merchant_learning_service.dart';
import 'notification_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  NOTIFICATION PIPELINE
//
//  Sits between NotificationService (stream) and the Drift DB.
//
//  Every PaymentNotification emitted by NotificationService is:
//    1. Checked against a 60-second in-memory dedup cache
//    2. Checked against existing DEBIT records in the DB (±5 min)
//    3. Checked against prior NOTIF_IMPORT records in the DB (±60 s)
//    4. Inserted with paymentMode = 'NOTIF_IMPORT'
//    5. Drift watch-streams auto-emit — UI refreshes without manual invalidation
//
//  Create with [NotificationPipeline.start()] and keep alive
//  via a Riverpod provider (see [notificationPipelineProvider]).
// ═══════════════════════════════════════════════════════════════════════════

const _kPaymentMode = 'NOTIF_IMPORT';

class NotificationPipeline {
  NotificationPipeline._({required AppDatabase db}) : _db = db;

  final AppDatabase _db;
  StreamSubscription<PaymentNotification>? _subscription;

  /// In-memory 60-second dedup cache.
  /// Key: "<amount>::<direction>" (e.g. "250.0::DEBIT")
  /// Value: time of last accepted notification with that key.
  final _dedupMap = <String, DateTime>{};

  static const _uuid = Uuid();

  // ─────────────────────────────────────────────────────────────────────────
  //  Human-readable labels for known UPI apps
  // ─────────────────────────────────────────────────────────────────────────

  static const _upiAppLabels = <String, String>{
    'com.google.android.apps.nbu.paisa.user': 'Google Pay',
    'com.phonepe.app': 'PhonePe',
    'net.one97.paytm': 'Paytm',
    'in.org.npci.upiapp': 'BHIM',
    'com.whatsapp': 'WhatsApp Pay',
    'in.amazon.mShop.android.shopping': 'Amazon Pay',
    'com.dreamplug.androidapp': 'CRED',
    'com.csam.icici.bank.imobile': 'iMobile Pay',
    'com.sbi.upi': 'SBI Pay',
    'money.jupiter': 'Jupiter',
    'com.epifi.paisa': 'Fi Money',
    'com.myairtelapp': 'Airtel Thanks',
    'com.slice': 'Slice',
  };

  // ─────────────────────────────────────────────────────────────────────────
  //  Public API
  // ─────────────────────────────────────────────────────────────────────────

  /// Start listening and return the pipeline instance.
  static NotificationPipeline start({required AppDatabase db}) {
    final pipeline = NotificationPipeline._(db: db);
    pipeline._listen();
    debugPrint('NotifPipeline: started');
    return pipeline;
  }

  void dispose() {
    _subscription?.cancel();
    _dedupMap.clear();
    debugPrint('NotifPipeline: disposed');
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Internal pipeline
  // ─────────────────────────────────────────────────────────────────────────

  void _listen() {
    _subscription = NotificationService.paymentNotifications.listen(
      _handle,
      onError: (e) => debugPrint('NotifPipeline: stream error — $e'),
    );
  }

  Future<void> _handle(PaymentNotification notif) async {
    // Notifications without an amount cannot be turned into transactions.
    final amount = notif.amount;
    if (amount == null || amount <= 0) {
      debugPrint('NotifPipeline: skipped — no amount');
      return;
    }

    final direction = notif.isDebit ? 'DEBIT' : 'CREDIT';
    final now = DateTime.now();

    // ── Gate 1: in-memory 60-second dedup ──────────────────────────────────
    // Include a payee component so two different merchants paying the same
    // amount in the same minute are NOT incorrectly deduplicated.
    final payeeHint = (notif.payeeName ?? notif.packageName).hashCode;
    final memKey = '${amount.toStringAsFixed(2)}::$direction::$payeeHint';
    final lastSeen = _dedupMap[memKey];
    if (lastSeen != null && now.difference(lastSeen).inSeconds < 60) {
      debugPrint(
        'NotifPipeline: SKIP [mem-dedup] $direction ₹$amount '
        '(${now.difference(lastSeen).inSeconds}s ago)',
      );
      return;
    }
    _dedupMap[memKey] = now;

    // Prune cache: remove entries older than 2 minutes to bound memory.
    _dedupMap.removeWhere(
      (_, dt) => now.difference(dt).inMinutes >= 2,
    );

    try {
      // ── Gate 2: DB dedup — existing DEBIT ± 5 min ──────────────────────
      // Also catches INITIATED rows with amount = 0 (static-QR pre-logs).
      if (notif.isDebit) {
        final isDup = await _db.isDuplicateDebit(
          amount: amount,
          timestamp: notif.timestamp,
        );
        if (isDup) {
          debugPrint(
            'NotifPipeline: SKIP [debit-dup] ₹$amount at ${notif.timestamp}',
          );
          return;
        }
      }

      // ── Gate 3: DB dedup — prior NOTIF_IMPORT ± 60 s ──────────────────
      final isReimport = await _isDuplicateNotifImport(
        amount: amount,
        direction: direction,
        timestamp: notif.timestamp,
      );
      if (isReimport) {
        debugPrint(
          'NotifPipeline: SKIP [notif-reimport] $direction ₹$amount',
        );
        return;
      }

      // ── Build payee info ───────────────────────────────────────────
      final rawPayee = notif.payeeName ?? '';
      final appLabel = _upiAppLabels[notif.packageName] ?? notif.packageName;

      // Use the real VPA when available.
      // For notifications without a VPA (e.g. Paytm bank-only alerts),
      // fall back to a per-notification synthetic ID so the transaction
      // is NOT merged with unrelated transactions from the same app.
      final payeeUpiId = rawPayee.contains('@')
          ? rawPayee.toLowerCase()
          : 'notif::${notif.timestamp.millisecondsSinceEpoch}';

      // ── Resolve display name (priority order) ────────────────────────
      // 1. Existing payee in DB that has a user-edited (non-generic) name
      // 2. Raw payee from notification (when it is a real name, not a VPA)
      // 3. VPA local-part converted to readable form
      // 4. "Unknown" — NEVER store the app label as the merchant name
      String payeeName;

      final existingPayee = payeeUpiId.startsWith('notif::')
          ? null // per-txn synthetic ID: skip DB lookup
          : await _db.getPayeeByUpiId(payeeUpiId);

      if (existingPayee != null &&
          existingPayee.name.isNotEmpty &&
          !_isGenericName(existingPayee.name)) {
        // Priority 1: user has already given this payee a good name
        payeeName = existingPayee.name;
      } else if (rawPayee.isNotEmpty &&
          !rawPayee.contains('@') &&
          !_isGenericName(rawPayee)) {
        // Priority 2: notification supplied a readable display name
        payeeName = rawPayee;
      } else if (rawPayee.contains('@')) {
        // Priority 3: derive readable name from VPA local-part
        final localPart = rawPayee.split('@').first;
        final isPhone = RegExp(r'^\d{8,}$').hasMatch(localPart);
        if (!isPhone && localPart.length >= 2) {
          // Convert e.g. "rameshkumar" → "Rameshkumar"
          payeeName = localPart
              .replaceAll(RegExp(r'[._-]'), ' ')
              .split(' ')
              .map((w) => w.isNotEmpty
                  ? '${w[0].toUpperCase()}${w.substring(1)}'
                  : '')
              .join(' ');
        } else {
          // Phone-number VPA: show the number
          payeeName = localPart;
        }
      } else {
        // Priority 4: genuinely unknown — app label goes in the note only
        payeeName = 'Unknown';
      }

      // Build stable merchant key FIRST — needed for category lookup
      final mKey = MerchantIdentity.buildKey(
        upiId: payeeUpiId,
        payeeName: payeeName,
      );

      final category = notif.isDebit
          ? await MerchantLearningService.categorize(
              _db,
              payeeName: payeeName,
              upiId: payeeUpiId,
              merchantKey: mKey,
            )
          : 'Income';

      // ── Insert transaction ─────────────────────────────────────────────────
      final id = _uuid.v4();
      // The ref includes the payee hint so cross-source dedup can match
      // a later SMS import for the same transaction.
      final ref = 'NOTIF_${notif.timestamp.millisecondsSinceEpoch}';

      await _db.insertTransaction(TransactionsCompanion(
        id: Value(id),
        payeeUpiId: Value(payeeUpiId),
        payeeName: Value(payeeName),
        amount: Value(amount),
        transactionRef: Value(ref),
        approvalRefNo: const Value(null),
        status: const Value('SUCCESS'),
        paymentMode: const Value(_kPaymentMode),
        category: Value(category),
        direction: Value(direction),
        merchantKey: Value(mKey),
        // App label goes in the note — NOT in payeeName
        transactionNote: Value('Detected via $appLabel'),
        createdAt: Value(notif.timestamp),
        updatedAt: Value(DateTime.now()),
      ));

      // ── Upsert payee — only when we have a real, non-generic name ─
      if (!_isGenericName(payeeName) && !payeeUpiId.startsWith('notif::')) {
        final existingForUpsert = await _db.getPayeeByUpiId(payeeUpiId);
        if (existingForUpsert != null) {
          await _db.incrementPayeeCount(existingForUpsert.id);
          // Upgrade generic names to better resolved ones
          if (_isGenericName(existingForUpsert.name)) {
            await _db.updatePayeeName(existingForUpsert.id, payeeName);
          }
        } else {
          await _db.upsertPayee(PayeesCompanion(
            id: Value(_uuid.v4()),
            upiId: Value(payeeUpiId),
            name: Value(payeeName),
            category: Value(category),
            lastTransactionAt: Value(notif.timestamp),
            transactionCount: const Value(1),
          ));
        }
      }


      // Drift's watchAllTransactions / watchRecentTransactions streams
      // emit automatically on table changes — no explicit invalidation needed.
      debugPrint(
        'NotifPipeline: IMPORTED $direction ₹$amount → $payeeName '
        '[$appLabel] key=$mKey',
      );
    } catch (e, st) {
      debugPrint('NotifPipeline: ERROR processing notification — $e\n$st');
    }
  }

  /// Returns true if the name is a generic placeholder that should be
  /// upgraded when better information is available.
  static bool _isGenericName(String name) {
    if (name.isEmpty) return true;
    if (name == 'Unknown') return true;
    if (name.startsWith('Payment via ')) return true;
    if (name.startsWith('Detected via ')) return true;
    // Raw phone numbers are not a display name
    if (RegExp(r'^\d{8,}$').hasMatch(name)) return true;
    // Raw VPAs are not a display name
    if (RegExp(r'^[a-z0-9._-]+@[a-z]+$').hasMatch(name.toLowerCase())) {
      return true;
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  DB helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns true if a NOTIF_IMPORT transaction for the same amount + direction
  /// already exists within a ±60-second window of [timestamp].
  Future<bool> _isDuplicateNotifImport({
    required double amount,
    required String direction,
    required DateTime timestamp,
  }) async {
    const window = Duration(seconds: 60);
    final start = timestamp.subtract(window);
    final end = timestamp.add(window);
    final results = await _db.customSelect(
      'SELECT id FROM transactions '
      'WHERE ABS(amount - ?) < 0.50 '
      'AND direction = ? '
      'AND payment_mode = ? '
      'AND created_at >= ? AND created_at <= ? '
      'LIMIT 1',
      variables: [
        Variable.withReal(amount),
        Variable.withString(direction),
        Variable.withString(_kPaymentMode),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
    ).get();
    return results.isNotEmpty;
  }
}
