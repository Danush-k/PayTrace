import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/category_engine.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/database/app_database.dart';

/// Redesigned transaction tile — clean, minimal, Money Manager-inspired.
///
/// Layout:
/// ┌──────────────────────────────────────────────┐
/// │  [🍔]   Swiggy               ─ ₹249.00      │
/// │         Food · UPI · 3:45 PM                 │
/// └──────────────────────────────────────────────┘
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
    final isCredit = transaction.direction == 'CREDIT';
    final amountColor = isCredit ? AppTheme.success : AppTheme.error;
    final categoryEmoji = CategoryEngine.categoryIcon(transaction.category);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // ─── Category Icon ───
            _CategoryAvatar(
              emoji: categoryEmoji,
              isCredit: isCredit,
            ),
            const SizedBox(width: 14),

            // ─── Name + Subtitle ───
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.payeeName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _subtitle(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          letterSpacing: 0.1,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // ─── Amount ───
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isCredit ? '+' : '−'} ${Formatters.currency(transaction.amount)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: amountColor,
                      ),
                ),
                // Status badge — only for non-success
                if (transaction.status != AppConstants.statusSuccess) ...[
                  const SizedBox(height: 4),
                  _StatusBadge(status: transaction.status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build subtitle: "Food · QR Scan · 3:45 PM"
  String _subtitle() {
    final parts = <String>[];

    // Category short name
    final cat = transaction.category.split(' ').first;
    if (cat.isNotEmpty && cat != 'Others') {
      parts.add(cat);
    }

    // Payment mode
    parts.add(_modeName());

    // Time
    parts.add(Formatters.timeOnly(transaction.createdAt));

    return parts.join(' · ');
  }

  String _modeName() {
    switch (transaction.paymentMode) {
      case AppConstants.modeQrScan:
        return transaction.qrType == AppConstants.qrTypeDynamic
            ? 'Dynamic QR'
            : 'QR Scan';
      case AppConstants.modeContact:
        return 'Contact';
      case AppConstants.modeManual:
        final method = transaction.upiAppName;
        if (method != null && method.isNotEmpty) {
          return 'Manual $method';
        }
        return 'Manual';
      case 'SMS_IMPORT':
        return 'UPI';
      default:
        return 'Payment';
    }
  }
}

/// Category icon avatar — circular with subtle tint
class _CategoryAvatar extends StatelessWidget {
  final String emoji;
  final bool isCredit;

  const _CategoryAvatar({required this.emoji, required this.isCredit});

  @override
  Widget build(BuildContext context) {
    final tint = isCredit
        ? AppTheme.success.withValues(alpha: 0.12)
        : AppTheme.primary.withValues(alpha: 0.12);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 20),
      ),
    );
  }
}

/// Small colored badge for non-success statuses
class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
