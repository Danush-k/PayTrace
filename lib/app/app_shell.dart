import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/daily_spending_summary_service.dart';
import '../features/history/history_screen.dart';
import '../features/history/manual_expense_entry_screen.dart';
import '../features/home/home_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/summary/daily_summary_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    DailySpendingSummaryService.initializeNotificationsForApp(
      onDailySummaryTap: _openDailySummary,
    ).then((launchedFromNotification) {
      if (launchedFromNotification && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openDailySummary();
        });
      }
    });
    DailySpendingSummaryService.initializeAndSchedule();
  }

  void _openDailySummary() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DailySummaryScreen()),
    );
  }

  static const _screens = [
    HomeScreen(),
    HistoryScreen(),
    InsightsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey(_currentIndex),
            child: _screens[_currentIndex],
          ),
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ManualExpenseEntryScreen(),
                  ),
                );
              },
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Expense'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
