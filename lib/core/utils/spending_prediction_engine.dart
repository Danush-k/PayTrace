import 'package:flutter/foundation.dart';

/// Lightweight on-device spending prediction engine using EMA + linear regression.
///
/// All calculations run locally in Dart. No external APIs required.
class SpendingPredictionEngine {
  SpendingPredictionEngine._();

  // Configuration
  static const double _emaAlpha = 0.3; // Smoothing factor for EMA
  static const int _minDataPoints = 5; // Minimum days needed for trend analysis

  // ════════════════════════════════════════════════════════════════════════════
  //  DATA AGGREGATION
  // ════════════════════════════════════════════════════════════════════════════

  /// Aggregate spending by date from a list of daily amounts.
  ///
  /// Returns a sorted list of (DateTime, daily_spent_amount) pairs.
  static List<DailySpending> aggregateDailySpending(
    Map<DateTime, double> dailyMap,
  ) {
    final entries = dailyMap.entries
        .map((e) => DailySpending(
              date: e.key,
              amount: e.value,
              cumulativeIndex: 0, // Will be set in sorting
            ))
        .toList();

    entries.sort((a, b) => a.date.compareTo(b.date));

    // Assign cumulative index for regression
    for (int i = 0; i < entries.length; i++) {
      entries[i] = entries[i].copyWith(cumulativeIndex: i);
    }

    debugPrint('[SPENDING_PREDICTION] aggregateDailySpending: ${entries.length} days');
    return entries;
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  EXPONENTIAL MOVING AVERAGE (EMA)
  // ════════════════════════════════════════════════════════════════════════════

  /// Calculate Exponential Moving Average (EMA) for smoothed spending curve.
  ///
  /// Formula: EMA_today = (spend_today × α) + (EMA_yesterday × (1 − α))
  /// Where α = 0.3 (30% weight on today's value, 70% on historical trend)
  static List<double> calculateEMA(List<DailySpending> dailyData) {
    if (dailyData.isEmpty) return [];

    final emaValues = <double>[];
    double prevEma = dailyData.first.amount;
    emaValues.add(prevEma);

    for (int i = 1; i < dailyData.length; i++) {
      final todaySpend = dailyData[i].amount;
      final ema = (todaySpend * _emaAlpha) + (prevEma * (1 - _emaAlpha));
      emaValues.add(ema);
      prevEma = ema;
    }

    debugPrint('[EMA_CALCULATED] EMA values: ${emaValues.length} points, '
        'last EMA: ₹${emaValues.last.toStringAsFixed(2)}');
    return emaValues;
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  LINEAR REGRESSION & TREND DETECTION
  // ════════════════════════════════════════════════════════════════════════════

  /// Perform linear regression: y = a + bx
  /// Returns (intercept, slope)
  static ({double intercept, double slope}) calculateLinearRegression(
    List<DailySpending> dailyData,
    List<double> emaValues,
  ) {
    if (dailyData.length < _minDataPoints || emaValues.length != dailyData.length) {
      return (intercept: 0, slope: 0);
    }

    // Use last 14 days for trend (or all if fewer available)
    final recentCount = dailyData.length > 14 ? 14 : dailyData.length;
    final startIdx = dailyData.length - recentCount;
    
    final recentData = dailyData.sublist(startIdx);
    final recentEma = emaValues.sublist(startIdx, startIdx + recentCount);

    final n = recentData.length;
    var sumX = 0.0;
    var sumY = 0.0;
    var sumXY = 0.0;
    var sumX2 = 0.0;

    for (int i = 0; i < n; i++) {
      final x = i.toDouble();
      final y = recentEma[i];
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }

    final meanX = sumX / n;
    final meanY = sumY / n;

    final numerator = sumXY - (n * meanX * meanY);
    final denominator = sumX2 - (n * meanX * meanX);

    final slope = denominator != 0 ? numerator / denominator : 0.0;
    final intercept = meanY - (slope * meanX);

    debugPrint('[TREND_SLOPE] Regression: intercept=${intercept.toStringAsFixed(2)}, '
        'slope=${slope.toStringAsFixed(2)} (₹/day)');
    return (intercept: intercept, slope: slope);
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  FUTURE SPENDING PROJECTION
  // ════════════════════════════════════════════════════════════════════════════

  /// Predict daily spending for the next N days using the regression model.
  ///
  /// Returns list of (date, predicted_amount) for each future day.
  static List<DailySpending> projectFutureSpending(
    DateTime baseDate,
    double intercept,
    double slope,
    int daysAhead,
  ) {
    final projections = <DailySpending>[];
    final today = DateTime(baseDate.year, baseDate.month, baseDate.day);

    // Start projecting from tomorrow
    for (int i = 1; i <= daysAhead; i++) {
      final futureDate = today.add(Duration(days: i));
      
      // Use the day index relative to today
      final dayIndex = i.toDouble();
      final predictedAmount = (intercept + (slope * dayIndex)).clamp(0.0, double.infinity);

      projections.add(DailySpending(
        date: futureDate,
        amount: predictedAmount,
        cumulativeIndex: 0, // Not used for projections
      ));
    }

    debugPrint(
      '[FUTURE_PREDICTION] Projected $daysAhead days. '
      'Day 1: ₹${projections.first.amount.toStringAsFixed(2)}, '
      'Day $daysAhead: ₹${projections.last.amount.toStringAsFixed(2)}',
    );
    return projections;
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  MONTHLY SPENDING ESTIMATE
  // ════════════════════════════════════════════════════════════════════════════

  /// Estimate end-of-month spending based on current trajectory.
  ///
  /// Formula:
  /// predicted_month_total = current_total + (average_daily × remaining_days)
  static double estimateMonthlyTotal(
    DateTime today,
    double currentMonthTotal,
    double averageDailySpend,
  ) {
    // Days remaining in month (including today)
    final lastDay = DateTime(today.year, today.month + 1, 0).day;
    final remaining = lastDay - today.day + 1;

    final projectedTotal = currentMonthTotal + (averageDailySpend * remaining);

    debugPrint(
      '[MONTHLY_ESTIMATE] Current: ₹${currentMonthTotal.toStringAsFixed(2)}, '
      'Average daily: ₹${averageDailySpend.toStringAsFixed(2)}, '
      'Days remaining: $remaining, '
      'Projected total: ₹${projectedTotal.toStringAsFixed(2)}',
    );
    return projectedTotal;
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  BURN RATE & LIMIT ANALYSIS
  // ════════════════════════════════════════════════════════════════════════════

  /// Calculate burn rate (average daily spending and days until limit exceeded).
  static BurnRateInfo calculateBurnRate({
    required double totalSpentThisMonth,
    required int daysElapsed,
    required double? monthlyLimit,
    required double currentDailyAverage,
  }) {
    if (daysElapsed <= 0 || monthlyLimit == null || monthlyLimit <= 0) {
      return BurnRateInfo(
        dailyAverage: currentDailyAverage,
        spentPercentage: 0,
        daysUntilLimit: null,
        isExceeded: false,
        urgency: BudgetUrgency.normal,
      );
    }

    final amountRemaining = monthlyLimit - totalSpentThisMonth;
    
    final isExceeded = totalSpentThisMonth >= monthlyLimit;
    final spentPercentage = (totalSpentThisMonth / monthlyLimit) * 100;

    // Days until limit is exceeded at current pace
    double? daysUntilLimit;
    if (currentDailyAverage > 0 && !isExceeded) {
      daysUntilLimit = amountRemaining / currentDailyAverage;
    }

    // Determine urgency level
    BudgetUrgency urgency;
    if (isExceeded) {
      urgency = BudgetUrgency.critical;
    } else if (spentPercentage >= 90) {
      urgency = BudgetUrgency.high;
    } else if (spentPercentage >= 70) {
      urgency = BudgetUrgency.medium;
    } else {
      urgency = BudgetUrgency.normal;
    }

    debugPrint(
      '[BURN_RATE] Daily avg: ₹${currentDailyAverage.toStringAsFixed(2)}, '
      'Spent: ${spentPercentage.toStringAsFixed(1)}% of limit, '
      'Days until limit: ${daysUntilLimit?.toStringAsFixed(1) ?? "N/A"}, '
      'Urgency: $urgency',
    );

    return BurnRateInfo(
      dailyAverage: currentDailyAverage,
      spentPercentage: spentPercentage,
      daysUntilLimit: daysUntilLimit,
      isExceeded: isExceeded,
      urgency: urgency,
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  WARNING GENERATION
  // ════════════════════════════════════════════════════════════════════════════

  /// Generate actionable warning messages for the user.
  static List<SpendingWarning> generateWarnings({
    required BurnRateInfo burnRate,
    required double slope, // Trend slope in ₹/day
    required double? monthlyLimit,
    required double projectedMonthlyTotal,
  }) {
    final warnings = <SpendingWarning>[];

    // Budget exceed warning
    if (burnRate.isExceeded) {
      warnings.add(SpendingWarning(
        severity: WarningLevel.critical,
        message: '⚠️ You have exceeded your monthly budget!',
        actionable:
            'Current spending: ₹${projectedMonthlyTotal.toStringAsFixed(0)}',
      ));
    } else if (burnRate.daysUntilLimit != null && burnRate.daysUntilLimit! < 7) {
      final daysStr = burnRate.daysUntilLimit!.toStringAsFixed(0);
      warnings.add(SpendingWarning(
        severity: WarningLevel.high,
        message: '⚠️ Budget limit in ~$daysStr days',
        actionable:
            'At your current pace (₹${burnRate.dailyAverage.toStringAsFixed(0)}/day), '
            'you may exceed ₹${monthlyLimit?.toStringAsFixed(0)} soon.',
      ));
    } else if (burnRate.spentPercentage >= 75) {
      warnings.add(SpendingWarning(
        severity: WarningLevel.medium,
        message: '📊 75% of budget used',
        actionable: 'You are on track to spend ₹${projectedMonthlyTotal.toStringAsFixed(0)} '
            'by month end.',
      ));
    }

    // Trend warnings
    if (slope > 10) {
      // Spending increasing by >₹10/day consistently
      final increase = (slope * 7).toStringAsFixed(0); // Weekly increase
      warnings.add(SpendingWarning(
        severity: WarningLevel.medium,
        message: '📈 Your spending is increasing',
        actionable: 'Your weekly spend increased by ₹$increase. '
            'Consider reviewing recent transactions.',
      ));
    } else if (slope < -30) {
      // Spending decreasing — positive signal
      warnings.add(SpendingWarning(
        severity: WarningLevel.info,
        message: '✨ Great! Your spending is decreasing',
        actionable: 'Keep up your spending discipline. You are on a positive track.',
      ));
    }

    return warnings;
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  DATA MODELS
// ════════════════════════════════════════════════════════════════════════════

/// Daily spending data point
class DailySpending {
  final DateTime date;
  final double amount; // ₹
  final int cumulativeIndex; // 0-based index in sorted list

  DailySpending({
    required this.date,
    required this.amount,
    required this.cumulativeIndex,
  });

  DailySpending copyWith({
    DateTime? date,
    double? amount,
    int? cumulativeIndex,
  }) {
    return DailySpending(
      date: date ?? this.date,
      amount: amount ?? this.amount,
      cumulativeIndex: cumulativeIndex ?? this.cumulativeIndex,
    );
  }

  @override
  String toString() => 'DailySpending($date: ₹${amount.toStringAsFixed(2)})';
}

/// Burn rate analysis
class BurnRateInfo {
  final double dailyAverage;
  final double spentPercentage; // 0-100
  final double? daysUntilLimit; // null if already exceeded or no limit
  final bool isExceeded;
  final BudgetUrgency urgency;

  BurnRateInfo({
    required this.dailyAverage,
    required this.spentPercentage,
    required this.daysUntilLimit,
    required this.isExceeded,
    required this.urgency,
  });

  @override
  String toString() => 'BurnRateInfo(daily: ₹${dailyAverage.toStringAsFixed(2)}, '
      'spent: ${spentPercentage.toStringAsFixed(1)}%, '
      'daysUntilLimit: $daysUntilLimit, urgency: $urgency)';
}

/// Budget urgency level
enum BudgetUrgency {
  normal, // < 70%
  medium, // 70-89%
  high, // 90+%
  critical, // Exceeded
}

/// Spending warning for user
class SpendingWarning {
  final WarningLevel severity;
  final String message; // Main warning message
  final String actionable; // Actionable insight

  SpendingWarning({
    required this.severity,
    required this.message,
    required this.actionable,
  });

  @override
  String toString() => '$severity: $message → $actionable';
}

/// Warning severity level
enum WarningLevel {
  info, // Positive feedback
  medium, // Caution
  high, // Alert
  critical, // Urgent action needed
}

/// Comprehensive spending prediction snapshot
class SpendingPrediction {
  final DateTime generatedAt;
  
  // Historical analysis
  final List<DailySpending> historicalDaily;
  final List<double> emaSmoothed;
  
  // Trend analysis
  final double trendSlope; // ₹/day
  final double trendIntercept;
  
  // Current month analysis
  final double currentMonthTotal;
  final double averageDailySpend;
  
  // Future projections
  final double projectedMonthlyTotal;
  final List<DailySpending> projectedDaily; // Next 14 days
  
  // Budget analysis
  final BurnRateInfo burnRate;
  
  // Warnings
  final List<SpendingWarning> warnings;

  SpendingPrediction({
    required this.generatedAt,
    required this.historicalDaily,
    required this.emaSmoothed,
    required this.trendSlope,
    required this.trendIntercept,
    required this.currentMonthTotal,
    required this.averageDailySpend,
    required this.projectedMonthlyTotal,
    required this.projectedDaily,
    required this.burnRate,
    required this.warnings,
  });

  @override
  String toString() => 'SpendingPrediction('
      'current: ₹${currentMonthTotal.toStringAsFixed(0)}, '
      'projected: ₹${projectedMonthlyTotal.toStringAsFixed(0)}, '
      'trend: ${trendSlope > 0 ? "📈" : "📉"} ${trendSlope.toStringAsFixed(1)}₹/day, '
      'warnings: ${warnings.length}'
      ')';
}
