import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/providers.dart';

/// Month-navigable summary card showing Spent / Received totals
/// Inspired by Money Manager's clean monthly overview.
class MonthlySummaryCard extends ConsumerWidget {
  final DateTime selectedMonth;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final bool canGoNext;

  const MonthlySummaryCard({
    super.key,
    required this.selectedMonth,
    required this.onPrevMonth,
    required this.onNextMonth,
    this.canGoNext = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spent = ref.watch(monthlySpendingProvider(selectedMonth));
    final received = ref.watch(monthlyReceivedProvider(selectedMonth));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          // ─── Month Navigator ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavButton(
                icon: Icons.chevron_left_rounded,
                onTap: onPrevMonth,
              ),
              Text(
                Formatters.monthYear(selectedMonth),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
              ),
              _NavButton(
                icon: Icons.chevron_right_rounded,
                onTap: canGoNext ? onNextMonth : null,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ─── Spent / Received Row ───
          Row(
            children: [
              // Expense column
              Expanded(
                child: _SummaryColumn(
                  label: 'Spent',
                  icon: Icons.arrow_upward_rounded,
                  iconColor: AppTheme.error,
                  value: spent.whenOrNull(data: (v) => v) ?? 0,
                  isLoading: spent.isLoading,
                ),
              ),
              // Divider
              Container(
                width: 1,
                height: 40,
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.3),
              ),
              // Income column
              Expanded(
                child: _SummaryColumn(
                  label: 'Received',
                  icon: Icons.arrow_downward_rounded,
                  iconColor: AppTheme.success,
                  value: received.whenOrNull(data: (v) => v) ?? 0,
                  isLoading: received.isLoading,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small chevron button for month navigation
class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _NavButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled
              ? AppTheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled
              ? AppTheme.primary
              : Theme.of(context)
                  .colorScheme
                  .outline
                  .withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

/// A single Spent / Received summary column
class _SummaryColumn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final double value;
  final bool isLoading;

  const _SummaryColumn({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.value,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 14, color: iconColor),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                Formatters.currencyCompact(value),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: iconColor,
                    ),
              ),
      ],
    );
  }
}
