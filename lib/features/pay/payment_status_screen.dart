import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/providers.dart';

/// Payment result screen — shown after user confirms payment status
class PaymentStatusScreen extends StatelessWidget {
  final PaymentFlowStatus status;
  final String payeeName;
  final double amount;
  final String? transactionId;

  const PaymentStatusScreen({
    super.key,
    required this.status,
    required this.payeeName,
    required this.amount,
    this.transactionId,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = status == PaymentFlowStatus.success;
    final isFailed = status == PaymentFlowStatus.failure;
    final isCancelled = status == PaymentFlowStatus.cancelled;

    final statusColor = isSuccess
        ? AppTheme.success
        : isFailed
            ? AppTheme.error
            : isCancelled
                ? AppTheme.cancelled
                : AppTheme.warning;

    final statusIcon = isSuccess
        ? Icons.check_circle_rounded
        : isFailed
            ? Icons.cancel_rounded
            : isCancelled
                ? Icons.do_disturb_rounded
                : Icons.hourglass_top_rounded;

    final statusText = isSuccess
        ? 'Payment Successful!'
        : isFailed
            ? 'Payment Failed'
            : isCancelled
                ? 'Payment Cancelled'
                : 'Payment Pending';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Status icon with animated container
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.15),
                ),
                child: Icon(statusIcon, size: 56, color: statusColor),
              ),
              const SizedBox(height: 24),

              // Status text
              Text(
                statusText,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),

              // Amount
              Text(
                Formatters.currency(amount),
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'to $payeeName',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey,
                    ),
              ),

              const SizedBox(height: 40),

              // Transaction details card
              _buildDetailsCard(context),

              const Spacer(flex: 3),

              // Actions
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // Pop back to home
                    Navigator.of(context)
                        .popUntil((route) => route.isFirst);
                  },
                  child: const Text('Done'),
                ),
              ),
              const SizedBox(height: 12),
              if (isFailed || isCancelled)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Try Again'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      child: Column(
        children: [
          if (transactionId != null)
            _detailRow(context, 'Tracking ID', transactionId!),
          _detailRow(
            context,
            'Status',
            status == PaymentFlowStatus.success ? 'Confirmed' : 'Not completed',
          ),
          _detailRow(
            context,
            'Time',
            Formatters.dateTime(DateTime.now()),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
