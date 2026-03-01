import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/spend_velocity_engine.dart';
import '../../core/utils/discipline_score_engine.dart';
import '../../core/utils/category_drift_engine.dart';
import '../../core/utils/insight_generator.dart';
import '../../state/providers.dart';
import '../../data/database/app_database.dart';

// ═══════════════════════════════════════════
//  INSIGHTS PROVIDERS
// ═══════════════════════════════════════════

/// All analytics data bundled into one provider for the current month.
final insightsProvider = FutureProvider.autoDispose<InsightsData?>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();

  // Fetch current month + previous 3 months + budget in parallel
  final prevDates = [
    for (int i = 1; i <= 3; i++) DateTime(now.year, now.month - i, 1),
  ];

  final results = await Future.wait([
    db.getMonthTransactions(now.year, now.month),
    for (final d in prevDates) db.getMonthTransactions(d.year, d.month),
    db.getBudget(now.year, now.month),
  ]);

  final currentTxns = results[0] as List<Transaction>;
  if (currentTxns.isEmpty) return null;

  final prevMonths = <List<Transaction>>[
    for (int i = 1; i <= 3; i++)
      if ((results[i] as List<Transaction>).isNotEmpty)
        results[i] as List<Transaction>,
  ];

  final budget = results[4] as Budget?;

  // Run all engines
  final velocity = SpendVelocityEngine.analyze(
    transactions: currentTxns,
    year: now.year,
    month: now.month,
    budgetLimit: budget?.limitAmount,
  );

  final discipline = DisciplineScoreEngine.calculate(
    transactions: currentTxns,
    year: now.year,
    month: now.month,
    budgetLimit: budget?.limitAmount,
  );

  final drift = CategoryDriftEngine.analyze(
    currentMonthTxns: currentTxns,
    previousMonthsTxns: prevMonths,
  );

  final insights = InsightGenerator.generate(
    velocity: velocity,
    discipline: discipline,
    drift: drift,
  );

  return InsightsData(
    velocity: velocity,
    discipline: discipline,
    drift: drift,
    insights: insights,
  );
});

class InsightsData {
  final SpendVelocityResult velocity;
  final DisciplineScoreResult discipline;
  final CategoryDriftResult drift;
  final List<Insight> insights;

  const InsightsData({
    required this.velocity,
    required this.discipline,
    required this.drift,
    required this.insights,
  });
}

// ═══════════════════════════════════════════
//  INSIGHTS SCREEN
// ═══════════════════════════════════════════

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsProvider);
    final now = DateTime.now();

    return Scaffold(
      body: SafeArea(
        child: insightsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (data) {
            if (data == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.insights_outlined,
                            size: 40, color: AppTheme.primary),
                      ),
                      const SizedBox(height: 20),
                      Text('No insights yet',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        'Insights will appear once you have\ntransaction data this month',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppTheme.textSecondaryDark
                                  : AppTheme.textSecondaryLight,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Separate insights by type for grouped display
            final warnings = data.insights
                .where((i) => i.type == InsightType.warning)
                .toList();
            final tips = data.insights
                .where((i) =>
                    i.type == InsightType.tip || i.type == InsightType.info)
                .toList();
            final positives = data.insights
                .where((i) => i.type == InsightType.positive)
                .toList();

            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Insights',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          Formatters.monthYear(now),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppTheme.textSecondaryDark
                                        : AppTheme.textSecondaryLight,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Score Overview (compact row) ──
                _ScoreOverviewCard(
                  discipline: data.discipline,
                  velocity: data.velocity,
                ),

                // ── Warnings Section ──
                if (warnings.isNotEmpty) ...[
                  _SectionLabel(
                    icon: Icons.warning_amber_rounded,
                    label: 'Needs Attention',
                    color: AppTheme.error,
                  ),
                  ...warnings.map((i) => _InsightTile(insight: i)),
                ],

                // ── Spend Velocity ──
                _SectionLabel(
                  icon: Icons.speed_rounded,
                  label: 'Spending Pace',
                  color: AppTheme.primary,
                ),
                _SpendVelocityCard(velocity: data.velocity),

                // ── Category Shifts ──
                if (data.drift.hasDrifts) ...[
                  _SectionLabel(
                    icon: Icons.compare_arrows_rounded,
                    label: 'Category Changes',
                    color: AppTheme.warning,
                  ),
                  _CategoryDriftCard(drift: data.drift),
                ],

                // ── Time of Day ──
                if (data.drift.timeOfDaySpend.values
                        .fold<double>(0, (s, v) => s + v) >
                    0) ...[
                  _SectionLabel(
                    icon: Icons.schedule_rounded,
                    label: 'When You Spend',
                    color: AppTheme.primaryLight,
                  ),
                  _TimeOfDayCard(timeData: data.drift.timeOfDaySpend),
                ],

                // ── Tips ──
                if (tips.isNotEmpty) ...[
                  _SectionLabel(
                    icon: Icons.lightbulb_outline_rounded,
                    label: 'Tips & Info',
                    color: AppTheme.warning,
                  ),
                  ...tips.map((i) => _InsightTile(insight: i)),
                ],

                // ── Positives ──
                if (positives.isNotEmpty) ...[
                  _SectionLabel(
                    icon: Icons.thumb_up_alt_outlined,
                    label: 'What\'s Going Well',
                    color: AppTheme.success,
                  ),
                  ...positives.map((i) => _InsightTile(insight: i)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  SECTION LABEL
// ═══════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  SCORE OVERVIEW CARD (compact)
// ═══════════════════════════════════════════

class _ScoreOverviewCard extends StatelessWidget {
  final DisciplineScoreResult discipline;
  final SpendVelocityResult velocity;

  const _ScoreOverviewCard({
    required this.discipline,
    required this.velocity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _gradeGradient(discipline.grade),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Top row: Score + Grade + Quick stats
            Row(
              children: [
                // Score ring
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: CircularProgressIndicator(
                          value: discipline.totalScore / 100,
                          strokeWidth: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor:
                              const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${discipline.totalScore}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            discipline.grade,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Summary stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Financial Discipline',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _MiniStat(
                            label: 'Spent',
                            value: Formatters.currencyCompact(
                                discipline.totalSpent),
                          ),
                          const SizedBox(width: 16),
                          _MiniStat(
                            label: 'Received',
                            value: Formatters.currencyCompact(
                                discipline.totalReceived),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Sub-score bars — compact 2-column layout
            Row(
              children: [
                Expanded(
                  child: _CompactScoreBar(
                      label: 'Budget',
                      value: discipline.budgetScore,
                      max: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CompactScoreBar(
                      label: 'Savings',
                      value: discipline.savingsScore,
                      max: 25),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _CompactScoreBar(
                      label: 'Consistency',
                      value: discipline.consistencyScore,
                      max: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CompactScoreBar(
                      label: 'Diversity',
                      value: discipline.diversityScore,
                      max: 15),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _CompactScoreBar(
                label: 'Regularity',
                value: discipline.regularityScore,
                max: 10),
          ],
        ),
      ),
    );
  }

  List<Color> _gradeGradient(String grade) {
    switch (grade) {
      case 'A+':
      case 'A':
        return [const Color(0xFF00B09B), const Color(0xFF96C93D)];
      case 'B+':
      case 'B':
        return [const Color(0xFF4A42DB), const Color(0xFF6C63FF)];
      case 'C':
        return [const Color(0xFFFF8C00), const Color(0xFFFFAB40)];
      default:
        return [const Color(0xFFFF5252), const Color(0xFFFF8A80)];
    }
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CompactScoreBar extends StatelessWidget {
  final String label;
  final int value;
  final int max;

  const _CompactScoreBar({
    required this.label,
    required this.value,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
            Text(
              '$value/$max',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: max > 0 ? value / max : 0,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation(Colors.white),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════
//  SPEND VELOCITY CARD
// ═══════════════════════════════════════════

class _SpendVelocityCard extends StatelessWidget {
  final SpendVelocityResult velocity;
  const _SpendVelocityCard({required this.velocity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trend badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Day ${velocity.daysElapsed} of ${velocity.daysInMonth}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                ),
                _TrendChip(trend: velocity.trend),
              ],
            ),

            const SizedBox(height: 16),

            // Primary metrics row
            Row(
              children: [
                Expanded(
                  child: _MetricBlock(
                    label: 'Spent so far',
                    value: Formatters.currencyCompact(velocity.totalSoFar),
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: AppTheme.primary,
                    isDark: isDark,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: isDark
                      ? AppTheme.borderDark
                      : AppTheme.borderLight,
                ),
                Expanded(
                  child: _MetricBlock(
                    label: 'Daily avg',
                    value: Formatters.currencyCompact(velocity.dailyAverage),
                    icon: Icons.calendar_today_rounded,
                    iconColor: AppTheme.primaryLight,
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Secondary metrics row
            Row(
              children: [
                Expanded(
                  child: _MetricBlock(
                    label: 'Projected',
                    value: Formatters.currencyCompact(
                        velocity.projectedMonthEnd),
                    icon: Icons.trending_up_rounded,
                    iconColor: velocity.willExceedBudget
                        ? AppTheme.error
                        : AppTheme.success,
                    isDark: isDark,
                    highlight: velocity.willExceedBudget,
                  ),
                ),
                if (velocity.budgetLimit != null) ...[
                  Container(
                    width: 1,
                    height: 40,
                    color: isDark
                        ? AppTheme.borderDark
                        : AppTheme.borderLight,
                  ),
                  Expanded(
                    child: _MetricBlock(
                      label: 'Safe daily limit',
                      value: velocity.safeDailyBudget > 0
                          ? Formatters.currencyCompact(
                              velocity.safeDailyBudget)
                          : '—',
                      icon: Icons.shield_outlined,
                      iconColor: AppTheme.success,
                      isDark: isDark,
                    ),
                  ),
                ],
              ],
            ),

            // Budget progress bar
            if (velocity.budgetLimit != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (velocity.totalSoFar / velocity.budgetLimit!)
                            .clamp(0, 1)
                            .toDouble(),
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        valueColor: AlwaysStoppedAnimation(
                          velocity.willExceedBudget
                              ? AppTheme.error
                              : AppTheme.success,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(velocity.totalSoFar / velocity.budgetLimit! * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: velocity.willExceedBudget
                          ? AppTheme.error
                          : AppTheme.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'of ${Formatters.currencyCompact(velocity.budgetLimit!)} budget',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final bool isDark;
  final bool highlight;

  const _MetricBlock({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.isDark,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: highlight ? AppTheme.error : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  final SpendTrend trend;
  const _TrendChip({required this.trend});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (trend) {
      SpendTrend.accelerating => ('Rising', AppTheme.error, Icons.trending_up),
      SpendTrend.decelerating =>
        ('Falling', AppTheme.success, Icons.trending_down),
      SpendTrend.stable => ('Stable', AppTheme.primary, Icons.trending_flat),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  CATEGORY DRIFT CARD
// ═══════════════════════════════════════════

class _CategoryDriftCard extends StatelessWidget {
  final CategoryDriftResult drift;
  const _CategoryDriftCard({required this.drift});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...drift.drifts.take(5).map((d) {
              final color =
                  d.isIncrease ? AppTheme.error : AppTheme.success;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    // Change indicator
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        d.isIncrease
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 16,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Category name + amount
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.category,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            Formatters.currencyCompact(d.currentAmount),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppTheme.textSecondaryDark
                                  : AppTheme.textSecondaryLight,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Percentage change
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${d.isIncrease ? '+' : ''}${d.changePercent.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  TIME-OF-DAY CARD
// ═══════════════════════════════════════════

class _TimeOfDayCard extends StatelessWidget {
  final Map<String, double> timeData;
  const _TimeOfDayCard({required this.timeData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final total = timeData.values.fold<double>(0, (s, v) => s + v);
    if (total == 0) return const SizedBox.shrink();

    final entries = timeData.entries.toList();
    final colors = [
      const Color(0xFFFFBE0B), // Morning
      const Color(0xFFFF6B6B), // Afternoon
      const Color(0xFF6C63FF), // Evening
      const Color(0xFF3A86FF), // Night
    ];

    final icons = [
      Icons.wb_sunny_outlined,
      Icons.wb_twilight_rounded,
      Icons.nightlight_outlined,
      Icons.dark_mode_outlined,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stacked horizontal bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    for (int i = 0; i < entries.length; i++)
                      if (entries[i].value > 0)
                        Expanded(
                          flex: (entries[i].value / total * 100)
                              .round()
                              .clamp(1, 100),
                          child: Container(color: colors[i]),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Time slots as rows
            for (int i = 0; i < entries.length; i++) ...[
              if (entries[i].value > 0)
                Padding(
                  padding: EdgeInsets.only(
                      bottom: i < entries.length - 1 ? 10 : 0),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: colors[i].withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Icon(icons[i], size: 14, color: colors[i]),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entries[i].key,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppTheme.textSecondaryDark
                                : AppTheme.textSecondaryLight,
                          ),
                        ),
                      ),
                      Text(
                        Formatters.currencyCompact(entries[i].value),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${(entries[i].value / total * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: colors[i],
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  INSIGHT TILE
// ═══════════════════════════════════════════

class _InsightTile extends StatelessWidget {
  final Insight insight;
  const _InsightTile({required this.insight});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final accentColor = switch (insight.type) {
      InsightType.warning => AppTheme.error,
      InsightType.tip => AppTheme.warning,
      InsightType.positive => AppTheme.success,
      InsightType.info => AppTheme.primary,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          ),
        ),
        child: Row(
          children: [
            // Left accent strip
            Container(
              width: 4,
              height: 56,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(insight.icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      insight.message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}
