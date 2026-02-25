import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/category_engine.dart';

/// Enhanced filter bar for transaction history
/// Supports: status filter, category filter, date range, amount range
class FilterBar extends StatelessWidget {
  final String selectedStatus;
  final ValueChanged<String> onStatusChanged;
  final String? selectedCategory;
  final ValueChanged<String?> onCategoryChanged;
  final DateTimeRange? selectedDateRange;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;
  final RangeValues? amountRange;
  final ValueChanged<RangeValues?> onAmountRangeChanged;

  const FilterBar({
    super.key,
    required this.selectedStatus,
    required this.onStatusChanged,
    this.selectedCategory,
    required this.onCategoryChanged,
    this.selectedDateRange,
    required this.onDateRangeChanged,
    this.amountRange,
    required this.onAmountRangeChanged,
  });

  static const _statusFilters = [
    ('All', 'ALL'),
    ('Success', AppConstants.statusSuccess),
    ('Failed', AppConstants.statusFailure),
    ('Pending', AppConstants.statusSubmitted),
    ('Cancelled', AppConstants.statusCancelled),
  ];

  int get _activeFilterCount {
    int count = 0;
    if (selectedStatus != 'ALL') count++;
    if (selectedCategory != null) count++;
    if (selectedDateRange != null) count++;
    if (amountRange != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Row 1: Status filters + action buttons ───
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Date range button
              _FilterButton(
                icon: Icons.calendar_month_rounded,
                label: selectedDateRange != null ? 'Date ✓' : 'Date',
                isActive: selectedDateRange != null,
                onTap: () => _pickDateRange(context),
              ),
              const SizedBox(width: 8),
              // Amount range button
              _FilterButton(
                icon: Icons.currency_rupee_rounded,
                label: amountRange != null ? 'Amount ✓' : 'Amount',
                isActive: amountRange != null,
                onTap: () => _showAmountRangeSheet(context),
              ),
              const SizedBox(width: 8),
              const VerticalDivider(indent: 6, endIndent: 6, width: 16),
              // Status chips
              ..._statusFilters.map((f) {
                final (label, value) = f;
                final isSelected = selectedStatus == value;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (_) => onStatusChanged(value),
                    selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.primary : null,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }),
            ],
          ),
        ),

        // ─── Row 2: Category filter chips ───
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // "All categories" chip
              _CategoryChip(
                label: 'All',
                icon: '📋',
                isSelected: selectedCategory == null,
                onTap: () => onCategoryChanged(null),
              ),
              const SizedBox(width: 6),
              ...AppConstants.defaultCategories.map((cat) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _CategoryChip(
                    label: cat.split(' ').first, // Short label
                    icon: CategoryEngine.categoryIcon(cat),
                    isSelected: selectedCategory == cat,
                    onTap: () => onCategoryChanged(
                      selectedCategory == cat ? null : cat,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        // ─── Active filter indicators ───
        if (_activeFilterCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Icon(Icons.filter_list_rounded,
                    size: 14, color: AppTheme.primary),
                const SizedBox(width: 4),
                Text(
                  '$_activeFilterCount filter${_activeFilterCount > 1 ? 's' : ''} active',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    onStatusChanged('ALL');
                    onCategoryChanged(null);
                    onDateRangeChanged(null);
                    onAmountRangeChanged(null);
                  },
                  child: const Text(
                    'Clear all',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: selectedDateRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          ),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppTheme.primary,
              ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      onDateRangeChanged(picked);
    }
  }

  void _showAmountRangeSheet(BuildContext context) {
    final minCtrl = TextEditingController(
      text: amountRange?.start.toStringAsFixed(0) ?? '',
    );
    final maxCtrl = TextEditingController(
      text: amountRange?.end.toStringAsFixed(0) ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter by Amount',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: minCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Min (₹)',
                      hintText: '0',
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('—'),
                ),
                Expanded(
                  child: TextField(
                    controller: maxCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max (₹)',
                      hintText: '10000',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Quick presets
            Wrap(
              spacing: 8,
              children: [
                _QuickAmountChip('< ₹100', () {
                  minCtrl.text = '0';
                  maxCtrl.text = '100';
                }),
                _QuickAmountChip('₹100–500', () {
                  minCtrl.text = '100';
                  maxCtrl.text = '500';
                }),
                _QuickAmountChip('₹500–2K', () {
                  minCtrl.text = '500';
                  maxCtrl.text = '2000';
                }),
                _QuickAmountChip('> ₹2K', () {
                  minCtrl.text = '2000';
                  maxCtrl.text = '';
                }),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (amountRange != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        onAmountRangeChanged(null);
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Clear'),
                    ),
                  ),
                if (amountRange != null) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final min =
                          double.tryParse(minCtrl.text) ?? 0;
                      final max =
                          double.tryParse(maxCtrl.text) ?? double.infinity;
                      onAmountRangeChanged(RangeValues(min, max));
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper Widgets ───

class _FilterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primary.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? AppTheme.primary.withValues(alpha: 0.4)
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: isActive
                    ? AppTheme.primary
                    : Theme.of(context).textTheme.bodyMedium?.color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? AppTheme.primary
                    : Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final String icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.5)
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppTheme.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAmountChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickAmountChip(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}
