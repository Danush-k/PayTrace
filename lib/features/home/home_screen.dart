import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/category_engine.dart';
import '../../state/providers.dart';
import '../pay/pay_screen.dart';
import '../pay/qr_scan_screen.dart';
import '../../core/constants/app_constants.dart';
import '../history/history_screen.dart';
import '../history/transaction_detail_screen.dart';
import '../history/widgets/transaction_tile.dart';
import '../../core/utils/qr_parser.dart';
import '../people/payee_chat_screen.dart';
import 'notification_permission_banner.dart';

/// Home screen — dashboard with quick actions and recent transactions
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  // Category colors for charts
  static const _categoryColors = [
    Color(0xFFFF6B6B), // Food & Dining
    Color(0xFF4ECDC4), // Shopping
    Color(0xFFFFBE0B), // Transport
    Color(0xFF3A86FF), // Bills & Utilities
    Color(0xFFA855F7), // Entertainment
    Color(0xFFEF4444), // Health
    Color(0xFF22D3EE), // Education
    Color(0xFFFB923C), // Rent
    Color(0xFF6C63FF), // Transfer
    Color(0xFF9E9E9E), // Others
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trigger SMS sync on home screen load
    ref.watch(smsSyncProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Header ───
            SliverToBoxAdapter(
              child: _buildHeader(context, ref),
            ),

            // ─── Notification Permission Banner ───
            const SliverToBoxAdapter(
              child: NotificationPermissionBanner(),
            ),

            // ─── Quick Actions ───
            SliverToBoxAdapter(
              child: _buildQuickActions(context),
            ),

            // ─── Monthly Summary with Category Breakdown ───
            SliverToBoxAdapter(
              child: _buildMonthlySummary(context, ref),
            ),

            // ─── Favorites Strip ───
            SliverToBoxAdapter(
              child: _buildFavoritesStrip(context, ref),
            ),

            // ─── Recurring Payments ───
            SliverToBoxAdapter(
              child: _buildRecurringPayments(context, ref),
            ),

            // ─── Recent Transactions ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Transactions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const HistoryScreen()),
                      ),
                      child: const Text('See all'),
                    ),
                  ],
                ),
              ),
            ),

            // Transaction list
            _buildRecentTransactions(context, ref),

            // Bottom padding
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Row(
        children: [
          // Logo / app icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryDark],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text('₹',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  )),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PayTrace',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text(
                'Track every rupee',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          // Scan & Pay
          Expanded(
            child: _QuickActionCard(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Scan & Pay',
              sublabel: 'Static / Dynamic QR',
              color: AppTheme.primary,
              onTap: () => _handleScanPay(context),
            ),
          ),
          const SizedBox(width: 12),

          // Pay to Contact
          Expanded(
            child: _QuickActionCard(
              icon: Icons.contacts_rounded,
              label: 'Pay Contact',
              sublabel: 'Via UPI app',
              color: AppTheme.success,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const PayScreen(
                      paymentMode: AppConstants.modeContact,
                    )),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Manual Entry
          Expanded(
            child: _QuickActionCard(
              icon: Icons.edit_rounded,
              label: 'Manual',
              sublabel: 'Enter UPI ID',
              color: AppTheme.warning,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PayScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleScanPay(BuildContext context) async {
    final qrData = await Navigator.of(context).push<QrPaymentData>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );

    if (qrData != null && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PayScreen(qrData: qrData),
        ),
      );
    }
  }

  Widget _buildMonthlySummary(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final monthKey = DateTime(now.year, now.month);
    final monthlySpending = ref.watch(monthlySpendingProvider(monthKey));
    final monthlyReceived = ref.watch(monthlyReceivedProvider(monthKey));
    final categorySpending = ref.watch(categorySpendingProvider(monthKey));
    final budgetProgress = ref.watch(budgetProgressProvider(monthKey));
    final budgetAsync = ref.watch(monthlyBudgetProvider(monthKey));
    final smsSync = ref.watch(smsSyncProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primary.withValues(alpha: 0.15),
              AppTheme.primaryDark.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month label
            Text(
              Formatters.monthYear(now),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 6),

            // Total spent
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Sent ',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                monthlySpending.when(
                  data: (amount) => Text(
                    Formatters.currency(amount),
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.error,
                        ),
                  ),
                  loading: () => const SizedBox(
                    width: 80,
                    height: 24,
                    child: LinearProgressIndicator(),
                  ),
                  error: (_, _) => Text(
                    '₹ --',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Total received
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Received ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                monthlyReceived.when(
                  data: (amount) => Text(
                    Formatters.currency(amount),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.success,
                        ),
                  ),
                  loading: () => const SizedBox(
                    width: 60,
                    height: 18,
                    child: LinearProgressIndicator(),
                  ),
                  error: (_, _) => Text(
                    '₹ --',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),

            // SMS sync status indicator
            smsSync.when(
              data: (count) => count > 0
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '✨ $count new ${count == 1 ? 'transaction' : 'transactions'} imported from SMS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.success,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              loading: () => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Syncing SMS...',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),

            // ─── Budget Progress Bar ───
            budgetProgress.when(
              data: (progress) {
                if (progress == null) return const SizedBox.shrink();
                final budgetLimit = budgetAsync.valueOrNull?.limitAmount ?? 0;
                final spent = monthlySpending.valueOrNull ?? 0;
                final color = progress < 0.6
                    ? AppTheme.success
                    : progress < 0.85
                        ? AppTheme.warning
                        : AppTheme.error;

                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Budget',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontSize: 12),
                          ),
                          Text(
                            '${Formatters.currency(spent)} / ${Formatters.currency(budgetLimit)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: color.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation(color),
                          minHeight: 6,
                        ),
                      ),
                      if (progress >= 0.85) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  size: 14, color: AppTheme.error),
                              const SizedBox(width: 4),
                              Text(
                                progress >= 1.0
                                    ? 'Budget exceeded!'
                                    : 'Close to budget limit',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 4),

            // ─── Category Breakdown ───
            categorySpending.when(
              data: (categories) {
                if (categories.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'via PayTrace this month',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                          ),
                    ),
                  );
                }

                final total = categories.values.fold<double>(0, (a, b) => a + b);
                // Show top 4 categories
                final top = categories.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                final display = top.take(4).toList();

                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    children: [
                      // Mini horizontal bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 8,
                          child: Row(
                            children: display.map((e) {
                              final idx = CategoryEngine.categoryColorIndex(e.key);
                              final fraction = total > 0 ? e.value / total : 0.0;
                              return Expanded(
                                flex: (fraction * 100).round().clamp(1, 100),
                                child: Container(
                                  color: _categoryColors[idx % _categoryColors.length],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Category list
                      ...display.map((e) {
                        final idx = CategoryEngine.categoryColorIndex(e.key);
                        final pct = total > 0
                            ? (e.value / total * 100).toStringAsFixed(0)
                            : '0';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _categoryColors[idx % _categoryColors.length],
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${CategoryEngine.categoryIcon(e.key)} ${e.key}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontSize: 12),
                              ),
                              const Spacer(),
                              Text(
                                '${Formatters.currency(e.value)}  $pct%',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Favorites Strip (F5) ───

  Widget _buildFavoritesStrip(BuildContext context, WidgetRef ref) {
    final payeesAsync = ref.watch(topPayeesProvider);

    return payeesAsync.when(
      data: (payees) {
        if (payees.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                'People',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: payees.length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final payee = payees[index];
                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PayeeChatScreen(
                          payeeUpiId: payee.upiId,
                          payeeName: payee.name,
                        ),
                      ),
                    ),
                    child: SizedBox(
                      width: 64,
                      child: Column(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                payee.name.isNotEmpty
                                    ? payee.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            payee.name.split(' ').first,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  // ─── Recurring Payments (F3) ───

  Widget _buildRecurringPayments(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringPaymentsProvider);

    return recurringAsync.when(
      data: (payments) {
        if (payments.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.repeat_rounded, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Upcoming',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: payments.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final rp = payments[index];
                  final daysUntil = rp.nextExpectedDate != null
                      ? rp.nextExpectedDate!.difference(DateTime.now()).inDays
                      : 0;

                  return Container(
                    width: 180,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                rp.payeeName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                rp.frequency,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '~${Formatters.currency(rp.averageAmount)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Text(
                              daysUntil <= 0
                                  ? 'Due today'
                                  : daysUntil == 1
                                      ? 'Tomorrow'
                                      : 'In $daysUntil days',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: daysUntil <= 1
                                    ? AppTheme.warning
                                    : Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color ??
                                        Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildRecentTransactions(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentTransactionsProvider);

    return recentAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_rounded,
                      size: 48, color: Colors.grey.shade600),
                  const SizedBox(height: 12),
                  Text(
                    'No transactions yet',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Scan a QR code or pay a contact to get started',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => TransactionTile(
              transaction: transactions[index],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TransactionDetailScreen(
                    transaction: transactions[index],
                  ),
                ),
              ),
            ),
            childCount: transactions.length,
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Center(child: Text('Error: $e')),
      ),
    );
  }
}

/// Quick action card widget
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 10,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
