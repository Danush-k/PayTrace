import 'package:flutter_test/flutter_test.dart';
import 'package:paytrace/core/utils/spending_prediction_engine.dart';

void main() {
  group('SpendingPredictionEngine', () {
    test('aggregateDailySpending sorts and indexes data', () {
      final daily = {
        DateTime(2026, 3, 5): 100.0,
        DateTime(2026, 3, 3): 150.0,
        DateTime(2026, 3, 4): 180.0,
      };

      final result = SpendingPredictionEngine.aggregateDailySpending(daily);

      expect(result.length, 3);
      expect(result[0].date, DateTime(2026, 3, 3));
      expect(result[0].cumulativeIndex, 0);
      expect(result[1].date, DateTime(2026, 3, 4));
      expect(result[1].cumulativeIndex, 1);
      expect(result[2].date, DateTime(2026, 3, 5));
      expect(result[2].cumulativeIndex, 2);
    });

    test('calculateEMA smooths spending data correctly', () {
      final dailyData = [
        DailySpending(date: DateTime(2026, 3, 1), amount: 100, cumulativeIndex: 0),
        DailySpending(date: DateTime(2026, 3, 2), amount: 200, cumulativeIndex: 1),
        DailySpending(date: DateTime(2026, 3, 3), amount: 150, cumulativeIndex: 2),
      ];

      final ema = SpendingPredictionEngine.calculateEMA(dailyData);

      expect(ema.length, 3);
      expect(ema[0], 100); // First value equals first data point
      expect(ema[1], 130); // EMA formula: 200*0.3 + 100*0.7 = 130
      expect(ema[2], closeTo(136, 1)); // (150*0.3) + (130*0.7) = 136
    });

    test('calculateLinearRegression detects spending trend', () {
      final dailyData = [
        DailySpending(date: DateTime(2026, 3, 1), amount: 100, cumulativeIndex: 0),
        DailySpending(date: DateTime(2026, 3, 2), amount: 150, cumulativeIndex: 1),
        DailySpending(date: DateTime(2026, 3, 3), amount: 180, cumulativeIndex: 2),
        DailySpending(date: DateTime(2026, 3, 4), amount: 210, cumulativeIndex: 3),
        DailySpending(date: DateTime(2026, 3, 5), amount: 230, cumulativeIndex: 4),
      ];

      // EMA smoothing
      final ema = SpendingPredictionEngine.calculateEMA(dailyData);

      final result = SpendingPredictionEngine.calculateLinearRegression(dailyData, ema);

      // Slope should be positive (increasing trend)
      expect(result.slope, greaterThan(0));
      // Intercept should be positive
      expect(result.intercept, greaterThan(0));
    });

    test('projectFutureSpending generates future predictions', () {
      final baseDate = DateTime(2026, 3, 10);
      const intercept = 100.0;
      const slope = 20.0;
      const daysAhead = 7;

      final projections = SpendingPredictionEngine.projectFutureSpending(
        baseDate,
        intercept,
        slope,
        daysAhead,
      );

      expect(projections.length, 7);
      expect(projections[0].date, DateTime(2026, 3, 11)); // Day 1 ahead
      expect(projections[0].amount, closeTo(120, 1)); // 100 + 20*1
      expect(projections[6].date, DateTime(2026, 3, 17)); // Day 7 ahead
      expect(projections[6].amount, closeTo(240, 1)); // 100 + 20*7
    });

    test('estimateMonthlyTotal projects end-of-month spending', () {
      final today = DateTime(2026, 3, 10);
      const currentMonthTotal = 5000.0;
      const dailyAverage = 500.0;

      final estimated = SpendingPredictionEngine.estimateMonthlyTotal(
        today,
        currentMonthTotal,
        dailyAverage,
      );

      // Days remaining: 31 - 10 + 1 = 22
      // Projected: 5000 + 500*22 = 16000
      expect(estimated, closeTo(16000, 1));
    });

    test('calculateBurnRate detects budget urgency levels', () {
      // Test case 1: Normal (< 70%)
      var burnRate = SpendingPredictionEngine.calculateBurnRate(
        totalSpentThisMonth: 2000,
        daysElapsed: 10,
        monthlyLimit: 5000,
        currentDailyAverage: 200,
      );
      expect(burnRate.urgency, BudgetUrgency.normal);
      expect(burnRate.spentPercentage, 40);

      // Test case 2: Medium (70-89%)
      burnRate = SpendingPredictionEngine.calculateBurnRate(
        totalSpentThisMonth: 3500,
        daysElapsed: 10,
        monthlyLimit: 5000,
        currentDailyAverage: 350,
      );
      expect(burnRate.urgency, BudgetUrgency.medium);
      expect(burnRate.spentPercentage, 70);

      // Test case 3: High (90+%)
      burnRate = SpendingPredictionEngine.calculateBurnRate(
        totalSpentThisMonth: 4700,
        daysElapsed: 10,
        monthlyLimit: 5000,
        currentDailyAverage: 470,
      );
      expect(burnRate.urgency, BudgetUrgency.high);
      expect(burnRate.spentPercentage, 94);

      // Test case 4: Critical (exceeded)
      burnRate = SpendingPredictionEngine.calculateBurnRate(
        totalSpentThisMonth: 5100,
        daysElapsed: 10,
        monthlyLimit: 5000,
        currentDailyAverage: 510,
      );
      expect(burnRate.urgency, BudgetUrgency.critical);
      expect(burnRate.isExceeded, true);
    });

    test('calculateBurnRate calculates days until limit', () {
      final burnRate = SpendingPredictionEngine.calculateBurnRate(
        totalSpentThisMonth: 2000,
        daysElapsed: 10,
        monthlyLimit: 5000,
        currentDailyAverage: 500,
      );

      // Days until limit: (5000 - 2000) / 500 = 6 days
      expect(burnRate.daysUntilLimit, 6.0);
    });

    test('generateWarnings creates warnings for high spending', () {
      final burnRate = BurnRateInfo(
        dailyAverage: 300,
        spentPercentage: 85,
        daysUntilLimit: 5,
        isExceeded: false,
        urgency: BudgetUrgency.high,
      );

      final warnings = SpendingPredictionEngine.generateWarnings(
        burnRate: burnRate,
        slope: 15, // Increasing trend
        monthlyLimit: 5000,
        projectedMonthlyTotal: 5200,
      );

      expect(warnings.isNotEmpty, true);
      expect(
        warnings.any((w) => w.message.contains('Budget')),
        true,
        reason: 'Should include budget warning',
      );
      expect(
        warnings.any((w) => w.message.contains('increasing')),
        true,
        reason: 'Should include trend warning for positive slope',
      );
    });

    test('generateWarnings detects spending decrease', () {
      final burnRate = BurnRateInfo(
        dailyAverage: 200,
        spentPercentage: 50,
        daysUntilLimit: null,
        isExceeded: false,
        urgency: BudgetUrgency.normal,
      );

      final warnings = SpendingPredictionEngine.generateWarnings(
        burnRate: burnRate,
        slope: -50, // Decreasing trend
        monthlyLimit: 5000,
        projectedMonthlyTotal: 4500,
      );

      expect(
        warnings.any((w) => w.message.contains('decreasing')),
        true,
        reason: 'Should include positive feedback for decreasing trend',
      );
    });

    test('SpendingPrediction contains all required data', () {
      final now = DateTime.now();
      final daily = [
        DailySpending(date: DateTime(2026, 3, 1), amount: 100, cumulativeIndex: 0),
        DailySpending(date: DateTime(2026, 3, 2), amount: 150, cumulativeIndex: 1),
      ];
      final ema = [100.0, 120.0];
      final projected = [
        DailySpending(date: DateTime(2026, 3, 3), amount: 140, cumulativeIndex: 0),
      ];
      final burnRate = BurnRateInfo(
        dailyAverage: 125,
        spentPercentage: 50,
        daysUntilLimit: 40,
        isExceeded: false,
        urgency: BudgetUrgency.normal,
      );

      final prediction = SpendingPrediction(
        generatedAt: now,
        historicalDaily: daily,
        emaSmoothed: ema,
        trendSlope: 25,
        trendIntercept: 75,
        currentMonthTotal: 250,
        averageDailySpend: 125,
        projectedMonthlyTotal: 3750,
        projectedDaily: projected,
        burnRate: burnRate,
        warnings: [],
      );

      expect(prediction.historicalDaily, daily);
      expect(prediction.emaSmoothed, ema);
      expect(prediction.trendSlope, 25);
      expect(prediction.projectedMonthlyTotal, 3750);
      expect(prediction.warnings.length, 0);
      expect(prediction.toString(), isNotEmpty);
    });

    test('Handles empty data gracefully', () {
      final daily = <DateTime, double>{};
      final result = SpendingPredictionEngine.aggregateDailySpending(daily);
      expect(result.isEmpty, true);

      final ema = SpendingPredictionEngine.calculateEMA([]);
      expect(ema.isEmpty, true);
    });

    test('Handles min data points requirement', () {
      final dailyData = [
        DailySpending(date: DateTime(2026, 3, 1), amount: 100, cumulativeIndex: 0),
      ];
      final ema = [100.0];

      // Should return (intercept: 0, slope: 0) for insufficient data
      final result = SpendingPredictionEngine.calculateLinearRegression(dailyData, ema);
      expect(result.intercept, 0);
      expect(result.slope, 0);
    });

    test('DailySpending copyWith works correctly', () {
      final original = DailySpending(
        date: DateTime(2026, 3, 1),
        amount: 100,
        cumulativeIndex: 0,
      );

      final copied = original.copyWith(amount: 200);

      expect(copied.date, original.date);
      expect(copied.amount, 200);
      expect(copied.cumulativeIndex, original.cumulativeIndex);
    });

    test('BurnRateInfo calculates correctly with null limit', () {
      final burnRate = SpendingPredictionEngine.calculateBurnRate(
        totalSpentThisMonth: 1000,
        daysElapsed: 10,
        monthlyLimit: null,
        currentDailyAverage: 100,
      );

      expect(burnRate.daysUntilLimit, isNull);
      expect(burnRate.spentPercentage, 0);
    });
  });
}
