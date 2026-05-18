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
//    1. Checked against a 60-second in-memory dedup cache (payee-scoped)
//    2. Checked against existing DEBIT records in the DB (±5 min)
//    3. Checked against prior NOTIF_IMPORT records in the DB (±60 s)
//    4. Inserted with paymentMode = 'NOTIF_IMPORT' and merchantKey
//    5. Drift watch-streams auto-emit — UI refreshes without manual invalidation
//
//  KEY FIXES vs original:
//    • Per-txn synthetic IDs (not shared 'notif::packageName') prevent
//      transactions from different merchants being merged together.
//    • Payee name resolution NEVER stores 'Payment via GPay' as a merchant.
//    • Dedup key includes a payee hash so two diferent merchants paying the
//      same amount in the same second are not collapsed.
//    • merchantKey is built and stored for all downstream grouping.
// ═══════════════════════════════════════════════════════════════════════════

const _kPaymentMode = 'NOTIF_IMPORT';

/// UPI app package → readable display label (app label stays in note only)
const _upiAppLabels = {
  'com.google.android.apps.nbu.paisa.user': 'GPay',
  'net.one97.paytm': 'Paytm',
  'com.phonepe.app': 'PhonePe',
  'in.amazon.mShop.android.shopping': 'Amazon Pay',
  'com.whatsapp': 'WhatsApp Pay',
  'com.bhim.axisb': 'BHIM',
  'in.org.npci.upiapp': 'BHIM',
};

class NotificationPipeline {
  NotificationPipeline._({required AppDatabase db}) : _db = db;

  final AppDatabase _db;
  StreamSubscription<PaymentNotification>? _subscription;

  /// In-memory 60-second dedup cache.
  /// Key: "<amount>::<direction>::<payeeHint>" to avoid collapsing different merchants
  final _dedupMap = <String, DateTime>{};

  static const _uuid = Uuid();

  // ─────────────────────────────────────────────────────────────────────────
  //  Public API
  // ─────────────────────────────────────────────────────────────────────────

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
    final amount = notif.amount;
    if (amount == null || amount <= 0) {
      debugPrint('NotifPipeline: skipped — no amount');
      return;
    }

    final direction = notif.isDebit ? 'DEBIT' : 'CREDIT';
    final now = DateTime.now();

    // ── Gate 1: in-memory 60-second dedup ──────────────────────────────────
    // Include payee identity so two different merchants paying the same
    // amount in the same minute are NOT collapsed together.
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

    // Prune cache: remove entries older than 2 minutes
    _dedupMap.removeWhere((_, dt) => now.difference(dt).inMinutes >= 2);

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

      // ── Resolve payee info ─────────────────────────────────────────────
      final rawPayee = notif.payeeName ?? '';
      final appLabel = _upiAppLabels[notif.packageName] ?? notif.packageName;

      // Use the real VPA when available. For notifications without a VPA
      // fall back to a per-notification timestamp-based synthetic ID so
      // transactions from different merchants on the same UPI app are NEVER
      // incorrectly merged together.
      final payeeUpiId = rawPayee.contains('@')
          ? rawPayee.toLowerCase()
          : 'notif::${notif.timestamp.millisecondsSinceEpoch}';

      // ── Resolve display name (priority order) ──────────────────────────
      // 1. Existing payee with a user-set (non-generic) name in DB
      // 2. Readable display name from notification (not a VPA, not generic)
      // 3. VPA local-part → Title Case (only if not purely digits)
      // 4. 'Unknown'  — app-label (e.g. 'GPay') NEVER goes in payeeName
      String payeeName;
      final existingPayee = payeeUpiId.startsWith('notif::')
          ? null // per-txn synthetic: no stable DB key to look up
          : await _db.getPayeeByUpiId(payeeUpiId);

      if (existingPayee != null &&
          existingPayee.name.isNotEmpty &&
          !_isGenericName(existingPayee.name)) {
        payeeName = existingPayee.name;
      } else if (rawPayee.isNotEmpty &&
          !rawPayee.contains('@') &&
          !_isGenericName(rawPayee)) {
        payeeName = rawPayee;
      } else if (rawPayee.contains('@')) {
        final localPart = rawPayee.split('@').first;
        final isPhone = RegExp(r'^\d{8,}$').hasMatch(localPart);
        if (!isPhone && localPart.length >= 2) {
          payeeName = localPart
              .replaceAll(RegExp(r'[._\-]'), ' ')
              .split(' ')
              .map((w) =>
                  w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
              .join(' ')
              .trim();
        } else {
          payeeName = localPart; // phone number — will show as digits
        }
      } else {
        payeeName = 'Unknown';
      }

      // ── Build stable merchantKey FIRST — needed for category lookup ────
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
        merchantKey: Value(mKey),
        // App label goes in note ONLY so the history shows real names
        transactionNote: Value('Detected via $appLabel'),
        createdAt: Value(notif.timestamp),
        updatedAt: Value(DateTime.now()),
      ));

      // ── Upsert payee — only for real, identifiable payees ─────────────
      if (!_isGenericName(payeeName) && !payeeUpiId.startsWith('notif::')) {
        await _db.upsertPayee(PayeesCompanion(
          upiId: Value(payeeUpiId),
          name: Value(payeeName),
          category: Value(category),
          lastTransactionAt: Value(notif.timestamp),
        ));
      }

      debugPrint(
        'NotifPipeline: IMPORTED $direction ₹$amount → $payeeName '
        '[mKey=$mKey]',
      );
    } catch (e, st) {
      debugPrint('NotifPipeline: ERROR — $e\n$st');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns true if the name is too generic to save as a payee name.
  static bool _isGenericName(String name) {
    final n = name.toLowerCase().trim();
    if (n.isEmpty || n == 'unknown') return true;
    // Reject raw phone numbers
    if (RegExp(r'^\d{8,}$').hasMatch(n)) return true;
    // Reject raw VPAs
    if (n.contains('@')) return true;
    // Reject generic app-label patterns
    const generics = {
      'payment via gpay', 'payment via phonepe', 'payment via paytm',
      'payment via amazon pay', 'payment via bhim', 'google pay',
      'phonepe', 'paytm', 'amazon pay', 'bhim', 'gpay',
      'upi payment', 'bank transfer', 'neft', 'imps', 'rtgs',
    };
    return generics.contains(n);
  }

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
      'AND payment_mode IN (?, ?) ' // Check both Notification and SMS imports
      'AND created_at >= ? AND created_at <= ? '
      'LIMIT 1',
      variables: [
        Variable.withReal(amount),
        Variable.withString(direction),
        Variable.withString(_kPaymentMode),
        Variable.withString('SMS_IMPORT'),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
    ).get();
    return results.isNotEmpty;
  }
}
