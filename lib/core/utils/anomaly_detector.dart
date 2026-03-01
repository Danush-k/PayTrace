import 'dart:math';
import '../../data/database/app_database.dart';
import '../constants/app_constants.dart';

/// Anomaly / Fraud Detection Engine — uses z-score based outlier detection
/// to flag unusual transactions based on historical spending patterns.
///
/// Detects:
/// 1. Category spikes (amount >> historical avg for that category)
/// 2. Unusual hours (large transaction at 9 PM–6 AM)
/// 3. Large transactions to new payees
/// 4. Single-transaction outliers vs user's overall median
class AnomalyDetector {
  AnomalyDetector._();

  /// Detect anomalies in current month's transactions using historical context.
  static AnomalyResult detect({
    required List<Transaction> currentMonthTxns,
    required List<List<Transaction>> previousMonthsTxns,
  }) {
    final alerts = <AnomalyAlert>[];

    final currentDebits = currentMonthTxns
        .where((t) => t.status == 'SUCCESS' && t.direction == 'DEBIT')
        .toList();

    if (currentDebits.isEmpty) {
      return const AnomalyResult(alerts: [], riskScore: 0);
    }

    // Build historical stats per category
    final histCategoryStats = _buildCategoryStats(previousMonthsTxns);
    // Build overall historical stats
    final histOverallStats = _buildOverallStats(previousMonthsTxns);
    // Known payees from history
    final knownPayees = _collectKnownPayees(previousMonthsTxns);

    for (final txn in currentDebits) {
      // 1. Category spike detection
      _checkCategorySpike(txn, histCategoryStats, alerts);

      // 2. Unusual time detection
      _checkUnusualTime(txn, alerts);

      // 3. New payee large amount
      _checkNewPayeeLargeAmount(txn, knownPayees, histOverallStats, alerts);

      // 4. Overall amount outlier
      _checkAmountOutlier(txn, histOverallStats, alerts);
    }

    // Deduplicate — keep highest severity per transaction
    final deduped = <String, AnomalyAlert>{};
    for (final a in alerts) {
      final existing = deduped[a.transactionId];
      if (existing == null || a.severity > existing.severity) {
        deduped[a.transactionId] = a;
      }
    }

    final finalAlerts = deduped.values.toList()
      ..sort((a, b) => b.severity.compareTo(a.severity));

    // Risk score — 0 to 100 based on anomaly count and severity
    final riskScore = finalAlerts.isEmpty
        ? 0
        : (finalAlerts.fold<double>(0, (s, a) => s + a.severity) /
                finalAlerts.length *
                20)
            .round()
            .clamp(0, 100);

    return AnomalyResult(
      alerts: finalAlerts.take(8).toList(),
      riskScore: riskScore,
    );
  }

  /// Build mean + stdDev per category from historical data.
  static Map<String, _Stats> _buildCategoryStats(
      List<List<Transaction>> prevMonths) {
    final categoryAmounts = <String, List<double>>{};

    for (final monthTxns in prevMonths) {
      for (final t in monthTxns) {
        if (t.status == 'SUCCESS' && t.direction == 'DEBIT') {
          categoryAmounts.putIfAbsent(t.category, () => []).add(t.amount);
        }
      }
    }

    return categoryAmounts.map((cat, amounts) => MapEntry(cat, _Stats.from(amounts)));
  }

  /// Build overall transaction amount stats from historical data.
  static _Stats _buildOverallStats(List<List<Transaction>> prevMonths) {
    final amounts = <double>[];
    for (final monthTxns in prevMonths) {
      for (final t in monthTxns) {
        if (t.status == 'SUCCESS' && t.direction == 'DEBIT') {
          amounts.add(t.amount);
        }
      }
    }
    return _Stats.from(amounts);
  }

  /// Collect all payee UPI IDs seen historically.
  static Set<String> _collectKnownPayees(List<List<Transaction>> prevMonths) {
    final payees = <String>{};
    for (final monthTxns in prevMonths) {
      for (final t in monthTxns) {
        payees.add(t.payeeUpiId.toLowerCase());
      }
    }
    return payees;
  }

  /// Check if a txn's amount is anomalous for its category.
  static void _checkCategorySpike(
    Transaction txn,
    Map<String, _Stats> catStats,
    List<AnomalyAlert> alerts,
  ) {
    final stats = catStats[txn.category];
    if (stats == null || stats.count < 3) return;

    final zScore = stats.stdDev > 0
        ? (txn.amount - stats.mean) / stats.stdDev
        : 0.0;

    if (zScore > 2.0 && txn.amount > 500 && txn.amount > stats.mean * 1.8) {
      alerts.add(AnomalyAlert(
        transactionId: txn.id,
        payeeName: txn.payeeName,
        amount: txn.amount,
        category: txn.category,
        alertType: AnomalyType.categorySpike,
        severity: (zScore.clamp(2, 5) - 1).round(),
        message:
            '${AppConstants.currencySymbol}${txn.amount.toStringAsFixed(0)} on ${txn.category} is '
            '${zScore.toStringAsFixed(1)}x above your usual '
            '${AppConstants.currencySymbol}${stats.mean.toStringAsFixed(0)} avg.',
        expectedMax: stats.mean + stats.stdDev,
        zScore: zScore,
        timestamp: txn.createdAt,
      ));
    }
  }

  /// Check if transaction happened at unusual hours with large amount.
  static void _checkUnusualTime(
    Transaction txn,
    List<AnomalyAlert> alerts,
  ) {
    final hour = txn.createdAt.hour;
    final isLateNight = hour >= 23 || hour < 5;

    if (isLateNight && txn.amount >= 2000) {
      alerts.add(AnomalyAlert(
        transactionId: txn.id,
        payeeName: txn.payeeName,
        amount: txn.amount,
        category: txn.category,
        alertType: AnomalyType.unusualTime,
        severity: 2,
        message:
            '${AppConstants.currencySymbol}${txn.amount.toStringAsFixed(0)} to ${txn.payeeName} '
            'at ${txn.createdAt.hour}:${txn.createdAt.minute.toString().padLeft(2, '0')} — late-night transactions '
            'are often impulsive.',
        expectedMax: 0,
        zScore: 0,
        timestamp: txn.createdAt,
      ));
    }
  }

  /// Flag large transactions to payees never seen before.
  static void _checkNewPayeeLargeAmount(
    Transaction txn,
    Set<String> knownPayees,
    _Stats overallStats,
    List<AnomalyAlert> alerts,
  ) {
    if (knownPayees.isEmpty) return;

    final isNew = !knownPayees.contains(txn.payeeUpiId.toLowerCase());
    final threshold = overallStats.count > 0
        ? overallStats.mean + overallStats.stdDev
        : 5000;

    if (isNew && txn.amount > threshold && txn.amount > 1000) {
      alerts.add(AnomalyAlert(
        transactionId: txn.id,
        payeeName: txn.payeeName,
        amount: txn.amount,
        category: txn.category,
        alertType: AnomalyType.newPayeeLargeAmount,
        severity: 3,
        message:
            'First-time payment of ${AppConstants.currencySymbol}${txn.amount.toStringAsFixed(0)} '
            'to ${txn.payeeName}. This is above your usual transaction range.',
        expectedMax: threshold.toDouble(),
        zScore: 0,
        timestamp: txn.createdAt,
      ));
    }
  }

  /// Check if a single transaction is an extreme outlier vs all historical.
  static void _checkAmountOutlier(
    Transaction txn,
    _Stats overallStats,
    List<AnomalyAlert> alerts,
  ) {
    if (overallStats.count < 5) return;

    final zScore = overallStats.stdDev > 0
        ? (txn.amount - overallStats.mean) / overallStats.stdDev
        : 0.0;

    if (zScore > 3.0 && txn.amount > 2000) {
      alerts.add(AnomalyAlert(
        transactionId: txn.id,
        payeeName: txn.payeeName,
        amount: txn.amount,
        category: txn.category,
        alertType: AnomalyType.highAmount,
        severity: (zScore.clamp(3, 5)).round(),
        message:
            '${AppConstants.currencySymbol}${txn.amount.toStringAsFixed(0)} is significantly higher '
            'than your typical ${AppConstants.currencySymbol}${overallStats.mean.toStringAsFixed(0)} transaction.',
        expectedMax: overallStats.mean + 2 * overallStats.stdDev,
        zScore: zScore,
        timestamp: txn.createdAt,
      ));
    }
  }
}

// ─── Helper: simple statistics ───

class _Stats {
  final double mean;
  final double stdDev;
  final double median;
  final int count;

  const _Stats({
    required this.mean,
    required this.stdDev,
    required this.median,
    required this.count,
  });

  factory _Stats.from(List<double> values) {
    if (values.isEmpty) {
      return const _Stats(mean: 0, stdDev: 0, median: 0, count: 0);
    }

    final n = values.length;
    final mean = values.fold<double>(0, (s, v) => s + v) / n;
    final variance = values.fold<double>(0, (s, v) => s + (v - mean) * (v - mean)) / n;
    final stdDev = sqrt(variance);

    final sorted = [...values]..sort();
    final median = n.isOdd ? sorted[n ~/ 2] : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;

    return _Stats(mean: mean, stdDev: stdDev, median: median, count: n);
  }
}

// ─── Result Models ───

enum AnomalyType {
  categorySpike,
  unusualTime,
  newPayeeLargeAmount,
  highAmount,
}

class AnomalyAlert {
  final String transactionId;
  final String payeeName;
  final double amount;
  final String category;
  final AnomalyType alertType;
  final int severity; // 1–5
  final String message;
  final double expectedMax;
  final double zScore;
  final DateTime timestamp;

  const AnomalyAlert({
    required this.transactionId,
    required this.payeeName,
    required this.amount,
    required this.category,
    required this.alertType,
    required this.severity,
    required this.message,
    required this.expectedMax,
    required this.zScore,
    required this.timestamp,
  });

  String get icon => switch (alertType) {
        AnomalyType.categorySpike => '📊',
        AnomalyType.unusualTime => '🌙',
        AnomalyType.newPayeeLargeAmount => '👤',
        AnomalyType.highAmount => '⚠️',
      };

  String get title => switch (alertType) {
        AnomalyType.categorySpike => 'Unusual $category Spend',
        AnomalyType.unusualTime => 'Late-Night Transaction',
        AnomalyType.newPayeeLargeAmount => 'New Payee Alert',
        AnomalyType.highAmount => 'Unusually Large Payment',
      };
}

class AnomalyResult {
  final List<AnomalyAlert> alerts;
  final int riskScore; // 0–100

  const AnomalyResult({
    required this.alerts,
    required this.riskScore,
  });

  bool get hasAnomalies => alerts.isNotEmpty;
}
