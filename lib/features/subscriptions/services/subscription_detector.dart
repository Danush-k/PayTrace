import '../../../data/database/app_database.dart';
import '../models/subscription_model.dart';

class SubscriptionDetector {
  /// Analyzes a list of transactions to detect recurring subscriptions.
  static List<SubscriptionModel> detectSubscriptions(List<Transaction> transactions) {
    // Only consider successful outgoing payments
    final debits = transactions.where((t) => t.direction == 'DEBIT' && t.status != 'FAILURE').toList();

    // Helper to normalize the merchant name for better grouping
    String normalize(String s) => s.toLowerCase().trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

    final Map<String, List<Transaction>> groupedByMerchant = {};
    for (var t in debits) {
      if (t.payeeName.isEmpty) continue;
      final normKey = normalize(t.payeeName);
      if (normKey.isNotEmpty) {
        groupedByMerchant.putIfAbsent(normKey, () => []).add(t);
      }
    }

    final List<SubscriptionModel> results = [];

    groupedByMerchant.forEach((normKey, list) {
      if (list.length < 2) return;

      // Group again exactly by amount (you could do a tolerance +/- a few cents)
      final Map<double, List<Transaction>> groupedByAmount = {};
      for (var t in list) {
        groupedByAmount.putIfAbsent(t.amount, () => []).add(t);
      }

      groupedByAmount.forEach((amount, amountList) {
        if (amountList.length < 2) return;

        // Sort chronological
        amountList.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        final List<int> diffDays = [];
        for (int i = 1; i < amountList.length; i++) {
          final diff = amountList[i].createdAt.difference(amountList[i - 1].createdAt).inDays;
          // Ignore same day duplicated logs
          if (diff > 2) {
            diffDays.add(diff);
          }
        }

        if (diffDays.isEmpty) return;

        // Calculate average day difference
        final double avgDiff = diffDays.fold(0, (sum, val) => sum + val) / diffDays.length;

        // Add variance check to prevent false positives? Let's keep it simple.
        String frequency = '';
        if (avgDiff >= 25 && avgDiff <= 35) {
          frequency = 'Monthly';
        } else if (avgDiff >= 355 && avgDiff <= 375) {
          frequency = 'Yearly';
        } else if (avgDiff >= 6 && avgDiff <= 8) {
          frequency = 'Weekly';
        }

        if (frequency.isNotEmpty) {
          final lastPayment = amountList.last;
          final lastDate = lastPayment.createdAt;
          DateTime nextDate;

          if (frequency == 'Monthly') {
            nextDate = DateTime(lastDate.year, lastDate.month + 1, lastDate.day);
          } else if (frequency == 'Yearly') {
            nextDate = DateTime(lastDate.year + 1, lastDate.month, lastDate.day);
          } else {
            nextDate = lastDate.add(const Duration(days: 7));
          }

          results.add(SubscriptionModel(
            merchantName: lastPayment.payeeName, // using unmodified name for UI
            amount: amount,
            frequency: frequency,
            nextExpectedPayment: nextDate,
            lastPaymentDate: lastDate,
          ));
        }
      });
    });

    results.sort((a, b) => a.amount.compareTo(b.amount));
    return results.reversed.toList(); // High spending to Low spending
  }
}
