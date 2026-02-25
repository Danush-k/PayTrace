import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../data/database/app_database.dart';
import '../../services/export_service.dart';
import '../../state/providers.dart';
import 'transaction_detail_screen.dart';
import 'widgets/filter_bar.dart';
import 'widgets/transaction_tile.dart';

/// Full transaction history with search, filter, and export
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _statusFilter = 'ALL';
  String _searchQuery = '';
  String? _categoryFilter;
  DateTimeRange? _dateRange;
  RangeValues? _amountRange;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Transaction> _applyFilters(List<Transaction> transactions) {
    var filtered = transactions;

    // Status filter
    if (_statusFilter != 'ALL') {
      filtered =
          filtered.where((t) => t.status == _statusFilter).toList();
    }

    // Category filter
    if (_categoryFilter != null) {
      filtered =
          filtered.where((t) => t.category == _categoryFilter).toList();
    }

    // Date range filter
    if (_dateRange != null) {
      filtered = filtered.where((t) {
        return t.createdAt.isAfter(
                _dateRange!.start.subtract(const Duration(seconds: 1))) &&
            t.createdAt.isBefore(
                _dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    // Amount range filter
    if (_amountRange != null) {
      filtered = filtered.where((t) {
        final min = _amountRange!.start;
        final max = _amountRange!.end;
        return t.amount >= min &&
            (max == double.infinity || t.amount <= max);
      }).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((t) {
        return t.payeeName.toLowerCase().contains(q) ||
            t.payeeUpiId.toLowerCase().contains(q) ||
            (t.transactionNote?.toLowerCase().contains(q) ?? false) ||
            t.category.toLowerCase().contains(q);
      }).toList();
    }

    return filtered;
  }

  /// Group transactions by date
  Map<String, List<Transaction>> _groupByDate(List<Transaction> txns) {
    final grouped = <String, List<Transaction>>{};
    for (final txn in txns) {
      final key = Formatters.dateRelative(txn.createdAt);
      grouped.putIfAbsent(key, () => []).add(txn);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final txnAsync = ref.watch(allTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          // Export button
          txnAsync.whenOrNull(
                data: (txns) => IconButton(
                  icon: const Icon(Icons.file_download_outlined),
                  tooltip: 'Export CSV',
                  onPressed: txns.isEmpty
                      ? null
                      : () {
                          final filtered = _applyFilters(txns);
                          ExportService.exportToCsv(
                              filtered.isEmpty ? txns : filtered);
                        },
                ),
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by name, UPI ID, category...',
                prefixIcon:
                    const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
          ),

          // Enhanced filter bar
          FilterBar(
            selectedStatus: _statusFilter,
            onStatusChanged: (v) => setState(() => _statusFilter = v),
            selectedCategory: _categoryFilter,
            onCategoryChanged: (v) => setState(() => _categoryFilter = v),
            selectedDateRange: _dateRange,
            onDateRangeChanged: (v) => setState(() => _dateRange = v),
            amountRange: _amountRange,
            onAmountRangeChanged: (v) => setState(() => _amountRange = v),
          ),

          const SizedBox(height: 8),

          // Transaction list
          Expanded(
            child: txnAsync.when(
              data: (allTxns) {
                final filtered = _applyFilters(allTxns);

                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }

                final grouped = _groupByDate(filtered);

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final dateLabel = grouped.keys.elementAt(index);
                    final dateTxns = grouped[dateLabel]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              20, 16, 20, 8),
                          child: Text(
                            dateLabel,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                          ),
                        ),
                        ...dateTxns.map((txn) => TransactionTile(
                              transaction: txn,
                              onTap: () => _openDetail(txn),
                            )),
                      ],
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Error: $e'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilters = _searchQuery.isNotEmpty ||
        _statusFilter != 'ALL' ||
        _categoryFilter != null ||
        _dateRange != null ||
        _amountRange != null;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 64, color: Colors.grey.shade600),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'No matching transactions'
                : 'No transactions yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            hasFilters
                ? 'Try adjusting your filters'
                : 'Your payments will appear here',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (hasFilters) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => setState(() {
                _searchQuery = '';
                _searchController.clear();
                _statusFilter = 'ALL';
                _categoryFilter = null;
                _dateRange = null;
                _amountRange = null;
              }),
              icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
              label: const Text('Clear all filters'),
            ),
          ],
        ],
      ),
    );
  }

  void _openDetail(Transaction txn) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(transaction: txn),
      ),
    );
  }
}
