import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/app_constants.dart';
import 'tables/transactions.dart';
import 'tables/payees.dart';
import 'tables/budgets.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Transactions, Payees, Budgets])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // Bump this when schema changes
  @override
<<<<<<< HEAD
  int get schemaVersion => 3;
=======
  int get schemaVersion => 2;
>>>>>>> b320780f40711318dbd695d92961461caf4e7088

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(budgets);
          }
<<<<<<< HEAD
          if (from < 3) {
            await m.database.customStatement(
              "ALTER TABLE transactions ADD COLUMN direction TEXT NOT NULL DEFAULT 'DEBIT'",
            );
          }
=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
        },
      );

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

<<<<<<< HEAD
  /// Update transaction payee name (for user-edited SMS imports)
  Future<bool> updateTransactionPayeeName(String id, String name) async {
    final result = await (update(transactions)
          ..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(
      payeeName: Value(name),
      updatedAt: Value(DateTime.now()),
    ));
    return result > 0;
  }

=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
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
  Future<List<Transaction>> searchTransactions(String query) =>
      (select(transactions)
            ..where((t) =>
                t.payeeName.like('%$query%') |
                t.payeeUpiId.like('%$query%') |
                t.transactionNote.like('%$query%'))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  /// Get all transactions for a specific payee
  Future<List<Transaction>> getTransactionsByPayee(String upiId) =>
      (select(transactions)
            ..where((t) => t.payeeUpiId.equals(upiId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

<<<<<<< HEAD
  /// Find transaction by UPI ref number (for SMS dedup)
  Future<Transaction?> findTransactionByRef(String refNumber) =>
      (select(transactions)
            ..where((t) =>
                t.approvalRefNo.equals(refNumber) |
                t.transactionRef.equals(refNumber)))
          .getSingleOrNull();

  /// Check if a DEBIT transaction already exists with similar amount and time.
  /// Intentionally ignores payee because app-tracked transactions store the
  /// actual payee UPI ID, while bank SMS uses a different sender name.
  /// Uses ±5 min window since bank SMS can arrive delayed.
  Future<bool> isDuplicateDebit({
    required double amount,
    required DateTime timestamp,
  }) async {
    final window = const Duration(minutes: 5);
    final start = timestamp.subtract(window);
    final end = timestamp.add(window);
    final results = await customSelect(
      'SELECT id FROM transactions '
      'WHERE ABS(amount - ?) < 1.0 '
      'AND direction = ? '
      'AND created_at >= ? AND created_at <= ? '
      'LIMIT 1',
      variables: [
        Variable.withReal(amount),
        Variable.withString('DEBIT'),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
    ).get();
    return results.isNotEmpty;
  }

  /// Check if an identical SMS-imported transaction already exists.
  /// Prevents the same SMS from being imported twice across syncs.
  Future<bool> isDuplicateSmsImport({
    required double amount,
    required String direction,
    required DateTime timestamp,
  }) async {
    final window = const Duration(minutes: 1);
    final start = timestamp.subtract(window);
    final end = timestamp.add(window);
    final results = await customSelect(
      'SELECT id FROM transactions '
      'WHERE ABS(amount - ?) < 0.50 '
      'AND direction = ? '
      'AND payment_mode = ? '
      'AND created_at >= ? AND created_at <= ? '
      'LIMIT 1',
      variables: [
        Variable.withReal(amount),
        Variable.withString(direction),
        Variable.withString('SMS_IMPORT'),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
    ).get();
    return results.isNotEmpty;
  }

=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
  /// Get total spent (successful transactions only)
  Future<double> getTotalSpent() async {
    final result = await customSelect(
      'SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE status = ?',
      variables: [Variable.withString(AppConstants.statusSuccess)],
    ).getSingle();
    return result.read<double>('total');
  }

<<<<<<< HEAD
  /// Get total spent in a month (DEBIT only)
=======
  /// Get total spent in a month
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
  Future<double> getMonthlySpent(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    final result = await customSelect(
      'SELECT COALESCE(SUM(amount), 0) as total FROM transactions '
<<<<<<< HEAD
      'WHERE status = ? AND direction = ? AND created_at >= ? AND created_at <= ?',
      variables: [
        Variable.withString(AppConstants.statusSuccess),
        Variable.withString('DEBIT'),
=======
      'WHERE status = ? AND created_at >= ? AND created_at <= ?',
      variables: [
        Variable.withString(AppConstants.statusSuccess),
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
    ).getSingle();
    return result.read<double>('total');
  }

<<<<<<< HEAD
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
=======
  /// Get spending by category for a month
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
  Future<Map<String, double>> getCategorySpending(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    final results = await customSelect(
      'SELECT category, COALESCE(SUM(amount), 0) as total FROM transactions '
<<<<<<< HEAD
      'WHERE status = ? AND direction = ? AND created_at >= ? AND created_at <= ? '
      'GROUP BY category ORDER BY total DESC',
      variables: [
        Variable.withString(AppConstants.statusSuccess),
        Variable.withString('DEBIT'),
=======
      'WHERE status = ? AND created_at >= ? AND created_at <= ? '
      'GROUP BY category ORDER BY total DESC',
      variables: [
        Variable.withString(AppConstants.statusSuccess),
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
    ).get();

    return {
      for (final row in results)
        row.read<String>('category'): row.read<double>('total'),
    };
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
  Future<List<Payee>> searchPayees(String query) =>
      (select(payees)
            ..where((p) =>
                p.name.like('%$query%') | p.upiId.like('%$query%'))
            ..orderBy([(p) => OrderingTerm.desc(p.transactionCount)]))
          .get();

  /// Increment payee transaction count
  Future<void> incrementPayeeCount(String payeeId) async {
    await customStatement(
      'UPDATE payees SET transaction_count = transaction_count + 1, '
      'last_paid_at = ? WHERE id = ?',
      [DateTime.now().millisecondsSinceEpoch, payeeId],
    );
  }

<<<<<<< HEAD
  /// Update payee name (for user-edited names — reused by SMS sync)
  Future<void> updatePayeeName(String payeeId, String name) async {
    await (update(payees)..where((p) => p.id.equals(payeeId)))
        .write(PayeesCompanion(name: Value(name)));
  }

=======
>>>>>>> b320780f40711318dbd695d92961461caf4e7088
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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, AppConstants.dbName));
    return NativeDatabase.createInBackground(file);
  });
}
