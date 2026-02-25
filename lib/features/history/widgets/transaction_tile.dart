import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/database/app_database.dart';

/// A single transaction list item — used in history & home screen
class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = AppTheme.statusColor(transaction.status);
    final isSuccess = transaction.status == AppConstants.statusSuccess;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // ─── Avatar ───
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  _getInitial(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // ─── Details ───
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.payeeName,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      // Payment mode icon
                      Icon(
                        _getModeIcon(),
                        size: 12,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_getModeName()} • ${Formatters.dateRelative(transaction.createdAt)}',
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 12,
                                ),
                      ),
                    ],
                  ),
                  if (transaction.transactionNote != null &&
                      transaction.transactionNote!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '📝 ${transaction.transactionNote}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // ─── Amount & Status ───
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${transaction.direction == 'CREDIT' ? '+ ' : '- '}${Formatters.currency(transaction.amount)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: transaction.direction == 'CREDIT'
                            ? AppTheme.success
                            : (isSuccess ? null : statusColor),
                      ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    transaction.status,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getInitial() {
    if (transaction.payeeName.isEmpty) return '?';
    return transaction.payeeName[0].toUpperCase();
  }

  IconData _getModeIcon() {
    switch (transaction.paymentMode) {
      case AppConstants.modeQrScan:
        return Icons.qr_code_2_rounded;
      case AppConstants.modeContact:
        return Icons.contacts_rounded;
      case AppConstants.modeManual:
        return Icons.edit_rounded;
      case 'SMS_IMPORT':
        return Icons.sms_rounded;
      default:
        return Icons.payment_rounded;
    }
  }

  String _getModeName() {
    switch (transaction.paymentMode) {
      case AppConstants.modeQrScan:
        return transaction.qrType == AppConstants.qrTypeDynamic
            ? 'Dynamic QR'
            : 'QR Scan';
      case AppConstants.modeContact:
        return 'Contact';
      case AppConstants.modeManual:
        return 'Manual';
      case 'SMS_IMPORT':
        return transaction.direction == 'CREDIT' ? 'Received' : 'SMS';
      default:
        return 'Payment';
    }
  }
}
