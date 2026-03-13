import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/category_engine.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/qr_parser.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import '../history/history_screen.dart';
import '../history/manual_expense_entry_screen.dart';
import '../history/transaction_detail_screen.dart';
import '../pay/pay_screen.dart';
import '../pay/qr_scan_screen.dart';
import '../settings/settings_screen.dart';
import 'widgets/transaction_activity_heatmap.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static Future<void> _launchScanPay(BuildContext context) async {
    final qrData = await Navigator.of(context).push<QrPaymentData>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (qrData == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PayScreen(qrData: qrData, paymentMode: AppConstants.modeQrScan),
      ),
    );
  }

  static void _launchPayContact(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PayScreen(paymentMode: AppConstants.modeContact),
      ),
    );
  }

  static void _launchManualEntry(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ManualExpenseEntryScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(smsSyncProvider);
    ref.watch(notificationPipelineProvider);

    final now = DateTime.now();
    final monthKey = DateTime(now.year, now.month);

    final spentAsync = ref.watch(monthlySpendingProvider(monthKey));
    final receivedAsync = ref.watch(monthlyReceivedProvider(monthKey));
    final recentAsync = ref.watch(recentTransactionsProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: Theme.of(context).brightness == Brightness.dark
              ? const [Color(0xFF0A101C), Color(0xFF101828), Color(0xFF0B1220)]
              : const [Color(0xFFF4F8FF), Color(0xFFEEF3FF), Color(0xFFF7FAFF)],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
        children: [
          _DashboardHeader(now: now),
          const SizedBox(height: 20),
          spentAsync.when(
            data: (spent) => receivedAsync.when(
              data: (received) =>
                  _SummaryCard(spent: spent, received: received),
              loading: () => const _SummaryCard.loading(),
              error: (_, __) => const _SummaryCard.loading(),
            ),
            loading: () => const _SummaryCard.loading(),
            error: (_, __) => const _SummaryCard.loading(),
          ),
          const SizedBox(height: 20),
          Text(
            'Quick Actions',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _PaymentActionsRow(
            onScanPay: () => _launchScanPay(context),
            onPayContact: () => _launchPayContact(context),
            onManualEntry: () => _launchManualEntry(context),
          ),
          const SizedBox(height: 20),
          const _DailySpendChart(),
          const SizedBox(height: 20),
          const TransactionActivityHeatmap(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  );
                },
                child: const Text('View All'),
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
                children: items
                    .take(6)
                    .map((txn) => _TransactionTile(txn: txn))
                    .toList(),
              );
            },
            loading: () => const _EmptyCard(message: 'Loading transactions...'),
            error: (_, __) =>
                const _EmptyCard(message: 'Could not load transactions'),
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final DateTime now;

  const _DashboardHeader({required this.now});

  String _greetingForHour(int hour) {
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _greetingForHour(now.hour);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Jeeva',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                Formatters.monthYear(now),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: Theme.of(context).brightness == Brightness.dark
                  ? [const Color(0xFF283247), const Color(0xFF1A2238)]
                  : [const Color(0xFFE9EEFF), const Color(0xFFDCE5FF)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.person_rounded,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF1C2950),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  final double? spent;
  final double? received;

  const _SummaryCard({required this.spent, required this.received});

  const _SummaryCard.loading() : spent = null, received = null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showLoading = spent == null || received == null;
    final currentSpent = spent ?? 0;
    final currentReceived = received ?? 0;

    final now = DateTime.now();
    final budgetAsync = ref.watch(
      monthlyBudgetProvider(DateTime(now.year, now.month)),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: Theme.of(context).brightness == Brightness.dark
              ? const [Color(0xFF141D30), Color(0xFF0D1527)]
              : const [Color(0xFF143D7A), Color(0xFF0E2D5C)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.17),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: budgetAsync.when(
        data: (budget) {
          final limit = (budget?.limitAmount ?? 5000).toDouble();
          final netBalance = currentReceived - currentSpent;
          final remainingRaw = limit - currentSpent;
          final remaining = remainingRaw > 0 ? remainingRaw : 0.0;
          final ratioRaw = limit > 0 ? (currentSpent / limit) : 0.0;
          final ratio = ratioRaw.clamp(0.0, 1.0);
          final usedPercent = (ratioRaw * 100).clamp(0, 100).round();

          final progressColor = ratio < 0.6
              ? const Color(0xFF30D68F)
              : ratio < 0.85
              ? const Color(0xFFFFC857)
              : const Color(0xFFFF6B6B);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Monthly Summary',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                showLoading
                    ? '--'
                    : '${netBalance < 0 ? '-' : ''}${Formatters.currency(netBalance.abs())}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Monthly Budget: ${Formatters.currency(limit)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: showLoading ? 0 : ratio,
                  minHeight: 10,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$usedPercent% of budget used',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.66),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${Formatters.currency(remaining)} remaining',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MetricPill(
                      title: 'Spent',
                      value: showLoading
                          ? '--'
                          : Formatters.currency(currentSpent),
                      color: const Color(0xFFFF5E5E),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricPill(
                      title: 'Received',
                      value: showLoading
                          ? '--'
                          : Formatters.currency(currentReceived),
                      color: const Color(0xFF00E676),
                    ),
                  ),
                ],
              ),
              if (budget == null || budget.limitAmount <= 0) ...[
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                          ),
                          body: const SafeArea(child: SettingsScreen()),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Set Monthly Budget',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const SizedBox(
          height: 160,
          child: Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
        ),
        error: (_, __) => const SizedBox(height: 140),
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
        color: const Color(0xFF3B4050),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
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

class _DailySpendChart extends ConsumerStatefulWidget {
  const _DailySpendChart();

  @override
  ConsumerState<_DailySpendChart> createState() => _DailySpendChartState();
}

class _DailySpendChartState extends ConsumerState<_DailySpendChart> {
  int _selectedDays = 7;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _isLoaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dailyAsync = ref.watch(spendingLastNDaysProvider(_selectedDays));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: Theme.of(context).brightness == Brightness.dark
              ? [const Color(0xFF1A2338), const Color(0xFF131B30)]
              : [const Color(0xFFFFFFFF), const Color(0xFFF5F8FF)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spending Trend',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your daily spending pattern',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _buildDateSelector(),
            ],
          ),
          const SizedBox(height: 26),
          SizedBox(
            height: 220,
            child: dailyAsync.when(
              data: (daily) {
                if (daily.isEmpty) {
                  return const Center(child: Text('No chart data available'));
                }

                final sortedDays = daily.keys.toList()..sort();
                final spots = sortedDays.asMap().entries.map((e) {
                  return FlSpot(e.key.toDouble(), daily[e.value] ?? 0);
                }).toList();

                final maxYValue = spots.fold<double>(0, (m, e) => max(m, e.y));
                final maxY = max<double>(100, maxYValue);

                const gradientColors = [Color(0xFF2575FC), Color(0xFF00C9A7)];

                return TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: _isLoaded ? 0.0 : 1.0, end: 1.0),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (context, animValue, child) {
                    final animatedSpots = spots
                        .map((s) => FlSpot(s.x, s.y * animValue))
                        .toList();
                    return _buildChart(
                      animatedSpots,
                      sortedDays,
                      maxY,
                      gradientColors,
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => const Center(child: Text('Chart unavailable')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [7, 30, 90].map((days) {
          final isSelected = _selectedDays == days;
          return GestureDetector(
            onTap: () {
              if (!isSelected) {
                setState(() => _selectedDays = days);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                '${days}D',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChart(
    List<FlSpot> spots,
    List<DateTime> sortedDays,
    double maxY,
    List<Color> gradientColors,
  ) {
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: max(1, sortedDays.length - 1).toDouble(),
        minY: 0,
        maxY: maxY * 1.15,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: max(1, maxY / 4),
          getDrawingHorizontalLine: (_) => FlLine(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.06),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: max(1, maxY / 3),
              getTitlesWidget: (value, _) {
                if (value == 0 || value > maxY * 1.1)
                  return const SizedBox.shrink();
                String text;
                if (value >= 1000) {
                  text = '${(value / 1000).toStringAsFixed(1)}k';
                } else {
                  text = value.toInt().toString();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    '?$text',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: max(1, (sortedDays.length / 6).floor()).toDouble(),
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= sortedDays.length)
                  return const SizedBox.shrink();
                final date = sortedDays[idx];
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.45),
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
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => const Color(0xFF232533),
            tooltipRoundedRadius: 14,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final date = sortedDays[spot.x.toInt()];
                return LineTooltipItem(
                  '?${spot.y.toStringAsFixed(0)}\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                  children: [
                    TextSpan(
                      text: Formatters.dateShort(date),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
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
            curveSmoothness: 0.35,
            preventCurveOverShooting: true,
            barWidth: 4,
            gradient: LinearGradient(colors: gradientColors),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: gradientColors
                    .map((c) => c.withValues(alpha: 0.30))
                    .toList(),
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, barData) {
                return spot.y != 0 &&
                    (spot.y == maxY || spot.x == sortedDays.length - 1);
              },
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4.5,
                  color: Colors.white,
                  strokeWidth: 3,
                  strokeColor: gradientColors.last,
                );
              },
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }
}

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
          color: const Color(0xFF3C77F6),
          tint: const Color(0xFFE4EEFF),
          onTap: onScanPay,
        ),
        const SizedBox(width: 10),
        _ActionCard(
          icon: Icons.contacts_rounded,
          label: 'Pay Contact',
          color: const Color(0xFF02BFA6),
          tint: const Color(0xFFE3FBF7),
          onTap: onPayContact,
        ),
        const SizedBox(width: 10),
        _ActionCard(
          icon: Icons.add_card_rounded,
          label: 'Add Expense',
          color: const Color(0xFFFF8E3C),
          tint: const Color(0xFFFFEFE1),
          onTap: onManualEntry,
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color tint;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(12),
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
            ],
          ),
        ),
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
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
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
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${txn.category} � ${Formatters.dateRelative(txn.createdAt)}',
        ),
        trailing: Text(
          '${isDebit ? '-' : '+'}${Formatters.currency(txn.amount)}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: amountColor,
            fontWeight: FontWeight.w800,
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
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
