import '../../core/constants/app_constants.dart';
import '../../data/database/app_database.dart';
import 'spending_insights_engine.dart';

/// Template-based analytical insight generator.
///
/// Generates clear, statistic-backed statements from real transaction data.
class InsightGenerator {
  InsightGenerator._();

  /// Generate a prioritized list of analytical insight strings.
  static List<Insight> generate({
    required List<Transaction> transactions,
    required SpendingInsightsResult spendingInsights,
    required DateTime referenceDate,
  }) {
    final insights = <Insight>[];

    final debits = transactions
        .where((t) => t.direction == 'DEBIT' && t.status == AppConstants.statusSuccess)
        .toList();
    if (debits.isEmpty) return insights;

    _addCategoryDistribution(insights, spendingInsights.categoryDistribution);
    _addTopMerchantThisWeek(insights, debits, referenceDate);
    _addDailyAverage(insights, spendingInsights.dailyAverage);
    _addPeakSpendingTime(insights, spendingInsights.timeOfDay);
    _addWeekendVsWeekday(insights, debits);

    // Sort by priority (lower = more important)
    insights.sort((a, b) => a.priority.compareTo(b.priority));

    return insights;
  }

  static void _addCategoryDistribution(
    List<Insight> insights,
    CategoryDistributionInsight categoryDistribution,
  ) {
    final top = categoryDistribution.topCategory;
    if (top == null || categoryDistribution.totalSpent <= 0) return;

    insights.add(
      Insight(
        icon: '📊',
        title: 'Category Distribution',
        message:
            '${top.category} accounts for ${top.percentage.toStringAsFixed(0)}% of your spending this month.',
        priority: 1,
        type: InsightType.info,
      ),
    );
  }

  static void _addTopMerchantThisWeek(
    List<Insight> insights,
    List<Transaction> debits,
    DateTime referenceDate,
  ) {
    final today = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    final weeklyTxns = debits
        .where((t) {
          final day = DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day);
          return !day.isBefore(weekStart) && !day.isAfter(today);
        })
        .toList();

    if (weeklyTxns.isEmpty) return;

    final merchantSpend = <String, double>{};
    for (final txn in weeklyTxns) {
      final merchant = txn.payeeName.trim().isNotEmpty
          ? txn.payeeName.trim()
          : txn.payeeUpiId.trim();
      merchantSpend.update(
        merchant,
        (value) => value + txn.amount,
        ifAbsent: () => txn.amount,
      );
    }

    final top = merchantSpend.entries.reduce((a, b) => a.value >= b.value ? a : b);
    insights.add(
      Insight(
        icon: '🏪',
        title: 'Top Merchant This Week',
        message:
            'You spent ${AppConstants.currencySymbol}${top.value.toStringAsFixed(0)} at ${top.key} this week.',
        priority: 2,
        type: InsightType.info,
      ),
    );
  }

  static void _addDailyAverage(
    List<Insight> insights,
    DailyAverageInsight dailyAverage,
  ) {
    insights.add(
      Insight(
        icon: '📅',
        title: 'Daily Spending Average',
        message:
            'Your average daily spending is ${AppConstants.currencySymbol}${dailyAverage.averagePerDay.toStringAsFixed(0)} this month.',
        priority: 3,
        type: InsightType.info,
      ),
    );
  }

  static void _addPeakSpendingTime(
    List<Insight> insights,
    TimeOfDayInsight timeOfDay,
  ) {
    if (timeOfDay.hourlyBreakdown.isEmpty || timeOfDay.totalSpent <= 0) return;

    int bestStart = 0;
    double bestTotal = -1;
    for (int start = 0; start <= 21; start++) {
      final total = timeOfDay.hourlyBreakdown
          .where((entry) => entry.hour >= start && entry.hour <= start + 2)
          .fold<double>(0, (sum, entry) => sum + entry.totalAmount);
      if (total > bestTotal) {
        bestTotal = total;
        bestStart = start;
      }
    }

    final startLabel = _hourLabel(bestStart);
    final endLabel = _hourLabel(bestStart + 3);
    insights.add(
      Insight(
        icon: '🕒',
        title: 'Peak Spending Time',
        message: 'Most spending occurs between $startLabel and $endLabel.',
        priority: 4,
        type: InsightType.info,
      ),
    );
  }

  static void _addWeekendVsWeekday(
    List<Insight> insights,
    List<Transaction> debits,
  ) {
    double weekendTotal = 0;
    double weekdayTotal = 0;
    final weekendDays = <DateTime>{};
    final weekdayDays = <DateTime>{};

    for (final txn in debits) {
      final day = DateTime(txn.createdAt.year, txn.createdAt.month, txn.createdAt.day);
      final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
      if (isWeekend) {
        weekendTotal += txn.amount;
        weekendDays.add(day);
      } else {
        weekdayTotal += txn.amount;
        weekdayDays.add(day);
      }
    }

    if (weekendTotal == 0 && weekdayTotal == 0) return;

    final weekendAvg = weekendDays.isNotEmpty ? weekendTotal / weekendDays.length : 0;
    final weekdayAvg = weekdayDays.isNotEmpty ? weekdayTotal / weekdayDays.length : 0;

    final message = weekendAvg > weekdayAvg
        ? 'Weekend average spend is ${AppConstants.currencySymbol}${weekendAvg.toStringAsFixed(0)} per day vs ${AppConstants.currencySymbol}${weekdayAvg.toStringAsFixed(0)} on weekdays.'
        : 'Weekday average spend is ${AppConstants.currencySymbol}${weekdayAvg.toStringAsFixed(0)} per day vs ${AppConstants.currencySymbol}${weekendAvg.toStringAsFixed(0)} on weekends.';

    insights.add(
      Insight(
        icon: '📆',
        title: 'Weekend vs Weekday Spending',
        message: message,
        priority: 5,
        type: InsightType.info,
      ),
    );
  }

  static String _hourLabel(int hour24) {
    final normalized = hour24 % 24;
    if (normalized == 0) return '12 AM';
    if (normalized < 12) return '$normalized AM';
    if (normalized == 12) return '12 PM';
    return '${normalized - 12} PM';
  }
}

enum InsightType { warning, tip, positive, info }

class Insight {
  final String icon;
  final String title;
  final String message;
  final int priority; // lower = more important
  final InsightType type;

  const Insight({
    required this.icon,
    required this.title,
    required this.message,
    required this.priority,
    required this.type,
  });
}
