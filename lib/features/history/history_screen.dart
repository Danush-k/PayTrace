import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/category_engine.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'transaction_detail_screen.dart';

enum _HistoryFilter { all, debit, credit }

class HistoryScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;

  const HistoryScreen({super.key, this.initialDate});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  _HistoryFilter _filter = _HistoryFilter.all;
  DateTime? _dateFilter;

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      final d = widget.initialDate!;
      _dateFilter = DateTime(d.year, d.month, d.day);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allTxnsAsync = ref.watch(allTransactionsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'History',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search transactions',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _filter == _HistoryFilter.all,
                    onTap: () => setState(() => _filter = _HistoryFilter.all),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Debit',
                    selected: _filter == _HistoryFilter.debit,
                    onTap: () => setState(() => _filter = _HistoryFilter.debit),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Credit',
                    selected: _filter == _HistoryFilter.credit,
                    onTap: () => setState(() => _filter = _HistoryFilter.credit),
                  ),
                  if (_dateFilter != null) ...[
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Today',
                      selected: true,
                      onTap: () => setState(() => _dateFilter = null),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: allTxnsAsync.when(
            data: (transactions) {
              final filtered = _applyFilter(transactions);
              if (filtered.isEmpty) {
                return const Center(child: Text('No matching transactions'));
              }

              final grouped = _groupByDate(filtered);
              final keys = grouped.keys.toList()
                ..sort((a, b) => b.compareTo(a));

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
                itemCount: keys.length,
                itemBuilder: (context, index) {
                  final day = keys[index];
                  final dayTxns = grouped[day]!;
                  return _DateGroupSection(day: day, txns: dayTxns);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  List<Transaction> _applyFilter(List<Transaction> items) {
    final query = _searchController.text.trim().toLowerCase();

    return items.where((txn) {
      if (_filter == _HistoryFilter.debit && txn.direction == 'CREDIT') {
        return false;
      }
      if (_filter == _HistoryFilter.credit && txn.direction != 'CREDIT') {
        return false;
      }

      if (query.isEmpty) return true;

      final haystack = [
        txn.payeeName,
        txn.payeeUpiId,
        txn.category,
        txn.transactionNote ?? '',
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).where((txn) {
      if (_dateFilter == null) return true;
      final day = DateTime(txn.createdAt.year, txn.createdAt.month, txn.createdAt.day);
      return day == _dateFilter;
    }).toList();
  }

  Map<DateTime, List<Transaction>> _groupByDate(List<Transaction> txns) {
    final grouped = <DateTime, List<Transaction>>{};
    for (final txn in txns) {
      final day = DateTime(txn.createdAt.year, txn.createdAt.month, txn.createdAt.day);
      grouped.putIfAbsent(day, () => []).add(txn);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return grouped;
  }
}

class _DateGroupSection extends StatelessWidget {
  final DateTime day;
  final List<Transaction> txns;

  const _DateGroupSection({required this.day, required this.txns});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text(
            Formatters.dateRelative(day),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        ...txns.map((txn) => _HistoryTxnTile(txn: txn)),
      ],
    );
  }
}

class _HistoryTxnTile extends StatelessWidget {
  final Transaction txn;

  const _HistoryTxnTile({required this.txn});

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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.14),
          child: Text(
            CategoryEngine.categoryIcon(txn.category),
            style: const TextStyle(fontSize: 15),
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
        subtitle: Text(
          '${txn.category} · ${Formatters.timeOnly(txn.createdAt)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.2)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppTheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? AppTheme.primary : null,
              ),
        ),
      ),
    );
  }
}
