import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

import '../core/utils/formatters.dart';
import '../data/database/app_database.dart';

const _dailySummaryTaskName = 'daily_spending_summary_task';
const _dailySummaryUniqueName = 'daily_spending_summary_unique';

const _channelId = 'daily_spending_summary_channel';
const _channelName = 'Daily Spending Summary';
const _channelDescription = 'Daily expense summary notifications at 10 PM';
const _dailySummaryPayload = 'daily_spending_summary_payload';

final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();

Future<void> _initializeNotificationsPlugin({
  DidReceiveNotificationResponseCallback? onDidReceive,
}) async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await _notifications.initialize(
    initSettings,
    onDidReceiveNotificationResponse: onDidReceive,
  );

  final androidImpl = _notifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidImpl?.createNotificationChannel(
    const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.defaultImportance,
    ),
  );
}

Future<void> _showDailySummaryNotification({
  required String title,
  required String body,
}) async {
  await _notifications.show(
    2200,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    ),
    payload: _dailySummaryPayload,
  );
}

@pragma('vm:entry-point')
void dailySpendingSummaryDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    if (task != _dailySummaryTaskName) {
      return true;
    }

    try {
      await _initializeNotificationsPlugin();

      final db = AppDatabase();
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final transactions = await db.getTransactionsInRange(startOfDay, endOfDay);
      final expenses = transactions
          .where((t) => t.direction == 'DEBIT' && t.amount > 0)
          .toList();

      String title;
      String body;

      if (expenses.isEmpty) {
        title = 'Today\'s Spending Summary';
        body = 'You didn\'t record any expenses today.';
      } else {
        final totalSpent = expenses.fold<double>(0, (sum, t) => sum + t.amount);
        final categoryTotals = <String, double>{};
        for (final txn in expenses) {
          categoryTotals.update(
            txn.category,
            (value) => value + txn.amount,
            ifAbsent: () => txn.amount,
          );
        }

        final topCategory = categoryTotals.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;

        title = 'Today\'s Spending Summary';
        body =
            'You spent ${Formatters.currency(totalSpent)} today. Most spending was on $topCategory.';
      }

      await _showDailySummaryNotification(title: title, body: body);

      await db.close();
      return true;
    } catch (e) {
      debugPrint('DailySummaryTask failed: $e');
      return false;
    }
  });
}

class DailySpendingSummaryService {
  DailySpendingSummaryService._();

  static bool _initialized = false;

  static Future<bool> initializeNotificationsForApp({
    required VoidCallback onDailySummaryTap,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    await _initializeNotificationsPlugin(
      onDidReceive: (response) {
        if (response.payload == _dailySummaryPayload) {
          onDailySummaryTap();
        }
      },
    );

    final launchDetails = await _notifications.getNotificationAppLaunchDetails();
    final launchedFromDailySummary =
        launchDetails?.didNotificationLaunchApp == true &&
            launchDetails?.notificationResponse?.payload ==
                _dailySummaryPayload;
    return launchedFromDailySummary;
  }

  static Future<void> initializeAndSchedule() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    if (!_initialized) {
      await Workmanager().initialize(
        dailySpendingSummaryDispatcher,
        isInDebugMode: kDebugMode,
      );
      _initialized = true;
    }

    await _initializeNotificationsPlugin();

    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImpl?.requestNotificationsPermission();

    await Workmanager().registerPeriodicTask(
      _dailySummaryUniqueName,
      _dailySummaryTaskName,
      frequency: const Duration(hours: 24),
      initialDelay: _initialDelayUntilTenPm(),
      existingWorkPolicy: ExistingWorkPolicy.update,
      constraints: Constraints(
        networkType: NetworkType.not_required,
      ),
    );
  }

  static Duration _initialDelayUntilTenPm() {
    final now = DateTime.now();
    var nextTenPm = DateTime(now.year, now.month, now.day, 22, 0);
    if (!nextTenPm.isAfter(now)) {
      nextTenPm = nextTenPm.add(const Duration(days: 1));
    }
    return nextTenPm.difference(now);
  }
}
