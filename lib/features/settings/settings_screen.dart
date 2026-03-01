import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/app_database.dart';
import '../../services/export_service.dart';
import '../../services/upi_service.dart';
import '../../state/providers.dart';

/// Settings screen — theme, budget, export, about
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final now = DateTime.now();
    final monthKey = DateTime(now.year, now.month);
    final budgetAsync = ref.watch(monthlyBudgetProvider(monthKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ─── Appearance Section ───
          _SectionHeader(title: 'Appearance'),
          _buildThemeSelector(context, ref, themeMode),

          const SizedBox(height: 8),

          // ─── Budget Section ───
          _SectionHeader(title: 'Budget'),
          _buildBudgetTile(context, ref, budgetAsync, now),

          const SizedBox(height: 8),

          // ─── Data Section ───
          _SectionHeader(title: 'Data'),
          _buildExportTile(context, ref),

          const SizedBox(height: 8),

          // ─── Permissions Section (Android only) ───
          if (!kIsWeb) ..._buildPermissionsSection(context, ref),

          const SizedBox(height: 8),

          // ─── About Section ───
          _SectionHeader(title: 'About'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'PayTrace',
            subtitle: 'Version ${AppConstants.appVersion}',
            trailing: const SizedBox.shrink(),
          ),
          _SettingsTile(
            icon: Icons.favorite_outline_rounded,
            title: 'Made with Flutter',
            subtitle: 'UPI Payment Tracker',
            trailing: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector(
      BuildContext context, WidgetRef ref, ThemeMode current) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Theme',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.phone_android_rounded, size: 16),
                    label: Text('System'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_rounded, size: 16),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_rounded, size: 16),
                    label: Text('Dark'),
                  ),
                ],
                selected: {current},
                onSelectionChanged: (modes) {
                  ref.read(themeModeProvider.notifier).setThemeMode(modes.first);
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetTile(BuildContext context, WidgetRef ref,
      AsyncValue<Budget?> budgetAsync, DateTime now) {
    return budgetAsync.when(
      data: (budget) {
        final hasLimit = budget != null && budget.limitAmount > 0;
        return _SettingsTile(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Monthly Budget',
          subtitle: hasLimit
              ? '${Formatters.currency(budget.limitAmount)} for ${Formatters.monthYear(now)}'
              : 'No budget set for ${Formatters.monthYear(now)}',
          trailing: Icon(Icons.chevron_right_rounded,
              color: Theme.of(context).textTheme.bodyMedium?.color),
          onTap: () => _showBudgetSheet(context, ref, budget, now),
        );
      },
      loading: () => _SettingsTile(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Monthly Budget',
        subtitle: 'Loading...',
        trailing: const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => _SettingsTile(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Monthly Budget',
        subtitle: 'Error loading budget',
        trailing: const SizedBox.shrink(),
      ),
    );
  }

  List<Widget> _buildPermissionsSection(BuildContext context, WidgetRef ref) {
    return [
      _SectionHeader(title: 'Permissions'),
      _SettingsTile(
        icon: Icons.sms_outlined,
        title: 'SMS Access',
        subtitle: 'Required for auto-detecting bank transactions',
        trailing: Icon(Icons.chevron_right_rounded,
            color: Theme.of(context).textTheme.bodyMedium?.color),
        onTap: () async {
          await UpiService.openAppSettings();
        },
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'If SMS permission is not working, open PayTrace in phone Settings, '
          'tap ⋮ (3 dots) at top right, and enable "Allow restricted settings".',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
        ),
      ),
    ];
  }

  Widget _buildExportTile(BuildContext context, WidgetRef ref) {
    return _SettingsTile(
      icon: Icons.file_download_outlined,
      title: 'Export Transactions',
      subtitle: 'Download as CSV file',
      trailing: Icon(Icons.chevron_right_rounded,
          color: Theme.of(context).textTheme.bodyMedium?.color),
      onTap: () => _showExportSheet(context, ref),
    );
  }

  void _showBudgetSheet(
      BuildContext context, WidgetRef ref, Budget? existing, DateTime now) {
    final controller = TextEditingController(
      text: existing != null ? existing.limitAmount.toStringAsFixed(0) : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set Monthly Budget',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              Formatters.monthYear(now),
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Budget Amount',
                prefixText: '₹ ',
                hintText: 'e.g. 5000',
              ),
            ),
            const SizedBox(height: 8),
            // Quick amount chips
            Wrap(
              spacing: 8,
              children: [2000, 5000, 10000, 20000, 50000].map((amount) {
                return ActionChip(
                  label: Text('₹${Formatters.amountOnly(amount.toDouble()).split('.')[0]}'),
                  onPressed: () => controller.text = amount.toString(),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(controller.text);
                  if (amount != null && amount > 0) {
                    ref.read(databaseProvider).upsertBudget(
                          now.year, now.month, amount);
                    ref.invalidate(monthlyBudgetProvider);
                    ref.invalidate(budgetProgressProvider);
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Budget set to ${Formatters.currency(amount)}',
                        ),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                },
                child: const Text('Save Budget'),
              ),
            ),
            const SizedBox(height: 8),
            if (existing != null)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    ref.read(databaseProvider).upsertBudget(
                          now.year, now.month, 0);
                    ref.invalidate(monthlyBudgetProvider);
                    ref.invalidate(budgetProgressProvider);
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Budget removed')),
                    );
                  },
                  style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                  child: const Text('Remove Budget'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showExportSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export Transactions',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Share your transaction history as a CSV file',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            // Export all
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final db = ref.read(databaseProvider);
                  final transactions = await db.getAllTransactions();
                  if (transactions.isEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No transactions to export'),
                        ),
                      );
                    }
                    return;
                  }
                  try {
                    await ExportService.exportToCsv(transactions);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Export failed: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.download_rounded, size: 20),
                label: const Text('Export All Transactions'),
              ),
            ),
            const SizedBox(height: 12),
            // Export this month
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final db = ref.read(databaseProvider);
                  final now = DateTime.now();
                  final start = DateTime(now.year, now.month, 1);
                  final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
                  final transactions =
                      await db.getTransactionsInRange(start, end);
                  if (transactions.isEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No transactions this month'),
                        ),
                      );
                    }
                    return;
                  }
                  try {
                    await ExportService.exportToCsv(transactions);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Export failed: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.calendar_month_rounded, size: 20),
                label: const Text('Export This Month'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable Widgets ───

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 11,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
        title: Text(title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 15,
                )),
        subtitle: Text(subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                )),
        trailing: trailing,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
