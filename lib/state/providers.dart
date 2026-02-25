import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';

import '../data/database/app_database.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/category_engine.dart';
import '../core/utils/recurring_detector.dart';
import '../services/upi_service.dart';
import '../services/notification_service.dart';

// ═══════════════════════════════════════════
//  DATABASE PROVIDER (singleton)
// ═══════════════════════════════════════════

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// ═══════════════════════════════════════════
//  THEME PROVIDER
// ═══════════════════════════════════════════

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'theme_mode';

  ThemeModeNotifier() : super(ThemeMode.dark) {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await _storage.read(key: _key);
    if (saved != null) {
      switch (saved) {
        case 'light':
          state = ThemeMode.light;
          break;
        case 'dark':
          state = ThemeMode.dark;
          break;
        case 'system':
          state = ThemeMode.system;
          break;
      }
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final value = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
            ? 'dark'
            : 'system';
    await _storage.write(key: _key, value: value);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

// ═══════════════════════════════════════════
//  TRANSACTION PROVIDERS
// ═══════════════════════════════════════════

/// Watch all transactions (reactive)
final allTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllTransactions();
});

/// Watch recent transactions for home screen
final recentTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchRecentTransactions(limit: 10);
});

/// Monthly spending
final monthlySpendingProvider = FutureProvider.family<double, DateTime>((ref, date) {
  final db = ref.watch(databaseProvider);
  return db.getMonthlySpent(date.year, date.month);
});

/// Category spending for a month
final categorySpendingProvider =
    FutureProvider.family<Map<String, double>, DateTime>((ref, date) {
  final db = ref.watch(databaseProvider);
  return db.getCategorySpending(date.year, date.month);
});

/// Search transactions
final transactionSearchProvider =
    FutureProvider.family<List<Transaction>, String>((ref, query) {
  final db = ref.watch(databaseProvider);
  if (query.isEmpty) return db.getAllTransactions();
  return db.searchTransactions(query);
});

// ═══════════════════════════════════════════
//  PAYEE PROVIDERS
// ═══════════════════════════════════════════

/// Watch all saved payees
final allPayeesProvider = StreamProvider<List<Payee>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllPayees();
});

/// Top payees for favorites strip
final topPayeesProvider = FutureProvider<List<Payee>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.getTopPayees(limit: 5);
});

// ═══════════════════════════════════════════
//  UPI APP PROVIDERS
// ═══════════════════════════════════════════

/// Installed UPI apps on device — autoDispose so it re-fetches each time
final installedUpiAppsProvider = FutureProvider.autoDispose<List<UpiAppInfo>>((ref) {
  return UpiService.getInstalledUpiApps();
});

// ═══════════════════════════════════════════
//  BUDGET PROVIDERS
// ═══════════════════════════════════════════

/// Monthly budget for current month
final monthlyBudgetProvider = FutureProvider.family<Budget?, DateTime>((ref, date) {
  final db = ref.watch(databaseProvider);
  return db.getBudget(date.year, date.month);
});

/// Budget progress (spent / limit) — returns null if no budget set
final budgetProgressProvider = FutureProvider.family<double?, DateTime>((ref, date) async {
  final db = ref.watch(databaseProvider);
  final budget = await db.getBudget(date.year, date.month);
  if (budget == null || budget.limitAmount <= 0) return null;
  final spent = await db.getMonthlySpent(date.year, date.month);
  return (spent / budget.limitAmount).clamp(0.0, 2.0);
});

// ═══════════════════════════════════════════
//  RECURRING PAYMENTS PROVIDER
// ═══════════════════════════════════════════

final recurringPaymentsProvider = FutureProvider<List<RecurringPayment>>((ref) async {
  final db = ref.watch(databaseProvider);
  final allTxns = await db.getAllTransactions();
  return RecurringDetector.detect(allTxns);
});

// ═══════════════════════════════════════════
//  PAYMENT STATE MANAGEMENT
// ═══════════════════════════════════════════

/// Represents the current payment flow state
enum PaymentFlowStatus {
  idle,
  scanning, // Camera active, scanning QR
  scanned, // QR data read, showing details
  enteringAmount, // User entering amount (static QR)
  confirming, // User reviewing before trigger
  processing, // UPI app opened, waiting for response
  success, // Payment completed
  failure, // Payment failed
  cancelled, // User cancelled
  error, // System error
}

class PaymentState {
  final PaymentFlowStatus status;
  final String? payeeUpiId;
  final String? payeeName;
  final double? amount;
  final String? note;
  final String? qrType; // STATIC or DYNAMIC
  final String paymentMode; // QR_SCAN, CONTACT, MANUAL
  final UpiAppInfo? selectedApp;
  final String? transactionId; // Our internal ID
  final String? error;

  const PaymentState({
    this.status = PaymentFlowStatus.idle,
    this.payeeUpiId,
    this.payeeName,
    this.amount,
    this.note,
    this.qrType,
    this.paymentMode = AppConstants.modeQrScan,
    this.selectedApp,
    this.transactionId,
    this.error,
  });

  PaymentState copyWith({
    PaymentFlowStatus? status,
    String? payeeUpiId,
    String? payeeName,
    double? amount,
    String? note,
    String? qrType,
    String? paymentMode,
    UpiAppInfo? selectedApp,
    String? transactionId,
    String? error,
  }) {
    return PaymentState(
      status: status ?? this.status,
      payeeUpiId: payeeUpiId ?? this.payeeUpiId,
      payeeName: payeeName ?? this.payeeName,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      qrType: qrType ?? this.qrType,
      paymentMode: paymentMode ?? this.paymentMode,
      selectedApp: selectedApp ?? this.selectedApp,
      transactionId: transactionId ?? this.transactionId,
      error: error ?? this.error,
    );
  }

  /// Reset to idle state
  static const PaymentState initial = PaymentState();
}

/// Payment flow controller
class PaymentNotifier extends StateNotifier<PaymentState> {
  final AppDatabase _db;
  static const _uuid = Uuid();

  PaymentNotifier(this._db) : super(PaymentState.initial);

  // ─── FLOW: QR Scanned (Static or Dynamic) ───

  /// Called when QR is scanned. Sets payee details.
  /// For dynamic QR: amount is pre-filled → go to confirm
  /// For static QR: amount is null → go to enteringAmount
  void onQrScanned({
    required String payeeUpiId,
    required String payeeName,
    double? amount,
    required bool isDynamic,
  }) {
    state = state.copyWith(
      status: amount != null && amount > 0
          ? PaymentFlowStatus.confirming
          : PaymentFlowStatus.enteringAmount,
      payeeUpiId: payeeUpiId,
      payeeName: payeeName,
      amount: amount,
      qrType: isDynamic ? AppConstants.qrTypeDynamic : AppConstants.qrTypeStatic,
      paymentMode: AppConstants.modeQrScan,
    );
  }

  // ─── FLOW: Manual UPI ID entry ───

  void onManualEntry({
    required String payeeUpiId,
    required String payeeName,
    String paymentMode = AppConstants.modeManual,
  }) {
    state = state.copyWith(
      status: PaymentFlowStatus.enteringAmount,
      payeeUpiId: payeeUpiId,
      payeeName: payeeName,
      paymentMode: paymentMode,
    );
  }

  // ─── FLOW: Set amount (for static QR / manual) ───

  void setAmount(double amount) {
    state = state.copyWith(
      status: PaymentFlowStatus.confirming,
      amount: amount,
    );
  }

  // ─── FLOW: Set transaction note ───

  void setNote(String note) {
    state = state.copyWith(note: note);
  }

  // ─── FLOW: Select UPI app ───

  void selectUpiApp(UpiAppInfo app) {
    state = state.copyWith(selectedApp: app);
  }

  // ─── FLOW: Launch UPI App (plain, no URI) ───

  /// Pre-log the transaction then open the UPI app normally.
  Future<bool> launchPayment() async {
    if (state.payeeUpiId == null ||
        state.selectedApp == null) {
      state = state.copyWith(
        status: PaymentFlowStatus.error,
        error: 'Missing payment details',
      );
      return false;
    }

    final txnId = _uuid.v4();
    final txnRef = UpiService.generateTxnRef();
    final amount = state.amount ?? 0;

    // Auto-categorize the transaction
    final category = CategoryEngine.categorize(
      payeeName: state.payeeName ?? '',
      upiId: state.payeeUpiId!,
    );

    // Step 1: Pre-log as INITIATED
    await _db.insertTransaction(TransactionsCompanion(
      id: Value(txnId),
      payeeUpiId: Value(state.payeeUpiId!),
      payeeName: Value(state.payeeName ?? state.payeeUpiId!),
      amount: Value(amount),
      transactionNote: Value(state.note),
      transactionRef: Value(txnRef),
      status: const Value(AppConstants.statusInitiated),
      paymentMode: Value(state.paymentMode),
      qrType: Value(state.qrType),
      upiApp: Value(state.selectedApp!.packageName),
      upiAppName: Value(state.selectedApp!.appName),
      category: Value(category),
    ));

    state = state.copyWith(
      status: PaymentFlowStatus.processing,
      transactionId: txnId,
    );

    debugPrint('PayTrace: Transaction $txnId inserted as INITIATED (amount=$amount, category=$category), state=processing');

    // Step 2: Open UPI app normally (no payment URI)
    final launched = await UpiService.launchApp(
      state.selectedApp!.packageName,
    );

    if (!launched) {
      await _db.updateTransactionStatus(
        id: txnId,
        status: AppConstants.statusFailure,
      );
      state = state.copyWith(
        status: PaymentFlowStatus.error,
        error: 'Could not open UPI app. Make sure it is installed.',
      );
    }

    return launched;
  }

  // ─── FLOW: User confirms payment result ───

  Future<void> confirmPayment({
    required bool wasSuccessful,
    String? upiRefNumber,
  }) async {
    final txnId = state.transactionId;
    debugPrint('PayTrace: confirmPayment called — txnId=$txnId, wasSuccessful=$wasSuccessful');
    if (txnId == null) {
      debugPrint('PayTrace: confirmPayment ABORTED — txnId is null!');
      return;
    }

    final status = wasSuccessful
        ? AppConstants.statusSuccess
        : AppConstants.statusFailure;

    debugPrint('PayTrace: Updating DB status to $status for txn $txnId');
    final updated = await _db.updateTransactionStatus(
      id: txnId,
      status: status,
      approvalRefNo: upiRefNumber,
    );
    debugPrint('PayTrace: DB update result: $updated');

    if (wasSuccessful) {
      await _autoSavePayee();
    }

    state = state.copyWith(
      status: wasSuccessful
          ? PaymentFlowStatus.success
          : PaymentFlowStatus.failure,
    );
    debugPrint('PayTrace: State updated to ${state.status}');
  }

  /// Auto-save payee for quick re-pay
  Future<void> _autoSavePayee() async {
    if (state.payeeUpiId == null) return;

    final existing = await _db.getPayeeByUpiId(state.payeeUpiId!);
    if (existing != null) {
      await _db.incrementPayeeCount(existing.id);
    } else {
      await _db.upsertPayee(PayeesCompanion(
        id: Value(_uuid.v4()),
        upiId: Value(state.payeeUpiId!),
        name: Value(state.payeeName ?? state.payeeUpiId!),
        lastPaidAt: Value(DateTime.now()),
        transactionCount: const Value(1),
      ));
    }
  }

  /// Reset state for a new payment
  void reset() {
    state = PaymentState.initial;
  }

  // ─── FLOW: Auto-confirm from notification ───

  Future<void> autoConfirmFromNotification({
    String? upiRefNumber,
    double? detectedAmount,
  }) async {
    final txnId = state.transactionId;
    debugPrint('PayTrace: autoConfirmFromNotification — txnId=$txnId, currentStatus=${state.status}');
    if (txnId == null) {
      debugPrint('PayTrace: autoConfirm ABORTED — txnId is null!');
      return;
    }
    if (state.status != PaymentFlowStatus.processing) {
      debugPrint('PayTrace: autoConfirm ABORTED — status is ${state.status}, not processing');
      return;
    }

    if (detectedAmount != null && detectedAmount > 0 && (state.amount == null || state.amount == 0)) {
      debugPrint('PayTrace: Updating transaction amount from SMS: $detectedAmount');
      await _db.updateTransactionAmount(txnId, detectedAmount);
      state = state.copyWith(amount: detectedAmount);
    }

    debugPrint('PayTrace: Auto-confirming txn $txnId as SUCCESS');
    final updated = await _db.updateTransactionStatus(
      id: txnId,
      status: AppConstants.statusSuccess,
      approvalRefNo: upiRefNumber,
    );
    debugPrint('PayTrace: Auto-confirm DB update result: $updated');

    await _autoSavePayee();

    state = state.copyWith(
      status: PaymentFlowStatus.success,
    );
    debugPrint('PayTrace: State updated to ${state.status}');
  }
}

/// Payment notifier provider
final paymentProvider =
    StateNotifierProvider<PaymentNotifier, PaymentState>((ref) {
  final db = ref.watch(databaseProvider);
  return PaymentNotifier(db);
});

// ═══════════════════════════════════════════
//  NOTIFICATION ACCESS PROVIDERS
// ═══════════════════════════════════════════

/// Check if notification listener permission is granted
final notificationAccessProvider = FutureProvider<bool>((ref) {
  return UpiService.isNotificationAccessEnabled();
});

/// Stream of payment notifications from NotificationListenerService
final paymentNotificationProvider = StreamProvider<PaymentNotification?>((ref) {
  return NotificationService.paymentNotifications;
});
