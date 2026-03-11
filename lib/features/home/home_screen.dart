import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/category_engine.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/qr_parser.dart';
import '../../core/utils/smart_spending_alert_engine.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'widgets/transaction_activity_heatmap.dart';
import '../history/manual_expense_entry_screen.dart';
import '../history/transaction_detail_screen.dart';
import '../pay/pay_screen.dart';
import '../pay/qr_scan_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  // ── Navigation helpers ───────────────────────────────────────────────────

  static Future<void> _launchScanPay(BuildContext context) async {
    final qrData = await Navigator.of(context).push<QrPaymentData>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (qrData == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PayScreen(
          qrData: qrData,
          paymentMode: AppConstants.modeQrScan,
        ),
      ),
    );
  }

  static void _launchPayContact(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PayScreen(
          paymentMode: AppConstants.modeContact,
        ),
      ),
    );
  }

  static void _launchManualEntry(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ManualExpenseEntryScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Boot-time transaction detection ────────────────────────────────────
    // smsSyncProvider runs SmsSyncService.sync() on every app open.
    // On first install, _getLastSyncTime() defaults to 90 days ago so the
    // full SMS history is scanned automatically — no separate call needed.
    ref.watch(smsSyncProvider);

    // notificationPipelineProvider starts the NotificationPipeline which
    // listens to the real-time NotificationListenerService stream for
    // GPay / PhonePe / Paytm / Amazon Pay payment notifications and
    // inserts them into the DB immediately (with 3-layer dedup).
    ref.watch(notificationPipelineProvider);
    // ───────────────────────────────────────────────────────────────────────

    final now = DateTime.now();
    final monthKey = DateTime(now.year, now.month);

    final spentAsync = ref.watch(monthlySpendingProvider(monthKey));
    final receivedAsync = ref.watch(monthlyReceivedProvider(monthKey));
    final recentAsync = ref.watch(recentTransactionsProvider);
    final allTxnsAsync = ref.watch(allTransactionsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
      children: [
        Text(
          'PayTrace',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        Text(
          Formatters.monthYear(now),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        spentAsync.when(
          data: (spent) => receivedAsync.when(
            data: (received) => _SummaryCard(spent: spent, received: received),
            loading: () => const _SummaryCard.loading(),
            error: (_, __) => const _SummaryCard.loading(),
          ),
          loading: () => const _SummaryCard.loading(),
          error: (_, __) => const _SummaryCard.loading(),
        ),
        const SizedBox(height: 14),
        // ── Payment Actions ────────────────────────────────────────────────
        _PaymentActionsRow(
          onScanPay: () => _launchScanPay(context),
          onPayContact: () => _launchPayContact(context),
          onManualEntry: () => _launchManualEntry(context),
        ),
        const SizedBox(height: 16),
        allTxnsAsync.when(
          data: (transactions) {
            final alerts = SmartSpendingAlertEngine.analyze(
              transactions: transactions,
              referenceDate: now,
            );
            if (alerts.isEmpty) return const SizedBox.shrink();
            return _SpendingAlertsSection(alerts: alerts);
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        const _SpendingChart(),
        const SizedBox(height: 16),
        const TransactionActivityHeatmap(),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Transactions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              'Latest',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        recentAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return const _EmptyCard(message: 'No transactions yet');
            }
            return Column(
              children: items.take(8).map((txn) {
                return _TransactionTile(txn: txn);
              }).toList(),
            );
          },
          loading: () => const _EmptyCard(message: 'Loading transactions...'),
          error: (_, __) => const _EmptyCard(message: 'Could not load transactions'),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double? spent;
  final double? received;

  const _SummaryCard({required this.spent, required this.received});

  const _SummaryCard.loading()
      : spent = null,
        received = null;

  @override
  Widget build(BuildContext context) {
    final showLoading = spent == null || received == null;
    final balance = (received ?? 0) - (spent ?? 0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF181C28), Color(0xFF121622)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.09),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Summary',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            showLoading ? '--' : Formatters.currency(balance),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricPill(
                  title: 'Spent',
                  value: showLoading ? '--' : Formatters.currency(spent!),
                  color: AppTheme.error,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricPill(
                  title: 'Received',
                  value: showLoading ? '--' : Formatters.currency(received!),
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _MetricPill({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SPENDING CHART — Professional with time period filters
// ═══════════════════════════════════════════════════════════════════════════

enum _ChartPeriod { week, month, threeMonth, sixMonth, year }

extension on _ChartPeriod {
  String get label => switch (this) {
        _ChartPeriod.week => '1W',
        _ChartPeriod.month => '1M',
        _ChartPeriod.threeMonth => '3M',
        _ChartPeriod.sixMonth => '6M',
        _ChartPeriod.year => '1Y',
      };

  DateTimeRange range() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return switch (this) {
      _ChartPeriod.week => DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        ),
      _ChartPeriod.month => DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: today,
        ),
      _ChartPeriod.threeMonth => DateTimeRange(
          start: DateTime(now.year, now.month - 2, 1),
          end: today,
        ),
      _ChartPeriod.sixMonth => DateTimeRange(
          start: DateTime(now.year, now.month - 5, 1),
          end: today,
        ),
      _ChartPeriod.year => DateTimeRange(
          start: DateTime(now.year - 1, now.month + 1, 1),
          end: today,
        ),
    };
  }
}

class _SpendingChart extends ConsumerStatefulWidget {
  const _SpendingChart();

  @override
  ConsumerState<_SpendingChart> createState() => _SpendingChartState();
}

class _SpendingChartState extends ConsumerState<_SpendingChart> {
  _ChartPeriod _selected = _ChartPeriod.month;
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final range = _selected.range();
    final spendingRange = SpendingRange(range.start, range.end);
    final asyncData = ref.watch(spendingInRangeProvider(spendingRange));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spending',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              // Total for selected period
              asyncData.when(
                data: (daily) {
                  final total = daily.values.fold<double>(0, (s, v) => s + v);
                  return Text(
                    Formatters.currencyCompact(total),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Period filter chips
          Row(
            children: _ChartPeriod.values.map((p) {
              final isActive = p == _selected;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selected = p;
                    _touchedIndex = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.primary
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      p.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive
                                ? Colors.white
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Chart
          SizedBox(
            height: 180,
            child: asyncData.when(
              data: (daily) => _buildChart(context, daily, range, isDark),
              loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, __) =>
                  const Center(child: Text('Chart unavailable')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(
    BuildContext context,
    Map<DateTime, double> rawDaily,
    DateTimeRange range,
    bool isDark,
  ) {
    // Build aggregated data points depending on the period
    final aggregated = _aggregate(rawDaily, range);

    if (aggregated.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 40,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.2)),
            const SizedBox(height: 8),
            Text('No spending data',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    )),
          ],
        ),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < aggregated.length; i++) {
      spots.add(FlSpot(i.toDouble(), aggregated[i].value));
    }

    final maxY = spots.fold<double>(1, (m, e) => max(m, e.y));
    final lineColor = isDark ? AppTheme.primary : AppTheme.primaryDark;

    return LineChart(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      LineChartData(
        minX: 0,
        maxX: (spots.length - 1).toDouble(),
        minY: 0,
        maxY: maxY * 1.15,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 3,
          getDrawingHorizontalLine: (_) => FlLine(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.06),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: maxY / 3,
              getTitlesWidget: (value, _) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  _compactAmount(value),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                        fontSize: 10,
                      ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: _bottomInterval(aggregated.length),
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= aggregated.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    aggregated[idx].label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchCallback: (event, response) {
            setState(() {
              if (event is FlLongPressEnd || event is FlPanEndEvent) {
                _touchedIndex = null;
              } else {
                _touchedIndex =
                    response?.lineBarSpots?.first.spotIndex;
              }
            });
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => isDark
                ? const Color(0xFF2A2D3E)
                : Colors.white,
            tooltipRoundedRadius: 10,
            tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final idx = spot.spotIndex;
                final label = idx < aggregated.length
                    ? aggregated[idx].label
                    : '';
                return LineTooltipItem(
                  '$label\n',
                  TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 11,
                  ),
                  children: [
                    TextSpan(
                      text: Formatters.currency(spot.y),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            preventCurveOverShooting: true,
            barWidth: 2.5,
            isStrokeCapRound: true,
            color: lineColor,
            shadow: Shadow(
              color: lineColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lineColor.withValues(alpha: 0.25),
                  lineColor.withValues(alpha: 0.0),
                ],
              ),
            ),
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) {
                final isTouched = spot.x.toInt() == _touchedIndex;
                return FlDotCirclePainter(
                  radius: isTouched ? 5 : 0,
                  color: lineColor,
                  strokeWidth: 2,
                  strokeColor: isDark ? Colors.black : Colors.white,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Aggregate raw daily data into chart-friendly buckets.
  /// For 1W/1M: one point per day.
  /// For 3M/6M: one point per week.
  /// For 1Y: one point per month.
  List<_ChartPoint> _aggregate(
    Map<DateTime, double> rawDaily,
    DateTimeRange range,
  ) {
    switch (_selected) {
      case _ChartPeriod.week:
        return _dailyPoints(rawDaily, range, 7);
      case _ChartPeriod.month:
        final days = range.end.difference(range.start).inDays + 1;
        return _dailyPoints(rawDaily, range, days);
      case _ChartPeriod.threeMonth:
      case _ChartPeriod.sixMonth:
        return _weeklyPoints(rawDaily, range);
      case _ChartPeriod.year:
        return _monthlyPoints(rawDaily, range);
    }
  }

  List<_ChartPoint> _dailyPoints(
    Map<DateTime, double> raw,
    DateTimeRange range,
    int dayCount,
  ) {
    final points = <_ChartPoint>[];
    for (int i = 0; i < dayCount; i++) {
      final date = range.start.add(Duration(days: i));
      final key = DateTime(date.year, date.month, date.day);
      final value = raw[key] ?? 0;
      final label = dayCount <= 7
          ? DateFormat('EEE').format(date) // Mon, Tue...
          : DateFormat('d').format(date); // 1, 2, 3...
      points.add(_ChartPoint(label: label, value: value));
    }
    return points;
  }

  List<_ChartPoint> _weeklyPoints(
    Map<DateTime, double> raw,
    DateTimeRange range,
  ) {
    final points = <_ChartPoint>[];
    var weekStart = range.start;
    while (weekStart.isBefore(range.end)) {
      var weekEnd = weekStart.add(const Duration(days: 6));
      if (weekEnd.isAfter(range.end)) weekEnd = range.end;

      double total = 0;
      for (var d = weekStart;
          !d.isAfter(weekEnd);
          d = d.add(const Duration(days: 1))) {
        final key = DateTime(d.year, d.month, d.day);
        total += raw[key] ?? 0;
      }

      final label = DateFormat('d MMM').format(weekStart);
      points.add(_ChartPoint(label: label, value: total));
      weekStart = weekEnd.add(const Duration(days: 1));
    }
    return points;
  }

  List<_ChartPoint> _monthlyPoints(
    Map<DateTime, double> raw,
    DateTimeRange range,
  ) {
    final points = <_ChartPoint>[];
    var cursor = DateTime(range.start.year, range.start.month);
    final endMonth = DateTime(range.end.year, range.end.month);

    while (!cursor.isAfter(endMonth)) {
      double total = 0;
      for (final entry in raw.entries) {
        if (entry.key.year == cursor.year && entry.key.month == cursor.month) {
          total += entry.value;
        }
      }
      final label = DateFormat('MMM').format(cursor);
      points.add(_ChartPoint(label: label, value: total));
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return points;
  }

  double _bottomInterval(int count) {
    if (count <= 7) return 1;
    if (count <= 15) return 2;
    if (count <= 31) return 5;
    return max(1, (count / 6).ceilToDouble());
  }

  String _compactAmount(double value) {
    if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '₹${(value / 1000).toStringAsFixed(1)}K';
    return '₹${value.toInt()}';
  }
}

class _ChartPoint {
  final String label;
  final double value;
  const _ChartPoint({required this.label, required this.value});
}

class _SpendingAlertsSection extends StatelessWidget {
  final List<SmartSpendingAlert> alerts;

  const _SpendingAlertsSection({required this.alerts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              'Spending Alerts',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: alerts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _AlertCard(alert: alerts[i]),
          ),
        ),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  final SmartSpendingAlert alert;

  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: AppTheme.warning.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(alert.icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  alert.message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.25,
                      ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction txn;

  const _TransactionTile({required this.txn});

  @override
  Widget build(BuildContext context) {
    final isDebit = txn.direction != 'CREDIT';
    final amountColor = isDebit ? AppTheme.error : AppTheme.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TransactionDetailScreen(transaction: txn),
            ),
          );
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
          child: Text(
            CategoryEngine.categoryIcon(txn.category),
            style: const TextStyle(fontSize: 16),
          ),
        ),
        title: Text(
          txn.payeeName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: Text('${txn.category} · ${Formatters.dateRelative(txn.createdAt)}'),
        trailing: Text(
          '${isDebit ? '-' : '+'}${Formatters.currency(txn.amount)}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  PAYMENT ACTIONS ROW
// ═══════════════════════════════════════════════════════════════════════════

class _PaymentActionsRow extends StatelessWidget {
  final VoidCallback onScanPay;
  final VoidCallback onPayContact;
  final VoidCallback onManualEntry;

  const _PaymentActionsRow({
    required this.onScanPay,
    required this.onPayContact,
    required this.onManualEntry,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionCard(
          icon: Icons.qr_code_scanner_rounded,
          label: 'Scan & Pay',
          subtitle: 'Scan QR code',
          color: AppTheme.primary,
          onTap: onScanPay,
        ),
        const SizedBox(width: 10),
        _ActionCard(
          icon: Icons.contacts_rounded,
          label: 'Pay Contact',
          subtitle: 'Phone or UPI',
          color: const Color(0xFF26C6DA),
          onTap: onPayContact,
        ),
        const SizedBox(width: 10),
        _ActionCard(
          icon: Icons.edit_rounded,
          label: 'Manual Entry',
          subtitle: 'Cash or card',
          color: const Color(0xFFFFAB40),
          onTap: onManualEntry,
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: Colors.white54,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;

  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
