import '../../core/constants/app_constants.dart';

/// Smart Budget Recommender — generates 3 budget tiers based on
/// historical spending data and income.
///
/// Tiers:
///   - Aggressive (30% savings target)
///   - Moderate   (20% savings target)
///   - Comfortable (10% savings target)
class BudgetRecommender {
  BudgetRecommender._();

  /// Generate budget recommendations from historical data.
  ///
  /// [monthlySpending] - total DEBIT amounts for the last N months
  /// [monthlyIncome]   - total CREDIT amounts for the last N months
  static BudgetRecommendation recommend({
    required List<double> monthlySpending,
    required List<double> monthlyIncome,
  }) {
    if (monthlySpending.isEmpty) {
      return const BudgetRecommendation(
        avgMonthlySpend: 0,
        avgMonthlyIncome: 0,
        tiers: [],
        reasoning: 'Not enough data to suggest a budget.',
      );
    }

    final avgSpend =
        monthlySpending.reduce((a, b) => a + b) / monthlySpending.length;
    final avgIncome = monthlyIncome.isEmpty
        ? 0.0
        : monthlyIncome.reduce((a, b) => a + b) / monthlyIncome.length;

    final tiers = <BudgetTier>[];
    const cs = AppConstants.currencySymbol;

    if (avgIncome > 0) {
      // Income-based tiers
      final aggressive = (avgIncome * 0.70).roundToDouble();
      final moderate = (avgIncome * 0.80).roundToDouble();
      final comfortable = (avgIncome * 0.90).roundToDouble();

      tiers.addAll([
        BudgetTier(
          label: 'Aggressive Saver',
          amount: aggressive,
          savingsPercent: 30,
          icon: '🔥',
          description:
              'Save 30% of income. Budget: $cs${_fmt(aggressive)}/month.',
          color: 0xFF00C853, // green
        ),
        BudgetTier(
          label: 'Balanced',
          amount: moderate,
          savingsPercent: 20,
          icon: '⚖️',
          description:
              'Save 20% of income. Budget: $cs${_fmt(moderate)}/month.',
          color: 0xFF6C63FF, // primary
        ),
        BudgetTier(
          label: 'Comfortable',
          amount: comfortable,
          savingsPercent: 10,
          icon: '😌',
          description:
              'Save 10% of income. Budget: $cs${_fmt(comfortable)}/month.',
          color: 0xFFFFAB40, // warning
        ),
      ]);
    } else {
      // Spending-only based tiers (no income data)
      final tight = (avgSpend * 0.85).roundToDouble();
      final same = avgSpend.roundToDouble();
      final relaxed = (avgSpend * 1.10).roundToDouble();

      tiers.addAll([
        BudgetTier(
          label: 'Cut Back',
          amount: tight,
          savingsPercent: 15,
          icon: '🔥',
          description:
              '15% below your avg spend. Budget: $cs${_fmt(tight)}/month.',
          color: 0xFF00C853,
        ),
        BudgetTier(
          label: 'Match Average',
          amount: same,
          savingsPercent: 0,
          icon: '⚖️',
          description:
              'Matches your average spending: $cs${_fmt(same)}/month.',
          color: 0xFF6C63FF,
        ),
        BudgetTier(
          label: 'With Buffer',
          amount: relaxed,
          savingsPercent: -10,
          icon: '😌',
          description:
              '10% buffer above average: $cs${_fmt(relaxed)}/month.',
          color: 0xFFFFAB40,
        ),
      ]);
    }

    // Build reasoning string
    final reasoning = avgIncome > 0
        ? 'Based on avg monthly income of $cs${_fmt(avgIncome)} and spending of $cs${_fmt(avgSpend)} over ${monthlySpending.length} month(s).'
        : 'Based on avg monthly spending of $cs${_fmt(avgSpend)} over ${monthlySpending.length} month(s).';

    return BudgetRecommendation(
      avgMonthlySpend: avgSpend,
      avgMonthlyIncome: avgIncome,
      tiers: tiers,
      reasoning: reasoning,
    );
  }

  static String _fmt(double v) {
    if (v >= 1000) {
      return v.toStringAsFixed(0);
    }
    return v.toStringAsFixed(0);
  }
}

// ─── Data Models ───

class BudgetTier {
  final String label;
  final double amount;
  final int savingsPercent;
  final String icon;
  final String description;
  final int color; // hex color

  const BudgetTier({
    required this.label,
    required this.amount,
    required this.savingsPercent,
    required this.icon,
    required this.description,
    required this.color,
  });
}

class BudgetRecommendation {
  final double avgMonthlySpend;
  final double avgMonthlyIncome;
  final List<BudgetTier> tiers;
  final String reasoning;

  const BudgetRecommendation({
    required this.avgMonthlySpend,
    required this.avgMonthlyIncome,
    required this.tiers,
    required this.reasoning,
  });

  bool get hasTiers => tiers.isNotEmpty;
}
