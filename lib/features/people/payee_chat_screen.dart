import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/category_engine.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import '../pay/pay_screen.dart';
import '../history/transaction_detail_screen.dart';

/// GPay-style payee detail screen — shows transaction history as chat bubbles
/// with a "Pay" button at the bottom.
class PayeeChatScreen extends ConsumerStatefulWidget {
  final String payeeName;
  final String payeeUpiId;

  const PayeeChatScreen({
    super.key,
    required this.payeeName,
    required this.payeeUpiId,
  });

  @override
  ConsumerState<PayeeChatScreen> createState() => _PayeeChatScreenState();
}

class _PayeeChatScreenState extends ConsumerState<PayeeChatScreen> {
  List<Transaction>? _transactions;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final db = ref.read(databaseProvider);
    final txns = await db.getTransactionsByPayee(widget.payeeUpiId);
    if (mounted) {
      setState(() {
        _transactions = txns;
        _loading = false;
      });
    }
  }

  double get _totalPaid {
    if (_transactions == null) return 0;
    return _transactions!
        .where((t) => t.status == AppConstants.statusSuccess)
        .fold<double>(0, (sum, t) => sum + t.amount);
  }

  int get _successCount {
    if (_transactions == null) return 0;
    return _transactions!
        .where((t) => t.status == AppConstants.statusSuccess)
        .length;
  }

  /// Group transactions by month label
  Map<String, List<Transaction>> _groupByMonth() {
    final grouped = <String, List<Transaction>>{};
    if (_transactions == null) return grouped;
    for (final txn in _transactions!) {
      final key = Formatters.monthYear(txn.createdAt);
      grouped.putIfAbsent(key, () => []).add(txn);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          // ─── App Bar with payee info ───
          _buildHeader(context, isDark),

          // ─── Transaction list (chat style) ───
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _transactions == null || _transactions!.isEmpty
                    ? _buildEmptyState(context)
                    : _buildChatList(context, isDark),
          ),

          // ─── Bottom Pay Button ───
          _buildPayButton(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.cardDark
            : AppTheme.primary.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Top row with back button and name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      widget.payeeName.isNotEmpty
                          ? widget.payeeName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.payeeName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        Formatters.maskUpiId(widget.payeeUpiId),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Stats row
          if (!_loading && _transactions != null && _transactions!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  _StatChip(
                    label: 'Total paid',
                    value: Formatters.currency(_totalPaid),
                    icon: Icons.payments_outlined,
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    label: 'Payments',
                    value: '$_successCount',
                    icon: Icons.receipt_long_outlined,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 36,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No payments yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Tap Pay below to send money to ${widget.payeeName}',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList(BuildContext context, bool isDark) {
    final grouped = _groupByMonth();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      reverse: false,
      itemCount: grouped.length,
      itemBuilder: (context, groupIndex) {
        final monthLabel = grouped.keys.elementAt(groupIndex);
        final monthTxns = grouped[monthLabel]!;

        return Column(
          children: [
            // Month separator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  monthLabel,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            // Transaction bubbles
            ...monthTxns.map((txn) => _TransactionBubble(
                  transaction: txn,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          TransactionDetailScreen(transaction: txn),
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }

  Widget _buildPayButton(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 0.5,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PayScreen(
                  prefilledUpiId: widget.payeeUpiId,
                  prefilledName: widget.payeeName,
                ),
              ),
            );
            // Reload transactions after returning from payment
            _loadTransactions();
          },
          icon: const Icon(Icons.send_rounded, size: 20),
          label: Text(
            'Pay ${widget.payeeName.split(' ').first}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Stat Chip ───

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.primary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                ),
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Transaction Bubble (chat-style) ───

class _TransactionBubble extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onTap;

  const _TransactionBubble({
    required this.transaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = transaction.status == AppConstants.statusSuccess;
    final isFailed = transaction.status == AppConstants.statusFailure;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final category = transaction.category;

    // Status color and icon
    final statusColor = isSuccess
        ? AppTheme.success
        : isFailed
            ? AppTheme.error
            : AppTheme.warning;
    final statusIcon = isSuccess
        ? Icons.check_circle_rounded
        : isFailed
            ? Icons.cancel_rounded
            : Icons.schedule_rounded;
    final statusLabel = isSuccess
        ? 'Sent'
        : isFailed
            ? 'Failed'
            : transaction.status;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Align(
          // Payments sent → right side (like outgoing messages)
          alignment: Alignment.centerRight,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSuccess
                  ? (isDark
                      ? AppTheme.primary.withValues(alpha: 0.12)
                      : AppTheme.primary.withValues(alpha: 0.08))
                  : isFailed
                      ? (isDark
                          ? AppTheme.error.withValues(alpha: 0.1)
                          : AppTheme.error.withValues(alpha: 0.06))
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.grey.withValues(alpha: 0.08)),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Amount row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      Formatters.currency(transaction.amount),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Category + status + note
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${CategoryEngine.categoryIcon(category)} $category',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),

                // Transaction note
                if (transaction.transactionNote != null &&
                    transaction.transactionNote!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    transaction.transactionNote!,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 4),

                // Time
                Text(
                  Formatters.dateTime(transaction.createdAt),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
