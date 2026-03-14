import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/constants/app_constants.dart';
import 'tables/transactions.dart';
import 'tables/payees.dart';
import 'tables/budgets.dart';
import 'tables/merchant_categories.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Transactions, Payees, Budgets, MerchantCategories])
class AppDatabase extends _$AppDatabase {
  AppDatabase()
      : super(driftDatabase(
          name: AppConstants.dbName,
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ));



  // Bump this when schema changes
  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(budgets);
          }
          if (from < 3) {
            try {
              await m.database.customStatement(
                "ALTER TABLE transactions ADD COLUMN direction TEXT NOT NULL DEFAULT 'DEBIT'",
              );
            } catch (_) {
              // Column may already exist from a partial migration
            }
          }
          if (from < 4) {
            // Add indices for production-level query performance
            await m.database.customStatement(
              'CREATE INDEX IF NOT EXISTS idx_txn_created_at ON transactions(created_at)',
            );
            await m.database.customStatement(
              'CREATE INDEX IF NOT EXISTS idx_txn_payee_upi ON transactions(payee_upi_id)',
            );
            await m.database.customStatement(
              'CREATE INDEX IF NOT EXISTS idx_txn_status_dir_date ON transactions(status, direction, created_at)',
            );
            await m.database.customStatement(
              'CREATE INDEX IF NOT EXISTS idx_payee_upi ON payees(upi_id)',
            );
          }
          if (from < 5) {
            // Add category + lastTransactionAt to payees
            try {
              await m.database.customStatement(
                'ALTER TABLE payees ADD COLUMN category TEXT',
              );
            } catch (_) {}
            try {
              await m.database.customStatement(
                'ALTER TABLE payees ADD COLUMN last_transaction_at INTEGER',
              );
            } catch (_) {}
            // Create merchant-category learning table
            await m.createTable(merchantCategories);
          }
          if (from < 6) {
            // Add stable merchant key column to transactions
            try {
              await m.database.customStatement(
                'ALTER TABLE transactions ADD COLUMN merchant_key TEXT',
              );
            } catch (_) {}
            // Deduplicate payees: keep earliest row per upi_id
            try {
              await m.database.customStatement(
                'DELETE FROM payees WHERE rowid NOT IN '
                '(SELECT MIN(rowid) FROM payees GROUP BY upi_id)',
              );
            } catch (_) {}
            // Enforce uniqueness on payees.upi_id going forward
            await m.database.customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_payee_upi_unique '
              'ON payees(upi_id)',
            );
            // Index on merchant_key for fast merchant-grouped queries
            await m.database.customStatement(
              'CREATE INDEX IF NOT EXISTS idx_txn_merchant_key '
              'ON transactions(merchant_key)',
            );
          }
        },
      );

  // ═══════════════════════════════════════════
  //  APP DATA MANAGEMENT
  // ═══════════════════════════════════════════

  /// Clear all app data (transactions, payees, budgets, merchant data)
  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(transactions).go();
      await delete(payees).go();
      await delete(budgets).go();
      await delete(merchantCategories).go();
    });
  }

  // ═══════════════════════════════════════════
  //  TRANSACTION QUERIES
  // ═══════════════════════════════════════════

  /// Insert a new transaction (pre-log as INITIATED)
  Future<int> insertTransaction(TransactionsCompanion entry) =>
      into(transactions).insert(entry);

  /// Update transaction status after UPI callback
  Future<bool> updateTransactionStatus({
    required String id,
    required String status,
    String? upiTxnId,
    String? approvalRefNo,
    String? responseCode,
  }) async {
    final result = await (update(transactions)
          ..where((t) => t.id.equals(id)))
        .write(
      TransactionsCompanion(
        status: Value(status),
        upiTxnId: upiTxnId != null ? Value(upiTxnId) : const Value.absent(),
        approvalRefNo:
            approvalRefNo != null ? Value(approvalRefNo) : const Value.absent(),
        responseCode:
            responseCode != null ? Value(responseCode) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return result > 0;
  }

  /// Update transaction payee name (single transaction only)
  Future<bool> updateTransactionPayeeName(String id, String name) async {
    final result = await (update(transactions)
          ..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(
      payeeName: Value(name),
      updatedAt: Value(DateTime.now()),
    ));
    return result > 0;
  }

  /// Batch-update payee name on ALL transactions sharing the same merchantKey.
  /// This is the preferred rename path for identified merchants.
  Future<int> updateAllTransactionsByMerchantKey(
      String merchantKey, String name) async {
    return (update(transactions)
          ..where((t) => t.merchantKey.equals(merchantKey)))
        .write(TransactionsCompanion(
      payeeName: Value(name),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Batch-update payee name on ALL transactions matching a UPI ID.
  /// Fallback for legacy rows without a merchantKey.
  Future<int> updateAllTransactionsPayeeName(String upiId, String name) async {
    return (update(transactions)
          ..where((t) => t.payeeUpiId.equals(upiId)))
        .write(TransactionsCompanion(
      payeeName: Value(name),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Update transaction category
  Future<bool> updateTransactionCategory(String id, String category) async {
    final result = await (update(transactions)
          ..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(
      category: Value(category),
      updatedAt: Value(DateTime.now()),
    ));
    return result > 0;
  }

  /// Batch-update category on ALL transactions sharing the same merchantKey.
  /// Called when a user sets a category and wants it applied retroactively.
  Future<int> batchUpdateCategoryByMerchantKey(
      String merchantKey, String category) async {
    return (update(transactions)
          ..where((t) => t.merchantKey.equals(merchantKey)))
        .write(TransactionsCompanion(
      category: Value(category),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Update transaction amount (used when amount is detected from SMS)
  Future<bool> updateTransactionAmount(String id, double amount) async {
    final result = await (update(transactions)
          ..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(
      amount: Value(amount),
      updatedAt: Value(DateTime.now()),
    ));
    return result > 0;
  }

  /// Get all transactions ordered by newest first
  Future<List<Transaction>> getAllTransactions() =>
      (select(transactions)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  /// Watch all transactions (reactive stream)
  Stream<List<Transaction>> watchAllTransactions() =>
      (select(transactions)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  /// Watch recent transactions (limit)
  Stream<List<Transaction>> watchRecentTransactions({int limit = 10}) =>
      (select(transactions)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit))
          .watch();

  /// Get transaction by ID
  Future<Transaction?> getTransactionById(String id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Get transactions by status
  Future<List<Transaction>> getTransactionsByStatus(String status) =>
      (select(transactions)
            ..where((t) => t.status.equals(status))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  /// Get transactions in date range
  Future<List<Transaction>> getTransactionsInRange(
    DateTime start,
    DateTime end,
  ) =>
      (select(transactions)
            ..where((t) =>
                t.createdAt.isBiggerOrEqualValue(start) &
                t.createdAt.isSmallerOrEqualValue(end))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  /// Search transactions by payee name or UPI ID
  Future<List<Transaction>> searchTransactions(String query) {
    // Escape LIKE wildcards to prevent unintended matches
    final escaped = query
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
    return (select(transactions)
          ..where((t) =>
              t.payeeName.like('%$escaped%') |
              t.payeeUpiId.like('%$escaped%') |
              t.transactionNote.like('%$escaped%'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Get all transactions for a specific payee
  Future<List<Transaction>> getTransactionsByPayee(String upiId) =>
      (select(transactions)
            ..where((t) => t.payeeUpiId.equals(upiId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  /// Find transaction by UPI ref number (for SMS dedup)
  Future<Transaction?> findTransactionByRef(String refNumber) =>
      (select(transactions)
            ..where((t) =>
                t.approvalRefNo.equals(refNumber) |
                t.transactionRef.equals(refNumber)))
          .getSingleOrNull();

  /// Check if a DEBIT transaction already exists with similar amount and time.
  /// Tolerance: amounts < ₹100 use exact match (0.01) to avoid false positives
  /// on common small repeated payments (e.g. two separate ₹50 transactions).
  /// Amounts ≥ ₹100 use ±₹1.00 for minor rounding differences.
  Future<bool> isDuplicateDebit({
    required double amount,
    required DateTime timestamp,
    String? payeeUpiId,
  }) async {
    const window = Duration(minutes: 5);
    final start = timestamp.subtract(window);
    final end = timestamp.add(window);
    final tolerance = amount < 100.0 ? 0.01 : 1.0;

    String query = 'SELECT id FROM transactions '
        'WHERE direction = ? '
        'AND created_at >= ? AND created_at <= ? '
        'AND ABS(amount - ?) < ? ';

    final variables = <Variable>[
      Variable.withString('DEBIT'),
      Variable.withDateTime(start),
      Variable.withDateTime(end),
      Variable.withReal(amount),
      Variable.withReal(tolerance),
    ];

    if (payeeUpiId != null && payeeUpiId.isNotEmpty) {
      query += 'AND payee_upi_id = ? ';
      variables.add(Variable.withString(payeeUpiId));
    }

    query += 'LIMIT 1';
    final results = await customSelect(query, variables: variables).get();
    return results.isNotEmpty;
  }

  /// Check if an identical SMS-imported transaction already exists.
  /// Prevents the same SMS from being imported twice across syncs.
  ///
  /// When [payeeUpiId] is a real VPA (not a synthetic 'sms::' / 'notif::' ID),
  /// the match also filters by payee so two completely different people sending
  /// the same amount within a 5-min window don't accidentally de-duplicate.
  Future<bool> isDuplicateSmsImport({
    required double amount,
    required String direction,
    required DateTime timestamp,
    String? payeeUpiId,
  }) async {
    // Use a tighter 1-min window for synthetic IDs; 5-min for real VPAs.
    final isRealVpa = payeeUpiId != null &&
        payeeUpiId.contains('@') &&
        !payeeUpiId.startsWith('sms::') &&
        !payeeUpiId.startsWith('notif::');
    final window = isRealVpa ? const Duration(minutes: 5) : const Duration(minutes: 1);

    final start = timestamp.subtract(window);
    final end = timestamp.add(window);

    String query = 'SELECT id FROM transactions '
        'WHERE ABS(amount - ?) < 0.50 '
        'AND direction = ? '
        'AND created_at >= ? AND created_at <= ? ';

    final variables = <Variable>[
      Variable.withReal(amount),
      Variable.withString(direction),
      Variable.withDateTime(start),
      Variable.withDateTime(end),
    ];

    // For real VPAs, also match payee to avoid false positives
    if (isRealVpa) {
      query += 'AND payee_upi_id = ? ';
      variables.add(Variable.withString(payeeUpiId));
    } else {
      // For synthetic IDs, restrict to SMS_IMPORT mode only
      query += 'AND payment_mode = ? ';
      variables.add(Variable.withString('SMS_IMPORT'));
    }

    query += 'LIMIT 1';
    final results = await customSelect(query, variables: variables).get();
    return results.isNotEmpty;
  }

  /// ════════════════════════════════════════════════════════════════════════
  ///  SMS PRIORITY OVERRIDES
  /// ════════════════════════════════════════════════════════════════════════

  /// Finds an existing transaction imported by the Notification Listener
  /// that matches the given SMS parameters.
  /// Used to allow the SMS to "overwrite" and upgrade the notification event.
  Future<String?> findMatchingNotificationImport({
    required double amount,
    required String direction,
    required DateTime timestamp,
  }) async {
    // 5-minute window to find the corresponding notification
    final start = timestamp.subtract(const Duration(minutes: 5));
    final end = timestamp.add(const Duration(minutes: 5));

    final results = await customSelect(
      'SELECT id FROM transactions '
      'WHERE ABS(amount - ?) < 0.50 '
      'AND direction = ? '
      'AND payment_mode = ? ' // Specifically look for Notification imports
      'AND created_at >= ? AND created_at <= ? '
      'LIMIT 1',
      variables: [
        Variable.withReal(amount),
        Variable.withString(direction),
        Variable.withString('NOTIF_IMPORT'),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
    ).get();

    if (results.isNotEmpty) {
      return results.first.read<String>('id');
    }
    return null;
  }

  /// Upgrades an existing Notification-imported transaction with high-fidelity
  /// data from an SMS (exact bank name, precise amount, stable merchant key).
  Future<int> upgradeTransactionFromSms({
    required String transactionId,
    required String payeeUpiId,
    required String payeeName,
    required String merchantKey,
    required String? category,
  }) async {
    return (update(transactions)..where((t) => t.id.equals(transactionId))).write(
      TransactionsCompanion(
        paymentMode: const Value('SMS_IMPORT'), // Upgrade the mode
        payeeUpiId: Value(payeeUpiId),
        payeeName: Value(payeeName),
        merchantKey: Value(merchantKey),
        category: category != null ? Value(category) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
        // We append a note indicating it was upgraded to preserve history
        transactionNote: const Value('Verified via Bank SMS'),
      ),
    );
  }

  /// Get total spent (successful transactions only)
  Future<double> getTotalSpent() async {
    final result = await customSelect(
      'SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE status = ?',
      variables: [Variable.withString(AppConstants.statusSuccess)],
    ).getSingle();
    return result.read<double>('total');
  }

  /// Get total spent in a month (DEBIT only)
  Future<double> getMonthlySpent(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    final result = await customSelect(
      'SELECT COALESCE(SUM(amount), 0) as total FROM transactions '
      'WHERE status = ? AND direction = ? AND created_at >= ? AND created_at <= ?',
      variables: [
        Variable.withString(AppConstants.statusSuccess),
        Variable.withString('DEBIT'),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
    ).getSingle();
    return result.read<double>('total');
  }

  /// Get total received in a month (CREDIT only)
  Future<double> getMonthlyReceived(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    final result = await customSelect(
      'SELECT COALESCE(SUM(amount), 0) as total FROM transactions '
      'WHERE status = ? AND direction = ? AND created_at >= ? AND created_at <= ?',
      variables: [
        Variable.withString(AppConstants.statusSuccess),
        Variable.withString('CREDIT'),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
    ).getSingle();
    return result.read<double>('total');
  }

  /// Get spending by category for a month (DEBIT only)
  Future<Map<String, double>> getCategorySpending(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    final results = await customSelect(
      'SELECT category, COALESCE(SUM(amount), 0) as total FROM transactions '
      'WHERE status = ? AND direction = ? AND created_at >= ? AND created_at <= ? '
      'GROUP BY category ORDER BY total DESC',
      variables: [
        Variable.withString(AppConstants.statusSuccess),
        Variable.withString('DEBIT'),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
    ).get();

    return {
      for (final row in results)
        row.read<String>('category'): row.read<double>('total'),
    };
  }

  /// Get all successful transactions for a specific month
  Future<List<Transaction>> getMonthTransactions(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    return (select(transactions)
          ..where((t) =>
              t.status.equals(AppConstants.statusSuccess) &
              t.createdAt.isBiggerOrEqualValue(start) &
              t.createdAt.isSmallerOrEqualValue(end))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Watch all successful transactions for a specific month.
  Stream<List<Transaction>> watchMonthTransactions(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    return (select(transactions)
          ..where((t) =>
              t.status.equals(AppConstants.statusSuccess) &
              t.createdAt.isBiggerOrEqualValue(start) &
              t.createdAt.isSmallerOrEqualValue(end))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Delete a transaction
  Future<int> deleteTransaction(String id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  // ═══════════════════════════════════════════
  //  PAYEE QUERIES
  // ═══════════════════════════════════════════

  /// Insert or update a payee
  Future<int> upsertPayee(PayeesCompanion entry) =>
      into(payees).insertOnConflictUpdate(entry);

  /// Get all payees ordered by most used
  Future<List<Payee>> getAllPayees() =>
      (select(payees)
            ..orderBy([(p) => OrderingTerm.desc(p.transactionCount)]))
          .get();

  /// Watch all payees
  Stream<List<Payee>> watchAllPayees() =>
      (select(payees)
            ..orderBy([(p) => OrderingTerm.desc(p.transactionCount)]))
          .watch();

  /// Get top N payees (for favorites strip)
  Future<List<Payee>> getTopPayees({int limit = 5}) =>
      (select(payees)
            ..orderBy([(p) => OrderingTerm.desc(p.transactionCount)])
            ..limit(limit))
          .get();

  /// Search payees
  Future<List<Payee>> searchPayees(String query) {
    final escaped = query
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
    return (select(payees)
          ..where((p) =>
              p.name.like('%$escaped%') | p.upiId.like('%$escaped%'))
          ..orderBy([(p) => OrderingTerm.desc(p.transactionCount)]))
        .get();
  }

  /// Increment payee transaction count
  Future<void> incrementPayeeCount(String payeeId) async {
    await customStatement(
      'UPDATE payees SET transaction_count = transaction_count + 1, '
      'last_paid_at = ? WHERE id = ?',
      [
        Variable.withDateTime(DateTime.now()),
        Variable.withString(payeeId),
      ],
    );
  }

  /// Update payee name (for user-edited names — reused by SMS sync)
  Future<void> updatePayeeName(String payeeId, String name) async {
    await (update(payees)..where((p) => p.id.equals(payeeId)))
        .write(PayeesCompanion(name: Value(name)));
  }

  /// Update payee phone number
  Future<void> updatePayeePhone(String payeeId, String phone) async {
    await (update(payees)..where((p) => p.id.equals(payeeId)))
        .write(PayeesCompanion(phone: Value(phone)));
  }

  /// Delete a payee
  Future<int> deletePayee(String id) =>
      (delete(payees)..where((p) => p.id.equals(id))).go();

  /// Get payee by UPI ID
  Future<Payee?> getPayeeByUpiId(String upiId) =>
      (select(payees)..where((p) => p.upiId.equals(upiId))).getSingleOrNull();

  // ═══════════════════════════════════════════
  //  BUDGET QUERIES
  // ═══════════════════════════════════════════

  /// Get budget for a specific month
  Future<Budget?> getBudget(int year, int month) =>
      (select(budgets)
            ..where((b) => b.year.equals(year) & b.month.equals(month)))
          .getSingleOrNull();

  /// Insert or update the monthly budget
  Future<void> upsertBudget(int year, int month, double amount) async {
    final existing = await getBudget(year, month);
    if (existing != null) {
      await (update(budgets)..where((b) => b.id.equals(existing.id)))
          .write(BudgetsCompanion(limitAmount: Value(amount)));
    } else {
      await into(budgets).insert(BudgetsCompanion(
        id: Value('budget_${year}_$month'),
        year: Value(year),
        month: Value(month),
        limitAmount: Value(amount),
      ));
    }
  }

  // ═══════════════════════════════════════════
  //  DAILY SPENDING (for heatmap calendar)
  // ═══════════════════════════════════════════

  /// Returns a map of day-of-month → total DEBIT amount for the given month.
  /// e.g. {1: 350.0, 2: 0.0, 5: 1200.0, ...}
  Future<Map<int, double>> getDailySpending(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);

    final rows = await (select(transactions)
          ..where((t) =>
              t.createdAt.isBiggerOrEqualValue(start) &
              t.createdAt.isSmallerOrEqualValue(end) &
              t.direction.equals('DEBIT') &
              t.status.equals('SUCCESS')))
        .get();

    final daily = <int, double>{};
    for (final txn in rows) {
      final day = txn.createdAt.day;
      daily[day] = (daily[day] ?? 0) + txn.amount;
    }
    return daily;
  }

  /// Returns total monthly spent (DEBIT) amounts for given months.
  /// Returns list in same order as input dates.
  Future<List<double>> getMonthlySpendingHistory(
      List<DateTime> months) async {
    final results = <double>[];
    for (final m in months) {
      final spent = await getMonthlySpent(m.year, m.month);
      results.add(spent);
    }
    return results;
  }

  /// Returns total monthly received (CREDIT) amounts for given months.
  Future<List<double>> getMonthlyIncomeHistory(
      List<DateTime> months) async {
    final results = <double>[];
    for (final m in months) {
      final received = await getMonthlyReceived(m.year, m.month);
      results.add(received);
    }
    return results;
  }

  // ═══════════════════════════════════════════
  //  MERCHANT LEARNING QUERIES
  // ═══════════════════════════════════════════

  /// Look up the learned category for a merchant key.
  /// Returns null if no mapping has been stored yet.
  Future<String?> getMerchantCategory(String key) async {
    final row = await (select(merchantCategories)
          ..where((m) => m.merchantKey.equals(key)))
        .getSingleOrNull();
    return row?.category;
  }

  /// Insert or update a merchant-category mapping.
  Future<void> upsertMerchantCategory(String key, String category) =>
      into(merchantCategories).insertOnConflictUpdate(
        MerchantCategoriesCompanion(
          merchantKey: Value(key),
          category: Value(category),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Delete a merchant-category mapping (for user resets).
  Future<void> deleteMerchantCategory(String key) =>
      (delete(merchantCategories)
            ..where((m) => m.merchantKey.equals(key)))
          .go();

  /// Return all stored merchant-category mappings (for a settings view).
  Future<List<MerchantCategory>> getAllMerchantCategories() =>
      (select(merchantCategories)
            ..orderBy([(m) => OrderingTerm.asc(m.merchantKey)]))
          .get();

  /// Watch all merchant-category mappings reactively.
  Stream<List<MerchantCategory>> watchAllMerchantCategories() =>
      (select(merchantCategories)
            ..orderBy([(m) => OrderingTerm.asc(m.merchantKey)]))
          .watch();
}


