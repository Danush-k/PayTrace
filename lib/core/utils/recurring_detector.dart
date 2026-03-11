import '../../data/database/app_database.dart';

/// Represents a detected recurring payment pattern
class RecurringPayment {
  final String payeeUpiId;
  final String payeeName;
  final double averageAmount;
  final int paymentCount;
  final DateTime lastPaidAt;
  final DateTime? nextExpectedDate;
  final String frequency; // 'Monthly', 'Weekly', 'Frequent'

  const RecurringPayment({
    required this.payeeUpiId,
    required this.payeeName,
    required this.averageAmount,
    required this.paymentCount,
    required this.lastPaidAt,
    this.nextExpectedDate,
    required this.frequency,
  });
}

/// Detects recurring payment patterns from transaction history.
/// Simple heuristic: groups by payee, checks frequency of payments.
class RecurringDetector {
  RecurringDetector._();

  /// Analyze transactions and return recurring payment patterns
  static List<RecurringPayment> detect(List<Transaction> transactions) {
    // Only consider successful transactions
    final successful = transactions
        .where((t) => t.status == 'SUCCESS')
        .toList();

    // Group by payee UPI ID
    final grouped = <String, List<Transaction>>{};
    for (final txn in successful) {
      grouped.putIfAbsent(txn.payeeUpiId, () => []).add(txn);
    }

    final results = <RecurringPayment>[];

    for (final entry in grouped.entries) {
      final txns = entry.value;
      if (txns.length < 2) continue; // Need at least 2 payments

      // Sort by date (newest first)
      txns.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final avgAmount = txns.fold<double>(0, (sum, t) => sum + t.amount) / txns.length;
      final lastPaid = txns.first.createdAt;

      // Calculate average gap between payments
      final gaps = <int>[];
      for (int i = 0; i < txns.length - 1; i++) {
        gaps.add(txns[i].createdAt.difference(txns[i + 1].createdAt).inDays);
      }
      final avgGap = gaps.fold<int>(0, (sum, g) => sum + g) / gaps.length;

      // Determine frequency
      String frequency;
      DateTime? nextExpected;

      if (avgGap <= 10) {
        frequency = 'Weekly';
        nextExpected = lastPaid.add(Duration(days: avgGap.round()));
      } else if (avgGap <= 45) {
        frequency = 'Monthly';
        // Safe date: clamp day to the last valid day of next month
        // (e.g. Jan 31 → Feb 28, Mar 31 → Apr 30)
        final nextMonth = lastPaid.month == 12 ? 1 : lastPaid.month + 1;
        final nextYear = lastPaid.month == 12 ? lastPaid.year + 1 : lastPaid.year;
        final lastDayOfNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        final safeDay = lastPaid.day > lastDayOfNextMonth ? lastDayOfNextMonth : lastPaid.day;
        nextExpected = DateTime(nextYear, nextMonth, safeDay);
      } else {
        frequency = 'Frequent';
        nextExpected = lastPaid.add(Duration(days: avgGap.round()));
      }

      // Only include if next expected date is within the next 15 days
      // (to show relevant upcoming payments)
      final now = DateTime.now();
      final daysUntilNext = nextExpected.difference(now).inDays;
      if (daysUntilNext > 15) continue;

      results.add(RecurringPayment(
        payeeUpiId: entry.key,
        payeeName: txns.first.payeeName,
        averageAmount: avgAmount,
        paymentCount: txns.length,
        lastPaidAt: lastPaid,
        nextExpectedDate: nextExpected,
        frequency: frequency,
      ));
    }

    // Sort by next expected date (soonest first)
    results.sort((a, b) {
      if (a.nextExpectedDate == null) return 1;
      if (b.nextExpectedDate == null) return -1;
      return a.nextExpectedDate!.compareTo(b.nextExpectedDate!);
    });

    return results;
  }
}
