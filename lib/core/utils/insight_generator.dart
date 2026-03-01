import '../../core/constants/app_constants.dart';
import 'spend_velocity_engine.dart';
import 'discipline_score_engine.dart';
import 'category_drift_engine.dart';
import 'anomaly_detector.dart';

/// Template-based Natural Language Generation engine.
/// Converts ML/analysis outputs into human-readable insight tips.
class InsightGenerator {
  InsightGenerator._();

  /// Generate a prioritized list of insight strings from all engine outputs.
  static List<Insight> generate({
    required SpendVelocityResult velocity,
    required DisciplineScoreResult discipline,
    required CategoryDriftResult drift,
    AnomalyResult? anomalies,
  }) {
    final insights = <Insight>[];

    // ── Anomaly alerts (highest priority) ──
    if (anomalies != null) {
      _addAnomalyInsights(insights, anomalies);
    }

    // ── Spend velocity insights ──
    _addVelocityInsights(insights, velocity);

    // ── Discipline score insights ──
    _addDisciplineInsights(insights, discipline);

    // ── Category drift alerts ──
    _addDriftInsights(insights, drift);

    // ── Time-of-day insights ──
    _addTimeInsights(insights, drift);

    // Sort by priority (lower = more important)
    insights.sort((a, b) => a.priority.compareTo(b.priority));

    return insights;
  }

  static void _addAnomalyInsights(
      List<Insight> insights, AnomalyResult anomalies) {
    if (anomalies.alerts.isEmpty) return;

    // Overall risk score insight
    if (anomalies.riskScore >= 60) {
      insights.add(Insight(
        icon: '🚨',
        title: 'High Risk Score: ${anomalies.riskScore}',
        message:
            'Multiple unusual transactions detected this month. Review flagged items below.',
        priority: 0,
        type: InsightType.warning,
      ));
    } else if (anomalies.riskScore >= 30) {
      insights.add(Insight(
        icon: '⚡',
        title: 'Some Unusual Activity',
        message:
            '${anomalies.alerts.length} transaction(s) flagged as unusual. Risk score: ${anomalies.riskScore}/100.',
        priority: 2,
        type: InsightType.warning,
      ));
    }

    // Top 3 individual alerts
    final topAlerts = anomalies.alerts.take(3);
    for (final alert in topAlerts) {
      insights.add(Insight(
        icon: alert.icon,
        title: alert.title,
        message: alert.message,
        priority: alert.severity <= 3 ? 1 : 4,
        type: alert.severity <= 2 ? InsightType.warning : InsightType.info,
      ));
    }
  }

  static void _addVelocityInsights(
      List<Insight> insights, SpendVelocityResult v) {
    if (v.totalSoFar == 0) return;

    // Budget overshoot warning
    if (v.willExceedBudget && v.budgetLimit != null) {
      insights.add(Insight(
        icon: '⚠️',
        title: 'Budget Alert',
        message:
            'At your current spending rate of ${AppConstants.currencySymbol}${v.dailyAverage.toStringAsFixed(0)}/day, '
            'you\'ll exceed your budget by ${AppConstants.currencySymbol}${v.projectedOverage.toStringAsFixed(0)} '
            'this month.',
        priority: 1,
        type: InsightType.warning,
      ));

      if (v.safeDailyBudget > 0) {
        insights.add(Insight(
          icon: '💡',
          title: 'Safe Spending Limit',
          message:
              'To stay within budget, limit daily spending to ${AppConstants.currencySymbol}${v.safeDailyBudget.toStringAsFixed(0)} '
              'for the next ${v.daysInMonth - v.daysElapsed} days.',
          priority: 2,
          type: InsightType.tip,
        ));
      }
    } else if (v.budgetLimit != null && v.totalSoFar > 0) {
      final usedPct = (v.totalSoFar / v.budgetLimit! * 100).toStringAsFixed(0);
      final elapsed = (v.monthProgress * 100).toStringAsFixed(0);
      insights.add(Insight(
        icon: '✅',
        title: 'On Track',
        message:
            'You\'ve used $usedPct% of your budget with $elapsed% of the month gone. '
            'Projected month-end spend: ${AppConstants.currencySymbol}${v.projectedMonthEnd.toStringAsFixed(0)}.',
        priority: 5,
        type: InsightType.positive,
      ));
    }

    // Spending trend
    if (v.trend == SpendTrend.accelerating) {
      insights.add(Insight(
        icon: '📈',
        title: 'Spending Accelerating',
        message:
            'Your recent spending is increasing faster than early in the month. '
            'Consider slowing down.',
        priority: 3,
        type: InsightType.warning,
      ));
    } else if (v.trend == SpendTrend.decelerating) {
      insights.add(Insight(
        icon: '📉',
        title: 'Spending Slowing Down',
        message:
            'Great! Your spending pace has slowed compared to the start of the month.',
        priority: 8,
        type: InsightType.positive,
      ));
    }
  }

  static void _addDisciplineInsights(
      List<Insight> insights, DisciplineScoreResult d) {
    // Overall score announcement
    insights.add(Insight(
      icon: _scoreEmoji(d.totalScore),
      title: 'Financial Discipline: ${d.grade}',
      message: 'Your financial discipline score is ${d.totalScore}/100 this month.',
      priority: 4,
      type: d.totalScore >= 60 ? InsightType.positive : InsightType.warning,
    ));

    // Specific sub-score feedback
    if (d.budgetScore <= 10 && d.totalSpent > 0) {
      insights.add(Insight(
        icon: '🎯',
        title: 'Budget Adherence Low',
        message: 'You\'re significantly over budget. '
            'Try setting a realistic budget and reviewing it weekly.',
        priority: 3,
        type: InsightType.warning,
      ));
    }

    if (d.savingsScore >= 20) {
      insights.add(Insight(
        icon: '🏦',
        title: 'Strong Savings',
        message: 'Your income-to-expense ratio is healthy. Keep it up!',
        priority: 9,
        type: InsightType.positive,
      ));
    } else if (d.savingsScore <= 5 && d.totalReceived > 0) {
      insights.add(Insight(
        icon: '💸',
        title: 'Low Savings Rate',
        message:
            'You\'re spending most of what you receive. '
            'Aim to save at least 20% of your income.',
        priority: 3,
        type: InsightType.tip,
      ));
    }

    if (d.consistencyScore <= 5) {
      insights.add(Insight(
        icon: '🎢',
        title: 'Erratic Spending',
        message:
            'Your daily spending varies a lot. Consistent spending habits help with budgeting.',
        priority: 6,
        type: InsightType.tip,
      ));
    }
  }

  static void _addDriftInsights(
      List<Insight> insights, CategoryDriftResult drift) {
    for (final d in drift.drifts.take(3)) {
      // Top 3 most significant drifts
      if (d.isIncrease) {
        insights.add(Insight(
          icon: '🔺',
          title: '${d.category} Up ${d.changePercent.abs().toStringAsFixed(0)}%',
          message:
              '${d.category} spending is ${AppConstants.currencySymbol}${d.currentAmount.toStringAsFixed(0)} '
              'this month vs ${AppConstants.currencySymbol}${d.historicalAverage.toStringAsFixed(0)} avg. '
              'That\'s ${AppConstants.currencySymbol}${d.absoluteChange.toStringAsFixed(0)} more than usual.',
          priority: 2,
          type: InsightType.warning,
        ));
      } else {
        insights.add(Insight(
          icon: '🔻',
          title: '${d.category} Down ${d.changePercent.abs().toStringAsFixed(0)}%',
          message:
              'You\'ve spent ${AppConstants.currencySymbol}${d.absoluteChange.abs().toStringAsFixed(0)} less '
              'on ${d.category} compared to your average.',
          priority: 7,
          type: InsightType.positive,
        ));
      }
    }

    // Overall spending change
    if (drift.totalChangePercent.abs() > 20 && drift.historicalAvgTotal > 0) {
      final direction = drift.totalChangePercent > 0 ? 'up' : 'down';
      insights.add(Insight(
        icon: drift.totalChangePercent > 0 ? '📊' : '💰',
        title: 'Overall Spending $direction',
        message:
            'Total spending is ${drift.totalChangePercent.abs().toStringAsFixed(0)}% '
            '$direction compared to previous months.',
        priority: drift.totalChangePercent > 0 ? 3 : 7,
        type: drift.totalChangePercent > 0
            ? InsightType.warning
            : InsightType.positive,
      ));
    }
  }

  static void _addTimeInsights(
      List<Insight> insights, CategoryDriftResult drift) {
    final tod = drift.timeOfDaySpend;
    final total = tod.values.fold<double>(0, (s, v) => s + v);
    if (total == 0) return;

    final peak = tod.entries.reduce((a, b) => a.value > b.value ? a : b);
    final peakPct = (peak.value / total * 100).toStringAsFixed(0);

    insights.add(Insight(
      icon: '🕐',
      title: 'Peak Spending Time',
      message:
          '$peakPct% of your spending happens in the ${peak.key.toLowerCase()} window.',
      priority: 10,
      type: InsightType.info,
    ));

    // Late-night spending alert
    final nightSpend = tod['Night (21–6)'] ?? 0;
    if (nightSpend > 0 && nightSpend / total > 0.25) {
      insights.add(Insight(
        icon: '🌙',
        title: 'Late-Night Spending',
        message:
            '${(nightSpend / total * 100).toStringAsFixed(0)}% of your spending is between 9 PM and 6 AM. '
            'These are often impulsive purchases.',
        priority: 4,
        type: InsightType.tip,
      ));
    }
  }

  static String _scoreEmoji(int score) {
    if (score >= 85) return '🏆';
    if (score >= 70) return '⭐';
    if (score >= 55) return '👍';
    if (score >= 40) return '⚡';
    return '⚠️';
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
