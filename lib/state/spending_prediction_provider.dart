import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/spending_prediction_engine.dart';
import 'providers.dart';

/// Spending prediction for the current month.
/// Recomputes whenever transactions change.
final spendingPredictionProvider =
    FutureProvider.autoDispose<SpendingPrediction>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();

  // Get daily spending for this month
  final dailySpendingByDay = await db.getDailySpending(now.year, now.month);
  if (dailySpendingByDay.isEmpty) {
    // Not enough data yet
    return SpendingPrediction(
      generatedAt: now,
      historicalDaily: [],
      emaSmoothed: [],
      trendSlope: 0,
      trendIntercept: 0,
      currentMonthTotal: 0,
      averageDailySpend: 0,
      projectedMonthlyTotal: 0,
      projectedDaily: [],
      burnRate: BurnRateInfo(
        dailyAverage: 0,
        spentPercentage: 0,
        daysUntilLimit: null,
        isExceeded: false,
        urgency: BudgetUrgency.normal,
      ),
      warnings: [],
    );
  }

  // Convert Map<int, double> (day of month) to Map<DateTime, double>
  final dailySpending = <DateTime, double>{};
  dailySpendingByDay.forEach((dayOfMonth, amount) {
    final date = DateTime(now.year, now.month, dayOfMonth);
    dailySpending[date] = amount;
  });

  // 1. Aggregate daily spending
  final aggregated = SpendingPredictionEngine.aggregateDailySpending(dailySpending);

  // 2. Calculate EMA (smoothed spending curve)
  final ema = SpendingPredictionEngine.calculateEMA(aggregated);

  // 3. Calculate trend (linear regression)
  final (:intercept, :slope) =
      SpendingPredictionEngine.calculateLinearRegression(aggregated, ema);

  // 4. Project future spending (next 14 days)
  final projectedDaily =
      SpendingPredictionEngine.projectFutureSpending(now, intercept, slope, 14);

  // 5. Calculate current month total
  final currentMonthTotal = dailySpendingByDay.values.fold<double>(
    0,
    (sum, amount) => sum + amount,
  );

  // 6. Calculate average daily spend
  final daysWithTransactions = aggregated.length;
  final averageDailySpend = daysWithTransactions > 0
      ? currentMonthTotal / daysWithTransactions.toDouble()
      : 0.0;

  // 7. Estimate projected monthly total
  final projectedMonthlyTotal =
      SpendingPredictionEngine.estimateMonthlyTotal(
    now,
    currentMonthTotal,
    averageDailySpend,
  );

  // 8. Get budget limit for this month
  final budget = await db.getBudget(now.year, now.month);
  final monthlyLimit = budget?.limitAmount;

  // 9. Calculate burn rate
  final daysElapsed = now.day;
  final burnRate = SpendingPredictionEngine.calculateBurnRate(
    totalSpentThisMonth: currentMonthTotal,
    daysElapsed: daysElapsed,
    monthlyLimit: monthlyLimit,
    currentDailyAverage: averageDailySpend,
  );

  // 10. Generate warnings
  final warnings = SpendingPredictionEngine.generateWarnings(
    burnRate: burnRate,
    slope: slope,
    monthlyLimit: monthlyLimit,
    projectedMonthlyTotal: projectedMonthlyTotal,
  );

  return SpendingPrediction(
    generatedAt: now,
    historicalDaily: aggregated,
    emaSmoothed: ema,
    trendSlope: slope,
    trendIntercept: intercept,
    currentMonthTotal: currentMonthTotal,
    averageDailySpend: averageDailySpend,
    projectedMonthlyTotal: projectedMonthlyTotal,
    projectedDaily: projectedDaily,
    burnRate: burnRate,
    warnings: warnings,
  );
});
