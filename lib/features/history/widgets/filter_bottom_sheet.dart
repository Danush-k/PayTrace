import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/category_engine.dart';

/// Bottom sheet with grouped filter options:
///   • Direction (All / Expense / Income)
///   • Status (All / Success / Failed / Pending)
///   • Category chips
///   • Date range picker
///   • Amount range slider
class FilterBottomSheet extends StatefulWidget {
  final String directionFilter;   // ALL, DEBIT, CREDIT
  final String statusFilter;      // ALL, SUCCESS, FAILURE, ...
  final String? categoryFilter;
  final DateTimeRange? dateRange;
  final RangeValues? amountRange;
  final ValueChanged<FilterResult> onApply;

  const FilterBottomSheet({
    super.key,
    required this.directionFilter,
    required this.statusFilter,
    this.categoryFilter,
    this.dateRange,
    this.amountRange,
    required this.onApply,
  });

  /// Show as a modal bottom sheet and return the result.
  static Future<FilterResult?> show(
    BuildContext context, {
    required String directionFilter,
    required String statusFilter,
    String? categoryFilter,
    DateTimeRange? dateRange,
    RangeValues? amountRange,
  }) {
    return showModalBottomSheet<FilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterBottomSheet(
        directionFilter: directionFilter,
        statusFilter: statusFilter,
        categoryFilter: categoryFilter,
        dateRange: dateRange,
        amountRange: amountRange,
        onApply: (result) => Navigator.of(context).pop(result),
      ),
    );
  }

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late String _direction;
  late String _status;
  late String? _category;
  late DateTimeRange? _dateRange;
  late RangeValues? _amountRange;

  @override
  void initState() {
    super.initState();
    _direction = widget.directionFilter;
    _status = widget.statusFilter;
    _category = widget.categoryFilter;
    _dateRange = widget.dateRange;
    _amountRange = widget.amountRange;
  }

  int get _activeCount {
    int c = 0;
    if (_direction != 'ALL') c++;
    if (_status != 'ALL') c++;
    if (_category != null) c++;
    if (_dateRange != null) c++;
    if (_amountRange != null) c++;
    return c;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // ─── Handle ───
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ─── Header ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filters',
                    style:
                        Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                  ),
                  if (_activeCount > 0)
                    TextButton(
                      onPressed: () => setState(() {
                        _direction = 'ALL';
                        _status = 'ALL';
                        _category = null;
                        _dateRange = null;
                        _amountRange = null;
                      }),
                      child: const Text('Clear all'),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // ─── Direction Toggle ───
              const _SectionTitle(label: 'Type'),
              const SizedBox(height: 8),
              _ToggleRow(
                options: const ['ALL', 'DEBIT', 'CREDIT'],
                labels: const ['All', 'Expense', 'Income'],
                selected: _direction,
                onChanged: (v) => setState(() => _direction = v),
              ),
              const SizedBox(height: 20),

              // ─── Status Toggle ───
              const _SectionTitle(label: 'Status'),
              const SizedBox(height: 8),
              _ToggleRow(
                options: const [
                  'ALL',
                  AppConstants.statusSuccess,
                  AppConstants.statusFailure,
                  AppConstants.statusSubmitted,
                ],
                labels: const ['All', 'Success', 'Failed', 'Pending'],
                selected: _status,
                onChanged: (v) => setState(() => _status = v),
              ),
              const SizedBox(height: 20),

              // ─── Category ───
              const _SectionTitle(label: 'Category'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CategoryChipBtn(
                    label: 'All',
                    emoji: '📋',
                    isSelected: _category == null,
                    onTap: () => setState(() => _category = null),
                  ),
                  ...AppConstants.defaultCategories.map((cat) {
                    return _CategoryChipBtn(
                      label: cat,
                      emoji: CategoryEngine.categoryIcon(cat),
                      isSelected: _category == cat,
                      onTap: () => setState(
                        () => _category = _category == cat ? null : cat,
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 20),

              // ─── Date Range ───
              const _SectionTitle(label: 'Date Range'),
              const SizedBox(height: 8),
              _DateRangeSelector(
                range: _dateRange,
                onChanged: (v) => setState(() => _dateRange = v),
              ),
              const SizedBox(height: 20),

              // ─── Amount Range ───
              const _SectionTitle(label: 'Amount Range'),
              const SizedBox(height: 8),
              _AmountSlider(
                range: _amountRange,
                onChanged: (v) => setState(() => _amountRange = v),
              ),
              const SizedBox(height: 24),

              // ─── Apply Button ───
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(FilterResult(
                      direction: _direction,
                      status: _status,
                      category: _category,
                      dateRange: _dateRange,
                      amountRange: _amountRange,
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _activeCount > 0
                        ? 'Apply $_activeCount filter${_activeCount > 1 ? 's' : ''}'
                        : 'Apply',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════
//  Filter result model
// ═══════════════════════════════════════════

class FilterResult {
  final String direction;
  final String status;
  final String? category;
  final DateTimeRange? dateRange;
  final RangeValues? amountRange;

  const FilterResult({
    this.direction = 'ALL',
    this.status = 'ALL',
    this.category,
    this.dateRange,
    this.amountRange,
  });

  int get activeCount {
    int c = 0;
    if (direction != 'ALL') c++;
    if (status != 'ALL') c++;
    if (category != null) c++;
    if (dateRange != null) c++;
    if (amountRange != null) c++;
    return c;
  }
}

// ═══════════════════════════════════════════
//  Internal widgets
// ═══════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
    );
  }
}

/// Segmented toggle row (like iOS segmented control)
class _ToggleRow extends StatelessWidget {
  final List<String> options;
  final List<String> labels;
  final String selected;
  final ValueChanged<String> onChanged;

  const _ToggleRow({
    required this.options,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context)
            .scaffoldBackgroundColor
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(options.length, (i) {
          final isActive = selected == options[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(options[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive
                        ? Colors.white
                        : Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Category chip button for filter sheet
class _CategoryChipBtn extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChipBtn({
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.15)
              : Theme.of(context)
                  .scaffoldBackgroundColor
                  .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.5)
                : Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
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

/// Date range selector — tap to pick
class _DateRangeSelector extends StatelessWidget {
  final DateTimeRange? range;
  final ValueChanged<DateTimeRange?> onChanged;

  const _DateRangeSelector({this.range, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: range != null
              ? AppTheme.primary.withValues(alpha: 0.1)
              : Theme.of(context)
                  .scaffoldBackgroundColor
                  .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: range != null
                ? AppTheme.primary.withValues(alpha: 0.4)
                : Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 18,
              color: range != null
                  ? AppTheme.primary
                  : Theme.of(context).textTheme.bodyMedium?.color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                range != null
                    ? '${_fmt(range!.start)} — ${_fmt(range!.end)}'
                    : 'Select date range',
                style: TextStyle(
                  fontSize: 13,
                  color: range != null
                      ? AppTheme.primary
                      : Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ),
            if (range != null)
              GestureDetector(
                onTap: () => onChanged(null),
                child: const Icon(Icons.close_rounded,
                    size: 16, color: AppTheme.primary),
              ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: range ??
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
    if (picked != null) onChanged(picked);
  }
}

/// Amount range slider
class _AmountSlider extends StatelessWidget {
  final RangeValues? range;
  final ValueChanged<RangeValues?> onChanged;

  static const double _max = 50000;

  const _AmountSlider({this.range, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final current = range ?? const RangeValues(0, _max);
    final isActive = range != null;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '₹${current.start.toInt()}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive
                    ? AppTheme.primary
                    : Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            if (isActive)
              GestureDetector(
                onTap: () => onChanged(null),
                child: const Text(
                  'Reset',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            Text(
              current.end >= _max
                  ? '₹${_max.toInt()}+'
                  : '₹${current.end.toInt()}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive
                    ? AppTheme.primary
                    : Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppTheme.primary,
            inactiveTrackColor:
                AppTheme.primary.withValues(alpha: 0.15),
            thumbColor: AppTheme.primary,
            overlayColor: AppTheme.primary.withValues(alpha: 0.1),
            trackHeight: 3,
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: RangeSlider(
            values: current,
            min: 0,
            max: _max,
            divisions: 100,
            onChanged: (v) => onChanged(v),
          ),
        ),
      ],
    );
  }
}
