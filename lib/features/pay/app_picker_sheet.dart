import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../services/upi_service.dart';
import '../../state/providers.dart';

/// Bottom sheet to pick which installed UPI app to use for payment
class AppPickerSheet extends ConsumerWidget {
  final void Function(UpiAppInfo app) onAppSelected;

  const AppPickerSheet({super.key, required this.onAppSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(installedUpiAppsProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Open & Pay',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your preferred UPI app',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          appsAsync.when(
            data: (apps) => _buildAppGrid(context, ref, apps),
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
            error: (error, __) => _buildError(context, ref, error),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object error) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded,
              size: 48, color: Colors.red.shade400),
          const SizedBox(height: 12),
          Text(
            'Could not load UPI apps',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(
            error.toString(),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(installedUpiAppsProvider),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppGrid(BuildContext context, WidgetRef ref, List<UpiAppInfo> apps) {
    if (apps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.app_blocking_rounded,
                size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 12),
            Text(
              'No UPI apps found',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Install a UPI app like Google Pay or PhonePe',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(installedUpiAppsProvider),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        return _AppTile(
          app: app,
          onTap: () {
            Navigator.of(context).pop();
            onAppSelected(app);
          },
        );
      },
    );
  }
}

class _AppTile extends StatelessWidget {
  final UpiAppInfo app;
  final VoidCallback onTap;

  const _AppTile({required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            child: Center(
              child: Text(
                app.icon,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            app.appName,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 11,
                ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
