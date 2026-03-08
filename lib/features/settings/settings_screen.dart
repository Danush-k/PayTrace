import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../services/export_service.dart';
import '../../state/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final themeMode = ref.watch(themeModeProvider);
    final budgetAsync = ref.watch(monthlyBudgetProvider(DateTime(now.year, now.month)));

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
      children: [
        Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        Text(
          'Customize your workspace',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.phone_android_rounded, size: 16),
                    label: Text('System'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_rounded, size: 16),
                    label: Text('Dark'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_rounded, size: 16),
                    label: Text('Light'),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (selection) {
                  ref.read(themeModeProvider.notifier).setThemeMode(selection.first);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          child: budgetAsync.when(
            data: (budget) {
              final title = budget == null
                  ? 'No monthly budget set'
                  : 'Budget ${Formatters.currency(budget.limitAmount)}';
              return _Tile(
                icon: Icons.account_balance_wallet_outlined,
                title: title,
                subtitle: Formatters.monthYear(now),
                trailing: const Icon(Icons.chevron_right_rounded),
              );
            },
            loading: () => const _Tile(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Loading budget...',
              subtitle: '',
              trailing: SizedBox.shrink(),
            ),
            error: (_, __) => const _Tile(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Budget unavailable',
              subtitle: '',
              trailing: SizedBox.shrink(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            children: [
              _Tile(
                icon: Icons.file_download_outlined,
                title: 'Export transactions',
                subtitle: 'Generate CSV',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final db = ref.read(databaseProvider);
                  final transactions = await db.getAllTransactions();
                  await ExportService.exportToCsv(transactions);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transactions exported successfully'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppTheme.success,
                    ),
                  );
                },
              ),
              Divider(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
                height: 1,
              ),
              const _Tile(
                icon: Icons.info_outline_rounded,
                title: 'PayTrace',
                subtitle: 'Version ${AppConstants.appVersion}',
                trailing: SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: AppTheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
