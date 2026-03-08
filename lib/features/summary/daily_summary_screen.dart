import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/providers.dart';
import '../history/history_screen.dart';

class DailySummaryScreen extends ConsumerWidget {
  const DailySummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final transactionsAsync = ref.watch(allTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Today's Spending")),
      body: transactionsAsync.when(
        data: (transactions) {
          final start = DateTime(now.year, now.month, now.day);
          final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

          final today = transactions.where((txn) {
            final dt = txn.createdAt;
            final inRange = !dt.isBefore(start) && !dt.isAfter(end);
            return inRange && txn.direction == 'DEBIT' && txn.amount > 0;
          }).toList();

          final totalSpent = today.fold<double>(0, (sum, t) => sum + t.amount);
          final byCategory = <String, double>{};
          for (final txn in today) {
            byCategory.update(
              txn.category,
              (value) => value + txn.amount,
              ifAbsent: () => txn.amount,
            );
          }

          final sorted = byCategory.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            children: [
              _SummaryHeader(totalSpent: totalSpent),
              const SizedBox(height: 16),
              if (sorted.isNotEmpty)
                _CategoryPieChart(categoryTotals: sorted)
              else
                _EmptyStateCard(),
              const SizedBox(height: 16),
              if (sorted.isNotEmpty)
                _CategoryBreakdown(categoryTotals: sorted),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HistoryScreen(initialDate: now),
                      ),
                    );
                  },
                  child: const Text('View All Transactions'),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final double totalSpent;

  const _SummaryHeader({required this.totalSpent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total spent today',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            Formatters.currency(totalSpent),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  final List<MapEntry<String, double>> categoryTotals;

  const _CategoryPieChart({required this.categoryTotals});

  @override
  Widget build(BuildContext context) {
    final total = categoryTotals.fold<double>(0, (sum, e) => sum + e.value);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: SizedBox(
        height: 220,
        child: PieChart(
          PieChartData(
            centerSpaceRadius: 52,
            sectionsSpace: 2,
            sections: categoryTotals.map((entry) {
              return PieChartSectionData(
                value: entry.value,
                title: total > 0
                    ? '${((entry.value / total) * 100).toStringAsFixed(0)}%'
                    : '',
                titleStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
                radius: 44,
                color: _colorForCategory(entry.key),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Color _colorForCategory(String category) {
    const palette = [
      Color(0xFF6C63FF),
      Color(0xFF00C853),
      Color(0xFFFFAB40),
      Color(0xFFFF5252),
      Color(0xFF40C4FF),
      Color(0xFFEC407A),
      Color(0xFF8E24AA),
    ];
    return palette[category.hashCode.abs() % palette.length];
  }
}

class _CategoryBreakdown extends StatelessWidget {
  final List<MapEntry<String, double>> categoryTotals;

  const _CategoryBreakdown({required this.categoryTotals});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Breakdown by category',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          ...categoryTotals.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _colorForCategory(entry.key),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  Text(
                    Formatters.currency(entry.value),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
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

  Color _colorForCategory(String category) {
    const palette = [
      Color(0xFF6C63FF),
      Color(0xFF00C853),
      Color(0xFFFFAB40),
      Color(0xFFFF5252),
      Color(0xFF40C4FF),
      Color(0xFFEC407A),
      Color(0xFF8E24AA),
    ];
    return palette[category.hashCode.abs() % palette.length];
  }
}

class _EmptyStateCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Text(
        'No expenses recorded today.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}
