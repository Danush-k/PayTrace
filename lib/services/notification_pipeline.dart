import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

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
    final memKey = '${amount.toStringAsFixed(2)}::$direction';
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

      // ── Build payee info ───────────────────────────────────────────────
      final rawPayee = notif.payeeName ?? '';
      final payeeUpiId = rawPayee.contains('@')
          ? rawPayee
          : 'notif::${notif.packageName}';

      // Resolve existing payee name or fall back to parsed
      final existingPayee = rawPayee.contains('@')
          ? await _db.getPayeeByUpiId(payeeUpiId)
          : null;
      final payeeName =
          (existingPayee?.name.isNotEmpty == true)
              ? existingPayee!.name
              : (rawPayee.isNotEmpty ? rawPayee : 'Unknown');

      final category = notif.isDebit
          ? await MerchantLearningService.categorize(
              _db,
              payeeName: payeeName,
              upiId: payeeUpiId,
            )
          : 'Income';

      // ── Insert transaction ─────────────────────────────────────────────
      final id = _uuid.v4();
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
        transactionNote: Value('Auto-imported from ${notif.packageName}'),
        createdAt: Value(notif.timestamp),
        updatedAt: Value(DateTime.now()),
      ));

      // ── Upsert payee ───────────────────────────────────────────────────
      if (payeeName != 'Unknown') {
        await _db.upsertPayee(PayeesCompanion(
          upiId: Value(payeeUpiId),
          name: Value(payeeName),
          category: Value(category),
          lastTransactionAt: Value(notif.timestamp),
        ));
      }

      // Drift's watchAllTransactions / watchRecentTransactions streams
      // emit automatically on table changes — no explicit invalidation needed.
      debugPrint(
        'NotifPipeline: IMPORTED $direction ₹$amount → $payeeName '
        '[${notif.packageName}]',
      );
    } catch (e, st) {
      debugPrint('NotifPipeline: ERROR processing notification — $e\n$st');
    }
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
