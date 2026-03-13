import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import 'state/subscriptions_provider.dart';
import 'utils/merchant_icon_mapper.dart';
import 'package:intl/intl.dart';

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionsAsyncValue = ref.watch(subscriptionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions'),
        centerTitle: true,
      ),
      body: subscriptionsAsyncValue.when(
        data: (subscriptions) {
          if (subscriptions.isEmpty) {
            return const Center(
              child: Text('No recurring subscriptions detected.'),
            );
          }

          // Calculate summary totals
          double monthlyTotal = 0;
          double yearlyTotal = 0;

          for (final sub in subscriptions) {
            if (sub.frequency == 'Monthly') {
              monthlyTotal += sub.amount;
              yearlyTotal += sub.amount * 12;
            } else if (sub.frequency == 'Yearly') {
              yearlyTotal += sub.amount;
              monthlyTotal += sub.amount / 12;
            } else if (sub.frequency == 'Weekly') {
              monthlyTotal += sub.amount * 4.33;
              yearlyTotal += sub.amount * 52;
            }
          }

          final formatCurrency = NumberFormat.simpleCurrency(name: 'INR', decimalDigits: 0);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, Color(0xFF4DA1FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Subscription Summary',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Monthly Costs',
                                  style: TextStyle(color: Colors.white, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatCurrency.format(monthlyTotal),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Yearly Estimate',
                                  style: TextStyle(color: Colors.white, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatCurrency.format(yearlyTotal),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final sub = subscriptions[index];
                      final dateStr = DateFormat('MMM d, yyyy').format(sub.nextExpectedPayment);
                      final iconWidget = MerchantIconMapper.getIconForMerchant(sub.merchantName, size: 28);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: Center(child: iconWidget),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sub.merchantName,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Next Payment: $dateStr',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.grey.shade600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    formatCurrency.format(sub.amount),
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '/ ${sub.frequency.toLowerCase().replaceAll('ly', '')}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: subscriptions.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 40),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Error analyzing subscriptions: $err'),
        ),
      ),
    );
  }
}
