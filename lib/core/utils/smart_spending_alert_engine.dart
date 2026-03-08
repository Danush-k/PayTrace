import '../../core/constants/app_constants.dart';
import '../../data/database/app_database.dart';

class SmartSpendingAlert {
  final String title;
  final String message;
  final String icon;
  final int priority;

  const SmartSpendingAlert({
    required this.title,
    required this.message,
    required this.icon,
    required this.priority,
  });
}

class SmartSpendingAlertEngine {
  SmartSpendingAlertEngine._();

  static List<SmartSpendingAlert> analyze({
    required List<Transaction> transactions,
    required DateTime referenceDate,
  }) {
    final debits = transactions
        .where((t) =>
            t.direction == 'DEBIT' && t.status == AppConstants.statusSuccess)
        .toList();

    if (debits.isEmpty) return const [];

    final today = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );

    final alerts = <SmartSpendingAlert>[];

    _addFoodWeeklyIncreaseAlert(alerts, debits, today);
    _addFoodFrequencyAlert(alerts, debits, today);
    _addLateNightSpendingAlert(alerts, debits, today);

    alerts.sort((a, b) => a.priority.compareTo(b.priority));
    return alerts;
  }

  static void _addFoodWeeklyIncreaseAlert(
    List<SmartSpendingAlert> alerts,
    List<Transaction> debits,
    DateTime today,
  ) {
    final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
    final lastWeekEnd = thisWeekStart.subtract(const Duration(days: 1));

    double thisWeekFood = 0;
    double lastWeekFood = 0;

    for (final txn in debits) {
      if (!_isFood(txn.category)) continue;

      final day = DateTime(
        txn.createdAt.year,
        txn.createdAt.month,
        txn.createdAt.day,
      );

      if (!day.isBefore(thisWeekStart) && !day.isAfter(today)) {
        thisWeekFood += txn.amount;
      } else if (!day.isBefore(lastWeekStart) && !day.isAfter(lastWeekEnd)) {
        lastWeekFood += txn.amount;
      }
    }

    if (lastWeekFood <= 0) return;

    final increasePct = ((thisWeekFood - lastWeekFood) / lastWeekFood) * 100;
    if (increasePct < 30) return;

    alerts.add(
      SmartSpendingAlert(
        title: 'Food spending is up',
        message:
            'Food spending increased by ${increasePct.toStringAsFixed(0)}% compared to last week.',
        icon: '🍔',
        priority: 1,
      ),
    );
  }

  static void _addFoodFrequencyAlert(
    List<SmartSpendingAlert> alerts,
    List<Transaction> debits,
    DateTime today,
  ) {
    final start = today.subtract(const Duration(days: 2)); // last 3 days incl. today

    var count = 0;
    for (final txn in debits) {
      if (!_isFood(txn.category)) continue;
      final day = DateTime(
        txn.createdAt.year,
        txn.createdAt.month,
        txn.createdAt.day,
      );
      if (!day.isBefore(start) && !day.isAfter(today)) {
        count++;
      }
    }

    if (count <= 5) return;

    alerts.add(
      SmartSpendingAlert(
        title: 'Frequent food purchases',
        message: 'You made $count food purchases in the last 3 days.',
        icon: '🛍️',
        priority: 2,
      ),
    );
  }

  static void _addLateNightSpendingAlert(
    List<SmartSpendingAlert> alerts,
    List<Transaction> debits,
    DateTime today,
  ) {
    final recentStart = today.subtract(const Duration(days: 6));
    final baselineStart = today.subtract(const Duration(days: 34));
    final baselineEnd = today.subtract(const Duration(days: 7));

    double recentTotal = 0;
    double recentLate = 0;
    int recentLateCount = 0;

    double baselineTotal = 0;
    double baselineLate = 0;

    for (final txn in debits) {
      final day = DateTime(
        txn.createdAt.year,
        txn.createdAt.month,
        txn.createdAt.day,
      );
      final isLate = txn.createdAt.hour >= 22;

      if (!day.isBefore(recentStart) && !day.isAfter(today)) {
        recentTotal += txn.amount;
        if (isLate) {
          recentLate += txn.amount;
          recentLateCount++;
        }
        continue;
      }

      if (!day.isBefore(baselineStart) && !day.isAfter(baselineEnd)) {
        baselineTotal += txn.amount;
        if (isLate) {
          baselineLate += txn.amount;
        }
      }
    }

    if (recentLateCount < 3 || recentTotal <= 0) return;

    final recentRatio = recentLate / recentTotal;

    if (baselineTotal > 0) {
      final baselineRatio = baselineLate / baselineTotal;
      final exceedsNormal =
          recentRatio > baselineRatio * 1.3 && (recentRatio - baselineRatio) > 0.08;

      if (!exceedsNormal) return;

      alerts.add(
        SmartSpendingAlert(
          title: 'Late-night spending spike',
          message:
              'Spending after 10 PM is ${(recentRatio * 100).toStringAsFixed(0)}% recently vs ${(baselineRatio * 100).toStringAsFixed(0)}% normally.',
          icon: '🌙',
          priority: 3,
        ),
      );
      return;
    }

    if (recentLate >= 1000) {
      alerts.add(
        const SmartSpendingAlert(
          title: 'Late-night spending spike',
          message:
              'Spending after 10 PM is unusually high in the last 7 days.',
          icon: '🌙',
          priority: 3,
        ),
      );
    }
  }

  static bool _isFood(String category) {
    final normalized = category.toLowerCase();
    return normalized.contains('food') || normalized.contains('dining');
  }
}
