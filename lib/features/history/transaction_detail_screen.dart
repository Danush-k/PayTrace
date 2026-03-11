import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/app_database.dart';
import '../../services/merchant_learning_service.dart';
import '../../state/providers.dart';

/// Full detail view of a single transaction
class TransactionDetailScreen extends ConsumerWidget {
  final Transaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = AppTheme.statusColor(transaction.status);
    final isSuccess = transaction.status == AppConstants.statusSuccess;
    final isInitiated = transaction.status == AppConstants.statusInitiated;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, ref, value),
            itemBuilder: (_) => [
              if (isInitiated)
                const PopupMenuItem(
                  value: 'mark_success',
                  child: ListTile(
                    leading: Icon(Icons.check_circle_outline, size: 20,
                        color: Colors.green),
                    title: Text('Mark as Paid',
                        style: TextStyle(color: Colors.green)),
                    dense: true,
                  ),
                ),
              if (isInitiated)
                const PopupMenuItem(
                  value: 'mark_failed',
                  child: ListTile(
                    leading: Icon(Icons.cancel_outlined, size: 20,
                        color: Colors.red),
                    title: Text('Mark as Failed',
                        style: TextStyle(color: Colors.red)),
                    dense: true,
                  ),
                ),
              const PopupMenuItem(
                value: 'category',
                child: ListTile(
                  leading: Icon(Icons.category_rounded, size: 20),
                  title: Text('Change Category'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'edit_name',
                child: ListTile(
                  leading: Icon(Icons.person_outline_rounded, size: 20),
                  title: Text('Edit Name'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'copy',
                child: ListTile(
                  leading: Icon(Icons.copy_rounded, size: 20),
                  title: Text('Copy Txn ID'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading:
                      Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  title: Text('Delete', style: TextStyle(color: Colors.red)),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ─── Update Status Banner (for INITIATED transactions) ───
            if (isInitiated) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Did you complete this payment?',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await ref.read(databaseProvider)
                                  .updateTransactionStatus(
                                id: transaction.id,
                                status: AppConstants.statusFailure,
                              );
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Marked as failed'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('No'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await ref.read(databaseProvider)
                                  .updateTransactionStatus(
                                id: transaction.id,
                                status: AppConstants.statusSuccess,
                              );
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Marked as paid!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Yes, paid'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ─── Status Header ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    statusColor.withValues(alpha: 0.15),
                    statusColor.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(
                    isSuccess
                        ? Icons.check_circle_rounded
                        : transaction.status == AppConstants.statusFailure
                            ? Icons.cancel_rounded
                            : Icons.hourglass_top_rounded,
                    color: statusColor,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    Formatters.currency(transaction.amount),
                    style:
                        Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      transaction.status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── Detail Rows ───
            _buildSection(context, 'Payee Information', [
              _detailRow(context, 'Name', transaction.payeeName),
              _detailRow(context, 'UPI ID', transaction.payeeUpiId),
            ]),

            const SizedBox(height: 16),

            _buildSection(context, 'Payment Details', [
              _detailRow(
                  context, 'Amount', Formatters.currency(transaction.amount)),
              _detailRow(context, 'Mode', _getModeName()),
              if (transaction.qrType != null)
                _detailRow(context, 'QR Type', transaction.qrType!),
              if (transaction.transactionNote != null &&
                  transaction.transactionNote!.isNotEmpty)
                _detailRow(
                    context, 'Note', transaction.transactionNote!),
              _detailRow(context, 'Category', transaction.category),
            ]),

            const SizedBox(height: 16),

            _buildSection(context, 'Transaction Info', [
              if (transaction.upiTxnId != null)
                _detailRow(
                    context, 'UPI Txn ID', transaction.upiTxnId!),
              _detailRow(context, 'Ref', transaction.transactionRef),
              if (transaction.approvalRefNo != null)
                _detailRow(
                    context, 'Approval Ref', transaction.approvalRefNo!),
              if (transaction.upiAppName != null)
                _detailRow(context, 'Paid via', transaction.upiAppName!),
              _detailRow(
                  context, 'Date', Formatters.dateTime(transaction.createdAt)),
              _detailRow(context, 'Last Updated',
                  Formatters.dateTime(transaction.updatedAt)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
      BuildContext context, String title, List<Widget> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 12,
                ),
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  String _getModeName() {
    switch (transaction.paymentMode) {
      case AppConstants.modeQrScan:
        return 'QR Scan';
      case AppConstants.modeContact:
        return 'Contact Payment';
      case AppConstants.modeManual:
        final method = transaction.upiAppName;
        if (method != null && method.isNotEmpty) {
          return 'Manual Entry ($method)';
        }
        return 'Manual Entry';
      case 'SMS_IMPORT':
        return transaction.direction == 'CREDIT'
            ? 'Received via SMS'
            : 'Detected via SMS';
      default:
        return transaction.paymentMode;
    }
  }

  Future<void> _handleMenuAction(
      BuildContext context, WidgetRef ref, String action) async {
    switch (action) {
      case 'copy':
        final id = transaction.upiTxnId ?? transaction.transactionRef;
        Clipboard.setData(ClipboardData(text: id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction ID copied')),
        );
        break;

      case 'category':
        _showCategoryPicker(context, ref);
        break;

      case 'edit_name':
        _showEditNameDialog(context, ref);
        break;

      case 'delete':
        _confirmDelete(context, ref);
        break;

      case 'mark_success':
        await ref.read(databaseProvider).updateTransactionStatus(
              id: transaction.id,
              status: AppConstants.statusSuccess,
            );
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Marked as paid!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        break;

      case 'mark_failed':
        await ref.read(databaseProvider).updateTransactionStatus(
              id: transaction.id,
              status: AppConstants.statusFailure,
            );
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Marked as failed')),
          );
        }
        break;
    }
  }

  void _showCategoryPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Category',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Future transactions from the same merchant will use this category automatically.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.defaultCategories.map((cat) {
                final isSelected = transaction.category == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) async {
                    final db = ref.read(databaseProvider);

                    // 1. Update this transaction's category
                    await db.updateTransactionCategory(transaction.id, cat);

                    // 2. Persist the merchant → category mapping so future
                    //    transactions from the same merchant use this category.
                    await MerchantLearningService.learn(
                      db,
                      payeeName: transaction.payeeName,
                      upiId: transaction.payeeUpiId,
                      category: cat,
                    );

                    final merchantKey = MerchantLearningService.normalizeKey(
                      transaction.payeeName,
                      transaction.payeeUpiId,
                    );

                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Category saved. "$merchantKey" will always be "$cat".',
                          ),
                          backgroundColor: AppTheme.success,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content:
            const Text('This will permanently remove this transaction record.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(databaseProvider).deleteTransaction(transaction.id);
              if (context.mounted) {
                Navigator.of(context).pop(); // dialog
                Navigator.of(context).pop(); // detail screen
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Show dialog to edit the payee/payer name.
  /// The edited name is saved to the payee record AND batch-updates
  /// ALL past transactions with the same UPI ID.
  void _showEditNameDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: transaction.payeeName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          transaction.direction == 'CREDIT' ? 'Who sent this?' : 'Who received this?',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This will update the name on all transactions with the same UPI ID.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Mom, John Doe',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.person_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              final db = ref.read(databaseProvider);

              // Batch-update ALL transactions with this UPI ID
              await db.updateAllTransactionsPayeeName(
                transaction.payeeUpiId, name);

              // Also update the payee record so future imports reuse this name
              final payee = await db.getPayeeByUpiId(transaction.payeeUpiId);
              if (payee != null) {
                await db.updatePayeeName(payee.id, name);
              }

              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                Navigator.pop(context); // Pop detail screen to refresh
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Updated name to "$name"'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
