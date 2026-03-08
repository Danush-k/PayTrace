import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/insight_generator.dart';
import '../../core/utils/spending_insights_engine.dart';
import '../../state/providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

final insightsDashboardProvider =
    FutureProvider.autoDispose<_InsightsDashboard?>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();

  final txns = await db.getAllTransactions();
  if (txns.isEmpty) return null;

  final result = SpendingInsightsEngine.analyze(transactions: txns);
  final insights = InsightGenerator.generate(
    transactions: txns,
    spendingInsights: result,
    referenceDate: now,
  );

  // ── Top merchant this week (Mon–today) ────────────────────────────────
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final weeklyDebits = txns.where((t) {
    if (t.direction != 'DEBIT' || t.status != 'SUCCESS') return false;
    final d = DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day);
    return !d.isBefore(weekStart) && !d.isAfter(today);
  }).toList();

  MerchantSpendEntry? topMerchantThisWeek;
  if (weeklyDebits.isNotEmpty) {
    final spend = <String, double>{};
    final counts = <String, int>{};
    final cats = <String, String>{};
    for (final t in weeklyDebits) {
      final key =
          t.payeeName.trim().isNotEmpty ? t.payeeName.trim() : t.payeeUpiId;
      spend.update(key, (v) => v + t.amount, ifAbsent: () => t.amount);
      counts.update(key, (v) => v + 1, ifAbsent: () => 1);
      cats.putIfAbsent(key, () => t.category);
    }
    final top = spend.entries.reduce((a, b) => a.value >= b.value ? a : b);
    topMerchantThisWeek = MerchantSpendEntry(
      displayName: top.key,
      upiId: '',
      totalAmount: top.value,
      transactionCount: counts[top.key]!,
      category: cats[top.key]!,
      shareOfTotal: result.topMerchants.totalSpent > 0
          ? (top.value / result.topMerchants.totalSpent) * 100
          : 0,
    );
  }

  return _InsightsDashboard(
    month: now,
    insights: insights,
    result: result,
    topMerchantThisWeek: topMerchantThisWeek,
  );
});

class _InsightsDashboard {
  final DateTime month;
  final List<Insight> insights;
  final SpendingInsightsResult result;
  final MerchantSpendEntry? topMerchantThisWeek;

  const _InsightsDashboard({
    required this.month,
    required this.insights,
    required this.result,
    required this.topMerchantThisWeek,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
//  MAIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(insightsDashboardProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (data) {
        if (data == null) {
          return Center(
            child: Text(
              'Add transactions to see insights',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
          children: [
            // ── Header ────────────────────────────────────────────────────
            Text(
              'Insights',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text(
              Formatters.monthYear(data.month),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white54),
            ),
            const SizedBox(height: 20),

            // ── 1  Daily Spending Bar Chart (Mon–Sun) ─────────────────────
            _DailySpendingBarCard(insight: data.result.weeklyComparison),
            const SizedBox(height: 16),

            // ── 2  Category Distribution (pie only, no cards) ─────────────
            _CategoryPieCard(insight: data.result.categoryDistribution),
            const SizedBox(height: 16),

            // ── 3  Top Merchant This Week ─────────────────────────────────
            if (data.topMerchantThisWeek != null) ...[
              _TopMerchantCard(merchant: data.topMerchantThisWeek!),
              const SizedBox(height: 16),
            ],

            // ── 4  Daily Spending Average ─────────────────────────────────
            _DailyAverageCard(
              insight: data.result.dailyAverage,
              weeklyInsight: data.result.weeklyComparison,
            ),
            const SizedBox(height: 16),

            // ── 5  Peak Spending Time ─────────────────────────────────────
            if (data.result.timeOfDay.totalSpent > 0) ...[
              _PeakTimeCard(insight: data.result.timeOfDay),
              const SizedBox(height: 16),
            ],

            // ── 6  Weekend vs Weekday ─────────────────────────────────────
            if (data.result.weekendVsWeekday.total > 0) ...[
              _WeekendVsWeekdayCard(insight: data.result.weekendVsWeekday),
              const SizedBox(height: 16),
            ],

            // ── 7  Statistical Insight Cards ──────────────────────────────
            _AnalyticsCards(insights: data.insights),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  1. DAILY SPENDING BAR CHART  (Mon–Sun, weekday=blue, weekend=orange)
// ═══════════════════════════════════════════════════════════════════════════

class _DailySpendingBarCard extends StatelessWidget {
  final WeeklyComparisonInsight insight;

  const _DailySpendingBarCard({required this.insight});

  static const _weekdayColor = AppTheme.primary;
  static const _weekendColor = Color(0xFFFFAB40);
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _fullDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final maxY = insight.maxDailyValue;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This Week\'s Spending',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${Formatters.currency(insight.thisWeekTotal)} total',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white54),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: max(1, maxY * 1.25),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        const Color(0xFF1E1E2C),
                    getTooltipItem: (group, gI, rod, rI) {
                      final idx = group.x;
                      return BarTooltipItem(
                        '${_fullDays[idx]} – ${Formatters.currency(rod.toY)} spent',
                        TextStyle(
                          color: idx >= 5 ? _weekendColor : _weekdayColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: max(1, maxY / 4),
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withValues(alpha: 0.06),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) {
                        final i = value.toInt();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _days[i],
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: i >= 5
                                      ? _weekendColor
                                      : Colors.white60,
                                ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) {
                  final amount = insight.thisWeekDaily[i] ?? 0;
                  final isWeekend = i >= 5;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: amount,
                        color: isWeekend ? _weekendColor : _weekdayColor,
                        width: 22,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: max(1, maxY * 1.25),
                          color: Colors.white.withValues(alpha: 0.03),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: _weekdayColor, label: 'Weekday'),
              const SizedBox(width: 20),
              _LegendDot(color: _weekendColor, label: 'Weekend'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  2. CATEGORY PIE (donut, touch, legend grid – no stray cards)
// ═══════════════════════════════════════════════════════════════════════════

class _CategoryPieCard extends StatefulWidget {
  final CategoryDistributionInsight insight;
  const _CategoryPieCard({required this.insight});
  @override
  State<_CategoryPieCard> createState() => _CategoryPieCardState();
}

class _CategoryPieCardState extends State<_CategoryPieCard> {
  int _touched = -1;

  static const _palette = [
    Color(0xFF6C63FF),
    Color(0xFFFF6B6B),
    Color(0xFFFFAB40),
    Color(0xFF26C6DA),
    Color(0xFF66BB6A),
    Color(0xFFEC407A),
    Color(0xFF42A5F5),
    Color(0xFFAB47BC),
  ];

  Color _color(String cat) => _palette[cat.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    if (widget.insight.entries.isEmpty) return const SizedBox.shrink();

    final sorted = [...widget.insight.entries]
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    final List<CategorySpendEntry> slices;
    if (sorted.length <= 7) {
      slices = sorted;
    } else {
      final top6 = sorted.take(6).toList();
      final otherAmt =
          sorted.skip(6).fold<double>(0, (s, e) => s + e.totalAmount);
      final total = sorted.fold<double>(0, (s, e) => s + e.totalAmount);
      slices = [
        ...top6,
        CategorySpendEntry(
          category: 'Other',
          totalAmount: otherAmt,
          transactionCount: 0,
          percentage: total > 0 ? (otherAmt / total) * 100 : 0,
        ),
      ];
    }

    final grandTotal = slices.fold<double>(0, (s, e) => s + e.totalAmount);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where Do You Spend?',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            '${slices.length} categories · ${Formatters.currency(grandTotal)} total',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white54),
          ),
          const SizedBox(height: 16),

          // Donut
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (evt, resp) {
                        setState(() {
                          if (evt is FlTapUpEvent) {
                            final idx = resp?.touchedSection
                                    ?.touchedSectionIndex ??
                                -1;
                            _touched = _touched == idx ? -1 : idx;
                          }
                        });
                      },
                    ),
                    centerSpaceRadius: 56,
                    sectionsSpace: 3,
                    sections: slices.asMap().entries.map((e) {
                      final i = e.key;
                      final entry = e.value;
                      final hit = i == _touched;
                      final pct = grandTotal > 0
                          ? entry.totalAmount / grandTotal * 100
                          : 0;
                      return PieChartSectionData(
                        value: entry.totalAmount,
                        color: _color(entry.category),
                        radius: hit ? 68.0 : 56.0,
                        title:
                            pct >= 5 ? '${pct.toStringAsFixed(0)}%' : '',
                        titleStyle: TextStyle(
                          fontSize: hit ? 13 : 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          shadows: const [
                            Shadow(blurRadius: 3, color: Colors.black45)
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // Center label
                _touched >= 0 && _touched < slices.length
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            slices[_touched].category,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: _color(slices[_touched].category),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            Formatters.currency(
                                slices[_touched].totalAmount),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: _color(slices[_touched].category),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      )
                    : Text(
                        Formatters.currency(grandTotal),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white70,
                            ),
                      ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Two-column legend
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: slices.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 3.2,
            ),
            itemBuilder: (_, i) {
              final entry = slices[i];
              final pct =
                  grandTotal > 0 ? entry.totalAmount / grandTotal : 0.0;
              final active = _touched == i;
              return GestureDetector(
                onTap: () =>
                    setState(() => _touched = active ? -1 : i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: active
                        ? _color(entry.category).withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active
                          ? _color(entry.category)
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _color(entry.category),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              entry.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                            ),
                          ),
                          Text(
                            '${(pct * 100).toStringAsFixed(0)}%',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontSize: 10,
                                  color: _color(entry.category),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: pct.clamp(0, 1).toDouble(),
                          minHeight: 3,
                          backgroundColor: _color(entry.category)
                              .withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation(
                              _color(entry.category)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.currencyCompact(entry.totalAmount),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 10, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  3. TOP MERCHANT THIS WEEK
// ═══════════════════════════════════════════════════════════════════════════

class _TopMerchantCard extends StatelessWidget {
  final MerchantSpendEntry merchant;
  const _TopMerchantCard({required this.merchant});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.storefront_rounded,
                color: AppTheme.warning, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top Merchant This Week',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white54),
                ),
                const SizedBox(height: 2),
                Text(
                  merchant.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    merchant.category,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.currency(merchant.totalAmount),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.error,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                '${merchant.transactionCount} txn${merchant.transactionCount == 1 ? '' : 's'}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  4. DAILY SPENDING AVERAGE  (clear summary + mini bar)
// ═══════════════════════════════════════════════════════════════════════════

class _DailyAverageCard extends StatelessWidget {
  final DailyAverageInsight insight;
  final WeeklyComparisonInsight weeklyInsight;

  const _DailyAverageCard({
    required this.insight,
    required this.weeklyInsight,
  });

  @override
  Widget build(BuildContext context) {
    final peakWd = insight.peakWeekday;
    final peakLabel =
        peakWd != null ? DailyAverageInsight.weekdayLabel(peakWd) : null;
    final peakWdAmount =
        peakWd != null ? (insight.weekdayAverages[peakWd] ?? 0) : 0.0;

    // Count of this-week transactions
    final thisWeekTxnCount = weeklyInsight.thisWeekDaily.values
        .where((v) => v > 0)
        .length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Spending Average',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),

          // Key metrics row
          _KeyMetric(
            label: 'Average per day',
            value: Formatters.currency(insight.averagePerDay),
          ),
          const SizedBox(height: 8),
          if (insight.peakDate != null && peakLabel != null)
            _KeyMetric(
              label: 'Highest spending day',
              value:
                  '$peakLabel – ${Formatters.currency(peakWdAmount)}',
              highlight: true,
            ),
          const SizedBox(height: 8),
          _KeyMetric(
            label: 'Active days this week',
            value: '$thisWeekTxnCount of 7',
          ),

          // Mini bar chart
          if (insight.weekdayAverages.isNotEmpty) ...[
            const SizedBox(height: 16),
            _WeekdayMiniBar(weekdayAverages: insight.weekdayAverages),
          ],
        ],
      ),
    );
  }
}

class _KeyMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _KeyMetric({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.white70),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: highlight ? AppTheme.error : Colors.white,
              ),
        ),
      ],
    );
  }
}

/// Mon–Sun miniature bar chart.
class _WeekdayMiniBar extends StatelessWidget {
  final Map<int, double> weekdayAverages; // 1=Mon … 7=Sun
  const _WeekdayMiniBar({required this.weekdayAverages});

  @override
  Widget build(BuildContext context) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxVal =
        weekdayAverages.values.fold<double>(0, (m, v) => v > m ? v : m);
    final peakWd = weekdayAverages.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final wd = i + 1;
        final val = weekdayAverages[wd] ?? 0;
        final frac = maxVal > 0 ? val / maxVal : 0.0;
        final isWeekend = wd >= 6;
        final isPeak = wd == peakWd;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i > 0 ? 4 : 0),
            child: Column(
              children: [
                if (isPeak)
                  Text(
                    Formatters.currencyCompact(val),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 9,
                          color: isWeekend
                              ? const Color(0xFFFFAB40)
                              : AppTheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                const SizedBox(height: 2),
                Container(
                  height: max(4, 52 * frac),
                  decoration: BoxDecoration(
                    color: isWeekend
                        ? const Color(0xFFFFAB40).withValues(alpha: 0.8)
                        : AppTheme.primary.withValues(
                            alpha: isPeak ? 1.0 : 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[i],
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        fontWeight:
                            isPeak ? FontWeight.w700 : FontWeight.normal,
                      ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  5. PEAK SPENDING TIME  (text + horizontal bars, no images)
// ═══════════════════════════════════════════════════════════════════════════

class _PeakTimeCard extends StatelessWidget {
  final TimeOfDayInsight insight;
  const _PeakTimeCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final total = insight.totalSpent;
    final peak = insight.peakSession;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Peak Spending Time',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${peak.label} (${peak.timeRange})',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ...SpendingSession.values.map((session) {
            final amt = insight.sessionTotals[session] ?? 0;
            final frac = total > 0 ? amt / total : 0.0;
            final isPeak = session == peak;
            final barColor = isPeak
                ? AppTheme.primary
                : AppTheme.primary.withValues(alpha: 0.25);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${session.label}  ${session.timeRange}',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: isPeak
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color:
                                      isPeak ? Colors.white : Colors.white60,
                                ),
                      ),
                      Text(
                        Formatters.currency(amt),
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: isPeak
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: isPeak
                                      ? AppTheme.primary
                                      : Colors.white38,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: frac,
                      minHeight: isPeak ? 8 : 5,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation(barColor),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  6. WEEKEND VS WEEKDAY  (two large side-by-side bars)
// ═══════════════════════════════════════════════════════════════════════════

class _WeekendVsWeekdayCard extends StatelessWidget {
  final WeekendVsWeekdayInsight insight;
  const _WeekendVsWeekdayCard({required this.insight});

  static const _weekdayColor = AppTheme.primary;
  static const _weekendColor = Color(0xFFFFAB40);

  @override
  Widget build(BuildContext context) {
    final moreOnWeekends = insight.spendMoreOnWeekends;
    final maxAmt = max(insight.weekdayTotal, insight.weekendTotal);
    final wdFrac = maxAmt > 0 ? insight.weekdayTotal / maxAmt : 0.0;
    final weFrac = maxAmt > 0 ? insight.weekendTotal / maxAmt : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekend vs Weekday',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (moreOnWeekends ? _weekendColor : _weekdayColor)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  moreOnWeekends ? 'Weekend heavy' : 'Weekday heavy',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            moreOnWeekends ? _weekendColor : _weekdayColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Amounts
          Row(
            children: [
              Expanded(
                child: Text(
                  'Weekday: ${Formatters.currency(insight.weekdayTotal)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
              ),
              Expanded(
                child: Text(
                  'Weekend: ${Formatters.currency(insight.weekendTotal)}',
                  textAlign: TextAlign.end,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Two large side-by-side bars
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Weekday bar
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.currencyCompact(insight.weekdayTotal),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: _weekdayColor,
                            ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        height: max(8, 100 * wdFrac),
                        decoration: BoxDecoration(
                          color: _weekdayColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Weekdays',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      Text(
                        '${insight.weekdayTxnCount} txns · ${Formatters.currency(insight.weekdayAvgPerDay)}/day',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 10, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Weekend bar
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.currencyCompact(insight.weekendTotal),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: _weekendColor,
                            ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        height: max(8, 100 * weFrac),
                        decoration: BoxDecoration(
                          color: _weekendColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Weekends',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      Text(
                        '${insight.weekendTxnCount} txns · ${Formatters.currency(insight.weekendAvgPerDay)}/day',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 10, color: Colors.white38),
                      ),
                    ],
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

// ═══════════════════════════════════════════════════════════════════════════
//  7. STATISTICAL INSIGHT CARDS
// ═══════════════════════════════════════════════════════════════════════════

class _AnalyticsCards extends StatelessWidget {
  final List<Insight> insights;
  const _AnalyticsCards({required this.insights});

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistical Insights',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ...insights.take(5).map((insight) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        insight.message,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}