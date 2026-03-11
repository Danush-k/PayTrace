import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/qr_parser.dart';
import '../../core/utils/merchant_detector.dart';
import '../../state/providers.dart';
import '../../services/upi_service.dart';
import '../../services/notification_service.dart';
import '../../services/sms_service.dart';
import 'app_picker_sheet.dart';
import 'contact_picker_sheet.dart';
import 'payment_status_screen.dart';
import 'payment_sheet_screen.dart';
import 'qr_scan_screen.dart';

/// Main payment screen — handles all three flows:
///
/// **Static QR Flow:**
///   QR scanned → shows payee → user enters amount → copy details → open UPI app → confirm
///
/// **Dynamic QR Flow:**
///   QR scanned → shows payee + amount (read-only) → copy details → open UPI app → confirm
///
/// **Manual Entry Flow:**
///   User enters UPI ID + name → enters amount → copy details → open UPI app → confirm
///
/// Because SBI (and some banks) block all `upi://pay` URI-based payments,
/// this screen provides COPY buttons so the user can paste the UPI ID
/// and amount inside GPay/PhonePe manually.
class PayScreen extends ConsumerStatefulWidget {
  /// Pre-filled QR data (from QR scan), or null for manual entry
  final QrPaymentData? qrData;

  /// Payment mode — QR_SCAN, MANUAL, or CONTACT
  final String paymentMode;

  /// Pre-filled UPI ID (from favorites strip)
  final String? prefilledUpiId;

  /// Pre-filled payee name (from favorites strip)
  final String? prefilledName;

  const PayScreen({
    super.key,
    this.qrData,
    this.paymentMode = AppConstants.modeManual,
    this.prefilledUpiId,
    this.prefilledName,
  });

  @override
  ConsumerState<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends ConsumerState<PayScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _upiIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isAmountReadOnly = false;
  bool _detailsConfirmed = false; // After user hits "Proceed"
  PayeeType _payeeType = PayeeType.unknown;
  StreamSubscription<PaymentNotification>? _notificationSub;
  StreamSubscription<BankSms>? _smsSub;
  bool _autoConfirmed = false; // Prevent double-confirm
  DateTime? _paymentLaunchedAt; // When user opened UPI app
  bool _isPolling = false; // Prevent concurrent polls

  // ── Auto-detect waiting mode ──
  bool _waitingForAutoDetect = false;
  Timer? _autoDetectTimer;
  Timer? _countdownUiTimer;
  int _countdownSeconds = 15;
  String _debugStatus = ''; // Visible debug info
  int _smsScannedCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prefillFromQr();
    _prefillFromFavorite();
    _openContactPickerIfNeeded();
  }

  /// When in contact mode, immediately open the contact picker.
  void _openContactPickerIfNeeded() {
    if (widget.paymentMode == AppConstants.modeContact &&
        widget.prefilledUpiId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openContactPicker();
      });
    }
  }

  /// Show the contact picker and fill in the selected contact's details.
  Future<void> _openContactPicker() async {
    final picked = await ContactPickerSheet.show(context);
    if (!mounted) return;

    if (picked == null) {
      // User dismissed without picking — go back to home
      if (_upiIdController.text.isEmpty) {
        Navigator.of(context).pop();
      }
      return;
    }

    setState(() {
      _nameController.text = picked.displayName;
      // Build a phone-based UPI ID (most common: phone@ybl)
      _upiIdController.text = '${picked.phone}@ybl';
      _payeeType = MerchantDetector.classify(
        upiId: _upiIdController.text,
        payeeName: picked.displayName,
      );
    });

    ref.read(paymentProvider.notifier).onManualEntry(
          payeeUpiId: _upiIdController.text,
          payeeName: picked.displayName,
        );
  }

  /// Pre-fill from favorites strip (when user taps a frequent payee)
  void _prefillFromFavorite() {
    if (widget.prefilledUpiId != null) {
      _upiIdController.text = widget.prefilledUpiId!;
      if (widget.prefilledName != null) {
        _nameController.text = widget.prefilledName!;
      }
      _payeeType = MerchantDetector.classify(
        upiId: widget.prefilledUpiId!,
        payeeName: widget.prefilledName ?? '',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(paymentProvider.notifier).onManualEntry(
              payeeUpiId: widget.prefilledUpiId!,
              payeeName: widget.prefilledName ?? widget.prefilledUpiId!,
            );
      });
    }
  }

  void _prefillFromQr() {
    final qr = widget.qrData;
    if (qr != null) {
      _upiIdController.text = qr.payeeAddress;
      _nameController.text = qr.payeeName;

      if (qr.isDynamic && qr.amount != null) {
        _amountController.text = qr.amount!.toStringAsFixed(2);
        _isAmountReadOnly = true;
      }

      if (qr.transactionNote != null) {
        _noteController.text = qr.transactionNote!;
      }

      // Classify payee
      _payeeType = MerchantDetector.classify(
        upiId: qr.payeeAddress,
        payeeName: qr.payeeName,
        merchantCode: qr.merchantCode,
      );

      // Update payment notifier
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(paymentProvider.notifier).onQrScanned(
              payeeUpiId: qr.payeeAddress,
              payeeName: qr.payeeName,
              amount: qr.amount,
              isDynamic: qr.isDynamic,
            );
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSub?.cancel();
    _smsSub?.cancel();
    _autoDetectTimer?.cancel();
    _countdownUiTimer?.cancel();
    _upiIdController.dispose();
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// When app returns to foreground (user comes back from GPay/PhonePe),
  /// re-trigger SMS polling as a bonus (main detection starts in _launchAndConfirm).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _paymentLaunchedAt != null &&
        !_autoConfirmed) {
      debugPrint('PayTrace: App resumed — re-triggering SMS poll (isPolling=$_isPolling)');
      // If a poll is already running, do a quick single scan instead
      // (the running poll might be stuck waiting on its interval timer)
      if (_isPolling) {
        _quickSmsScan().then((sms) {
          if (sms != null && mounted && _tryClaimAutoConfirm()) {
            _notificationSub?.cancel();
            _onAutoConfirmed(
              upiRefNumber: sms.refNumber,
              detectedAmount: sms.amount,
            );
          }
        });
      } else {
        _pollSmsInbox();
      }
    }
  }

  /// Whether the current payment is amount-free (user skipped entering amount).
  bool get _isAmountFreePayment {
    final pendingAmount = double.tryParse(_amountController.text.trim()) ?? 0;
    return pendingAmount <= 0;
  }

  /// Auto-detect timeout: longer for amount-free payments since bank SMS
  /// can take 15-45 seconds to arrive after UPI transaction completes.
  int get _autoDetectTimeoutSeconds => _isAmountFreePayment ? 30 : 15;

  /// Whether this is a static QR payment (QR present but no amount embedded).
  bool get _isStaticQr =>
      widget.qrData != null && !(widget.qrData!.isDynamic);

  /// Poll the SMS inbox for a matching bank debit SMS.
  /// This is the MOST RELIABLE method — reads from the actual SMS database
  /// rather than depending on BroadcastReceiver delivery.
  Future<void> _pollSmsInbox() async {
    if (_autoConfirmed || _isPolling) return;
    _isPolling = true;

    if (_paymentLaunchedAt == null) {
      _isPolling = false;
      return;
    }

    final pendingAmount = double.tryParse(_amountController.text.trim()) ?? 0;
    final isAmountFree = pendingAmount <= 0;
    final pollTimeout = _autoDetectTimeoutSeconds + 5; // Extend beyond UI timer

    debugPrint('PayTrace: Polling SMS inbox — amount=$pendingAmount (amountFree=$isAmountFree) since $_paymentLaunchedAt, timeout=${pollTimeout}s');

    // Poll every 2 seconds. Timeout extends beyond auto-detect UI timer
    // so we keep scanning even as the UI countdown finishes.
    // When pendingAmount <= 0, pollForPaymentSms uses amount-free mode
    // which matches ANY debit SMS with a valid amount.
    final matchedSms = await SmsService.pollForPaymentSms(
      pendingAmount: pendingAmount,
      paymentStartTime: _paymentLaunchedAt!,
      interval: const Duration(seconds: 2),
      timeout: Duration(seconds: pollTimeout),
      onPollUpdate: (smsCount) {
        if (mounted) {
          setState(() {
            _smsScannedCount = smsCount;
            _debugStatus = isAmountFree
                ? 'Scanning for payment SMS ($smsCount checked)...'
                : 'Scanned $smsCount SMS...';
          });
        }
      },
    );

    _isPolling = false;

    if (matchedSms != null && mounted && _tryClaimAutoConfirm()) {
      debugPrint('PayTrace: SMS inbox poll found match! ref=${matchedSms.refNumber}, amount=${matchedSms.amount}');
      _notificationSub?.cancel();
      _onAutoConfirmed(
        upiRefNumber: matchedSms.refNumber,
        detectedAmount: matchedSms.amount,
      );
    }
  }

  /// Do a single quick scan of the SMS inbox (no polling loop).
  /// Returns a matching BankSms if found, null otherwise.
  /// Used as a "second chance" scan before showing the manual entry dialog.
  Future<BankSms?> _quickSmsScan() async {
    if (_paymentLaunchedAt == null) return null;

    final pendingAmount = double.tryParse(_amountController.text.trim()) ?? 0;
    final isAmountFree = pendingAmount <= 0;

    debugPrint('PayTrace: Quick SMS scan — amount=$pendingAmount (amountFree=$isAmountFree)');

    final smsList = await SmsService.readRecentSms(since: _paymentLaunchedAt!);
    debugPrint('PayTrace: Quick scan found ${smsList.length} SMS to check');

    for (final sms in smsList) {
      if (isAmountFree) {
        if (SmsService.isDebitSms(sms) && sms.amount != null && sms.amount! > 0) {
          debugPrint('PayTrace: Quick scan matched (amount-free)! sender=${sms.sender}, amount=${sms.amount}, ref=${sms.refNumber}');
          return sms;
        }
      } else {
        if (SmsService.matchesPending(sms: sms, pendingAmount: pendingAmount)) {
          debugPrint('PayTrace: Quick scan matched! sender=${sms.sender}, amount=${sms.amount}, ref=${sms.refNumber}');
          return sms;
        }
      }
    }

    return null;
  }

  /// Step 1: User fills in details and hits "Proceed".
  ///
  /// Static QR: amount is always skipped (detected from SMS later).
  /// Dynamic QR: amount is pre-filled from QR (read-only).
  /// Manual entry: amount is required (validated).
  void _onProceed() async {
    // Static QR skips amount entirely — only validate note
    // Dynamic QR and manual entry validate the full form including amount
    if (_isStaticQr) {
      // For static QR, we don't validate amount (it's not shown)
      // Just validate the note field (which allows empty)
    } else if (!_formKey.currentState!.validate()) {
      return;
    }

    final notifier = ref.read(paymentProvider.notifier);

    if (widget.qrData == null) {
      // Manual / Contact entry
      notifier.onManualEntry(
        payeeUpiId: _upiIdController.text.trim(),
        payeeName: _nameController.text.trim(),
        paymentMode: widget.paymentMode,
      );

      // Classify manually entered payee
      _payeeType = MerchantDetector.classify(
        upiId: _upiIdController.text.trim(),
        payeeName: _nameController.text.trim(),
      );
    }

    // Set amount: 0 for static QR (SMS will fill it), otherwise parsed value
    final amountText = _amountController.text.trim();
    final amount = amountText.isEmpty ? 0.0 : double.tryParse(amountText) ?? 0.0;
    if (amount > 0) {
      notifier.setAmount(amount);
    }
    // If amount == 0 (static QR), don't call setAmount — leave it null

    if (_noteController.text.isNotEmpty) {
      notifier.setNote(_noteController.text.trim());
    }

    setState(() => _detailsConfirmed = true);

    // Auto-copy UPI ID to clipboard when entering Copy & Pay view
    _copyToClipboard(_upiIdController.text.trim(), 'UPI ID');

    // Record time so we can poll SMS inbox from this point
    _paymentLaunchedAt ??= DateTime.now().subtract(const Duration(seconds: 5));

    // Ensure SMS permission is granted for auto-detection
    final hasPerm = await SmsService.hasSmsPermission();
    if (!hasPerm) {
      final granted = await SmsService.requestSmsPermission();
      if (granted) {
        ref.invalidate(smsSyncProvider);
      }
    }

    // Start listening for notifications as soon as Copy & Pay view shows
    // (user might open GPay manually from their phone)
    _startNotificationListener();
  }

  /// Copy text to clipboard with feedback
  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('$label copied!'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  /// Step 2: Pick UPI app and launch it
  void _showAppPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AppPickerSheet(
        onAppSelected: (app) {
          // NOTE: AppPickerSheet already pops the bottom sheet in _AppTile.onTap
          // Do NOT pop again here — that would pop the PayScreen itself!
          ref.read(paymentProvider.notifier).selectUpiApp(app);
          _launchAndConfirm(app);
        },
      ),
    );
  }

  /// Step 3: Launch UPI app and immediately start auto-detection
  Future<void> _launchAndConfirm(UpiAppInfo app) async {
    final notifier = ref.read(paymentProvider.notifier);

    // Record when we launched — used to filter SMS inbox
    _paymentLaunchedAt = DateTime.now().subtract(const Duration(seconds: 5));

    // Start listening for payment notifications BEFORE launching
    _startNotificationListener();

    final launched = await notifier.launchPayment();

    if (!mounted) return;

    if (!launched) {
      _notificationSub?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open UPI app'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // === START AUTO-DETECT IMMEDIATELY ===
    // Don't rely on lifecycle callback — start right now
    _startAutoDetectWait();
  }

  /// Start listening to payment notifications for auto-detection.
  /// SMS detection is handled by _pollSmsInbox() using ContentResolver polling.
  void _startNotificationListener() {
    _notificationSub?.cancel();
    _autoConfirmed = false;

    final pendingAmount = double.tryParse(_amountController.text.trim()) ?? 0;
    final pendingPayee = _nameController.text.trim();
    final amountFree = pendingAmount <= 0;

    debugPrint('PayTrace: Listening for auto-detection — amount=$pendingAmount (amountFree=$amountFree), payee=$pendingPayee');

    // ── Listener: UPI app notifications (GPay, PhonePe, etc.) ──
    _notificationSub = NotificationService.paymentNotifications.listen(
      (notification) {
        debugPrint('PayTrace: Got notification → ${notification.amount}, ${notification.payeeName}');

        if (_autoConfirmed) return;

        bool matches;
        if (amountFree) {
          // Amount-free mode: match by payee name + success keywords,
          // or any notification with a valid payment amount
          final fullText = '${notification.title} ${notification.text}'.toLowerCase();
          final hasSuccessKeyword = ['success', 'paid', 'sent', 'debited', 'completed', 'transferred']
              .any((kw) => fullText.contains(kw));

          // Match if: (success keyword + payee name match) OR (has a valid payment amount)
          final nameMatch = pendingPayee.isNotEmpty &&
              fullText.contains(pendingPayee.toLowerCase());
          final hasAmount = notification.amount != null && notification.amount! > 0;

          matches = (hasSuccessKeyword && nameMatch) || (hasSuccessKeyword && hasAmount);

          if (matches) {
            debugPrint('PayTrace: Amount-free notification match! '
                'nameMatch=$nameMatch, hasAmount=$hasAmount, amount=${notification.amount}');
          }
        } else {
          matches = NotificationService.matchesPending(
            notification: notification,
            pendingAmount: pendingAmount,
            pendingPayeeName: pendingPayee,
          );
        }

        if (matches && _tryClaimAutoConfirm()) {
          debugPrint('PayTrace: Notification matches! Auto-confirming...');
          _notificationSub?.cancel();
          _onAutoConfirmed(
            detectedAmount: notification.amount,
          );
        }
      },
      onError: (e) {
        debugPrint('PayTrace: Notification stream error: $e');
      },
    );
  }

  /// Start the auto-detect waiting screen with a dynamic countdown.
  /// Amount-free payments get 30s (bank SMS takes longer), others get 15s.
  /// If no SMS/notification match is found within the timeout, does a final
  /// SMS scan before falling back to the manual dialog.
  void _startAutoDetectWait() {
    if (_waitingForAutoDetect || _autoConfirmed) return;

    final timeout = _autoDetectTimeoutSeconds;
    debugPrint('PayTrace: Starting auto-detect wait (${timeout}s, amountFree=$_isAmountFreePayment)');

    // Show waiting screen IMMEDIATELY — no async, no delays
    setState(() {
      _waitingForAutoDetect = true;
      _countdownSeconds = timeout;
      _smsScannedCount = 0;
      _debugStatus = _isAmountFreePayment
          ? 'Waiting for bank SMS confirmation...'
          : 'Starting SMS scan...';
    });

    // Check SMS permission in background and update debug status
    _checkSmsPermissionAndUpdateStatus();

    // Timeout → do one final quick scan, THEN fall back to manual confirmation
    _autoDetectTimer?.cancel();
    _autoDetectTimer = Timer(Duration(seconds: timeout), () async {
      if (_autoConfirmed || !mounted) return;

      debugPrint('PayTrace: Auto-detect timer expired — doing final SMS scan before manual dialog');
      setState(() => _debugStatus = 'Final scan...');

      // One last chance: do a quick SMS scan right now
      // (the bank SMS might have arrived in the last few seconds)
      final lastChanceSms = await _quickSmsScan();

      if (lastChanceSms != null && mounted && _tryClaimAutoConfirm()) {
        debugPrint('PayTrace: Last-chance SMS scan found match! ref=${lastChanceSms.refNumber}, amount=${lastChanceSms.amount}');
        _countdownUiTimer?.cancel();
        _notificationSub?.cancel();
        setState(() => _waitingForAutoDetect = false);
        _onAutoConfirmed(
          upiRefNumber: lastChanceSms.refNumber,
          detectedAmount: lastChanceSms.amount,
        );
        return;
      }

      if (!_autoConfirmed && mounted) {
        debugPrint('PayTrace: Auto-detect timed out — showing manual dialog');
        _countdownUiTimer?.cancel();
        setState(() => _waitingForAutoDetect = false);
        _showPaymentConfirmation();
      }
    });

    // Update countdown UI every second
    _countdownUiTimer?.cancel();
    _countdownUiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _countdownSeconds = (_countdownSeconds - 1).clamp(0, timeout);
      });
    });

    // Start polling SMS inbox immediately
    _pollSmsInbox();
  }

  /// Check SMS permission and update the debug status on the waiting screen.
  void _checkSmsPermissionAndUpdateStatus() async {
    final hasPerm = await SmsService.hasSmsPermission();
    debugPrint('PayTrace: SMS permission check: $hasPerm');

    if (!mounted) return;

    if (!hasPerm) {
      setState(() => _debugStatus = 'SMS permission: ❌ DENIED');
      // Request permission
      final granted = await SmsService.requestSmsPermission();
      if (mounted) {
        setState(() {
          _debugStatus = granted
              ? 'SMS permission: ✅ Scanning...'
              : 'SMS permission: ❌ DENIED — go to Settings';
        });
        // If permission was just granted, restart polling
        if (granted) {
          ref.invalidate(smsSyncProvider);
          if (!_isPolling) _pollSmsInbox();
        }
      }
    } else {
      setState(() => _debugStatus = 'SMS permission: ✅ Scanning...');
    }
  }

  /// Atomically claim the auto-confirm flag. Returns true only for
  /// the FIRST caller — all subsequent callers get false, preventing
  /// duplicate transaction creation from concurrent SMS + notification.
  bool _tryClaimAutoConfirm() {
    if (_autoConfirmed) return false;
    _autoConfirmed = true;
    return true;
  }

  /// Called when a matching notification or SMS auto-confirms the payment
  void _onAutoConfirmed({String? upiRefNumber, double? detectedAmount}) async {
    if (!mounted) return;

    // Stop timers
    _autoDetectTimer?.cancel();
    _countdownUiTimer?.cancel();

    // Dismiss manual confirmation dialog if it's showing
    Navigator.of(context, rootNavigator: true).popUntil((route) {
      return route is! DialogRoute;
    });

    // Clear waiting state
    setState(() => _waitingForAutoDetect = false);

    await ref.read(paymentProvider.notifier).autoConfirmFromNotification(
          upiRefNumber: upiRefNumber,
          detectedAmount: detectedAmount,
        );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(upiRefNumber != null
                ? 'Payment auto-detected! Ref: $upiRefNumber'
                : 'Payment auto-detected!'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );

    _navigateToStatus();
  }

  void _showPaymentConfirmation() async {
    final paymentState = ref.read(paymentProvider);
    final isAmountMissing = paymentState.amount == null || paymentState.amount == 0;

    // ── SECOND-CHANCE SCAN ──
    // Before showing manual entry, do one more quick SMS scan.
    // The bank SMS might have arrived just after the auto-detect timer expired.
    if (isAmountMissing && _paymentLaunchedAt != null) {
      debugPrint('PayTrace: Manual dialog — attempting second-chance SMS scan before showing dialog');
      final lastChanceSms = await _quickSmsScan();
      if (lastChanceSms != null && mounted && _tryClaimAutoConfirm()) {
        debugPrint('PayTrace: Second-chance SMS scan found match! '
            'ref=${lastChanceSms.refNumber}, amount=${lastChanceSms.amount}');
        _notificationSub?.cancel();
        _onAutoConfirmed(
          upiRefNumber: lastChanceSms.refNumber,
          detectedAmount: lastChanceSms.amount,
        );
        return; // Don't show manual dialog
      }
    }

    if (!mounted) return;

    final refController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment Status'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isAmountMissing
                    ? 'Could not auto-detect payment.\nDid you complete the payment?'
                    : 'Did you complete the payment of '
                        '₹${paymentState.amount!.toStringAsFixed(2)}?',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (isAmountMissing) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bank SMS was not detected. Please enter the amount manually.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.orange.shade700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount paid',
                    hintText: 'e.g., 500.00',
                    prefixText: '₹ ',
                    prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 20),
                    helperText: 'Check your UPI app or bank SMS for the amount',
                    helperStyle: Theme.of(context).textTheme.bodySmall,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: refController,
                decoration: InputDecoration(
                  labelText: 'UPI Reference Number (optional)',
                  hintText: 'e.g., 503912345678',
                  prefixIcon: const Icon(Icons.receipt_long_rounded, size: 20),
                  helperText: 'Check your UPI app for the ref number',
                  helperStyle: Theme.of(context).textTheme.bodySmall,
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await ref.read(paymentProvider.notifier).confirmPayment(
                    wasSuccessful: false,
                  );
              if (!mounted) return;
              _navigateToStatus();
            },
            child: const Text('No, it failed'),
          ),
          // Retry SMS scan button — for amount-free payments
          if (isAmountMissing)
            TextButton.icon(
              onPressed: () async {
                // Try scanning SMS one more time
                final sms = await _quickSmsScan();
                if (!mounted) return;
                if (sms != null && _tryClaimAutoConfirm()) {
                  _notificationSub?.cancel();
                  _smsSub?.cancel();
                  Navigator.of(context).pop();
                  _onAutoConfirmed(
                    upiRefNumber: sms.refNumber,
                    detectedAmount: sms.amount,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No payment SMS found yet. Please enter manually.'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry SMS'),
            ),
          ElevatedButton.icon(
            onPressed: () async {
              // If amount was missing, parse the manually entered amount
              double? manualAmount;
              if (isAmountMissing) {
                final amountText = amountController.text.trim();
                manualAmount = double.tryParse(amountText);
                if (manualAmount != null && manualAmount > 0) {
                  // Update the amount in state and DB
                  await ref.read(paymentProvider.notifier).autoConfirmFromNotification(
                    detectedAmount: manualAmount,
                    upiRefNumber: refController.text.trim().isNotEmpty
                        ? refController.text.trim()
                        : null,
                  );
                  amountController.dispose();
                  refController.dispose();
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  _navigateToStatus();
                  return;
                }
              }

              Navigator.of(context).pop();
              await ref.read(paymentProvider.notifier).confirmPayment(
                    wasSuccessful: true,
                    upiRefNumber: refController.text.trim().isNotEmpty
                        ? refController.text.trim()
                        : null,
                  );
              amountController.dispose();
              refController.dispose();
              if (!mounted) return;
              _navigateToStatus();
            },
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Yes, paid!'),
          ),
        ],
      ),
    );
  }

  void _navigateToStatus() {
    final paymentState = ref.read(paymentProvider);
    debugPrint('PayTrace: _navigateToStatus — status=${paymentState.status}, txnId=${paymentState.transactionId}');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaymentStatusScreen(
          status: paymentState.status,
          payeeName: paymentState.payeeName ?? '',
          amount: paymentState.amount ?? 0,
          transactionId: paymentState.transactionId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDynamic = widget.qrData?.isDynamic ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _detailsConfirmed
              ? 'Copy & Pay'
              : widget.qrData != null
                  ? (isDynamic ? 'Confirm Payment' : 'Review Payment')
                  : widget.paymentMode == AppConstants.modeContact
                      ? 'Pay to Contact'
                      : 'Pay via UPI',
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            ref.read(paymentProvider.notifier).reset();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: _waitingForAutoDetect
          ? _buildWaitingView()
          : _detailsConfirmed
              ? _buildCopyAndPayView()
              : _buildFormView(isDynamic),
    );
  }

  // ═══════════════════════════════════════════
  //  FORM VIEW — Enter/confirm details
  // ═══════════════════════════════════════════

  Widget _buildFormView(bool isDynamic) {
    // Static QR: no amount field (detected from SMS)
    // Dynamic QR: amount field shown (read-only)
    // Manual entry: all fields shown
    final showAmountField = isDynamic || widget.qrData == null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payee Card (QR mode)
            if (widget.qrData != null) _buildPayeeCard(isDynamic),
            if (widget.qrData != null) const SizedBox(height: 28),

            // Amount Field — only for dynamic QR and manual entry
            if (showAmountField) ...[
              Text('Amount', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                readOnly: _isAmountReadOnly,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}')),
                ],
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle:
                      Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                  hintText: '0.00',
                  suffixIcon: _isAmountReadOnly
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.lock_rounded,
                              size: 20, color: Colors.grey),
                        )
                      : null,
                ),
                validator: Validators.amount,
                autofocus: !_isAmountReadOnly && widget.qrData != null,
              ),
              if (_isAmountReadOnly) ...[
                const SizedBox(height: 4),
                Text(
                  'Amount is set by the QR code',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                ),
              ],
              const SizedBox(height: 24),
            ],

            // SMS auto-detect info chip — for static QR only
            if (_isStaticQr) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sms_rounded,
                        size: 20, color: AppTheme.primary.withValues(alpha: 0.8)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Amount detected automatically',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Enter amount in your UPI app — we\'ll read it from your bank\'s SMS',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Note Field
            Text('Payment Note',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'For your reference only',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                  ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteController,
              maxLength: AppConstants.maxNoteLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g., Rent for February',
                prefixIcon: Icon(Icons.sticky_note_2_outlined, size: 20),
              ),
              validator: Validators.note,
            ),

            // UPI ID & Name (manual / contact entry)
            if (widget.qrData == null) ...[
              // Pick from Contacts button (contact mode)
              if (widget.paymentMode == AppConstants.modeContact) ...[
                InkWell(
                  onTap: _openContactPicker,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.contacts_rounded,
                            color: AppTheme.primary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _nameController.text.isNotEmpty
                                ? 'Paying ${_nameController.text}'
                                : 'Pick from Contacts',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        Icon(Icons.swap_horiz_rounded,
                            color: AppTheme.primary.withValues(alpha: 0.6),
                            size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              const SizedBox(height: 24),
              Text('Payee UPI ID',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _upiIdController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'name@ybl',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined,
                      size: 20),
                ),
                validator: Validators.upiId,
              ),
              const SizedBox(height: 16),
              Text('Payee Name',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Enter name',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                ),
                validator: Validators.payeeName,
              ),
            ],

            const SizedBox(height: 40),

            // Proceed Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _onProceed,
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                label: Text(
                  _isAmountReadOnly && _amountController.text.isNotEmpty
                      ? 'Pay ₹${_amountController.text}'
                      : _isStaticQr
                          ? 'Copy & Pay'
                          : 'Proceed to Pay',
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Scan QR option (manual mode only)
            if (widget.qrData == null)
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    final qrData =
                        await Navigator.of(context).push<QrPaymentData>(
                      MaterialPageRoute(
                          builder: (_) => const QrScanScreen()),
                    );
                    if (qrData != null && mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => PaymentSheetScreen(qrData: qrData),
                        ),
                      );
                    }
                  },
                  icon:
                      const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: const Text('Scan QR instead'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  COPY & PAY VIEW — Copy details + open app
  // ═══════════════════════════════════════════

  Widget _buildCopyAndPayView() {
    final upiId = _upiIdController.text.trim();
    final name = _nameController.text.trim();
    final amount = _amountController.text.trim();
    final hasAmount = amount.isNotEmpty && (double.tryParse(amount) ?? 0) > 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Merchant / Personal badge
          _buildPayeeTypeBadge(),
          const SizedBox(height: 20),

          // Payee display card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.12),
                  AppTheme.primary.withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(name,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center),

                // Amount — only if available (dynamic QR or manual entry)
                if (hasAmount) ...[
                  const SizedBox(height: 16),
                  Text(
                    '₹$amount',
                    style:
                        Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                            ),
                  ),
                ] else ...[
                  // Static QR — amount will be detected from SMS
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sms_rounded, size: 14,
                            color: Colors.green.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'Amount auto-detected from SMS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── Copy Buttons ───
          _buildCopyTile(
            icon: Icons.account_balance_wallet_rounded,
            label: 'UPI ID',
            value: upiId,
            onCopy: () => _copyToClipboard(upiId, 'UPI ID'),
          ),
          if (hasAmount) ...[
            const SizedBox(height: 12),
            _buildCopyTile(
              icon: Icons.currency_rupee_rounded,
              label: 'Amount',
              value: '₹$amount',
              onCopy: () => _copyToClipboard(amount, 'Amount'),
            ),
          ],
          const SizedBox(height: 28),

          // ─── Instructions ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'How to pay',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.amber.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildStep('1', 'UPI ID is already copied!'),
                _buildStep('2', 'Tap "Open UPI App" below'),
                _buildStep('3', 'Paste the UPI ID in the app'),
                if (!hasAmount)
                  _buildStep('4', 'Enter the amount and pay')
                else
                  _buildStep('4', 'Confirm ₹$amount and pay'),
                _buildStep('5', 'Come back — we\'ll detect it automatically'),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ─── Open UPI App Button ───
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _showAppPicker,
              icon: const Icon(Icons.open_in_new_rounded, size: 20),
              label: const Text(
                'Open UPI App',
                style: TextStyle(fontSize: 17),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ─── Edit Details Button ───
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() => _detailsConfirmed = false);
              },
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Edit Details'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  WAITING FOR AUTO-DETECT VIEW
  // ═══════════════════════════════════════════

  Widget _buildWaitingView() {
    final name = _nameController.text.trim();
    final amount = _amountController.text.trim();
    final isAmountFree = amount.isEmpty || (double.tryParse(amount) ?? 0) <= 0;
    final progress = _countdownSeconds / _autoDetectTimeoutSeconds;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated pulsing container
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.95, end: 1.05),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              onEnd: () {
                // Restart animation by rebuilding
                if (mounted && _waitingForAutoDetect) setState(() {});
              },
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.sms_rounded,
                  size: 48,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 28),

            Text(
              'Detecting payment...',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              isAmountFree
                  ? 'Waiting for bank SMS to $name'
                  : '₹$amount to $name',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 28),

            // Circular countdown progress
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 4,
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  ),
                  Text(
                    '${_countdownSeconds}s',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Listening for bank SMS & app notifications',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
            if (_debugStatus.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _smsScannedCount > 0
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _debugStatus,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _smsScannedCount > 0 ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
            const SizedBox(height: 40),

            // "I already paid" shortcut
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () {
                  _autoDetectTimer?.cancel();
                  _countdownUiTimer?.cancel();
                  setState(() => _waitingForAutoDetect = false);
                  _showPaymentConfirmation();
                },
                icon: const Icon(Icons.edit_note_rounded, size: 20),
                label: const Text('I already paid — enter manually'),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel
            TextButton(
              onPressed: () async {
                _autoDetectTimer?.cancel();
                _countdownUiTimer?.cancel();
                _notificationSub?.cancel();
                setState(() => _waitingForAutoDetect = false);
                await ref.read(paymentProvider.notifier).confirmPayment(
                      wasSuccessful: false,
                    );
                if (!mounted) return;
                _navigateToStatus();
              },
              child: Text(
                'Cancel payment',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  HELPER WIDGETS
  // ═══════════════════════════════════════════

  Widget _buildPayeeTypeBadge() {
    final color = _payeeType == PayeeType.merchant
        ? Colors.orange
        : _payeeType == PayeeType.personal
            ? AppTheme.primary
            : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(MerchantDetector.icon(_payeeType),
              style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            MerchantDetector.label(_payeeType),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onCopy,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        )),
                const SizedBox(height: 2),
                Text(value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 20),
            tooltip: 'Copy $label',
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              number,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.amber.shade700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayeeCard(bool isDynamic) {
    final qr = widget.qrData!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.15),
            AppTheme.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // QR type + Payee type badges
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDynamic
                      ? AppTheme.success.withValues(alpha: 0.15)
                      : AppTheme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isDynamic ? '⚡ Dynamic QR' : '📷 Static QR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDynamic ? AppTheme.success : AppTheme.warning,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildPayeeTypeBadge(),
            ],
          ),
          const SizedBox(height: 14),
          // Payee avatar
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
            child: Text(
              qr.payeeName.isNotEmpty
                  ? qr.payeeName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            qr.payeeName,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            qr.payeeAddress,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (isDynamic && qr.amount != null) ...[
            const SizedBox(height: 14),
            Text(
              Formatters.currency(qr.amount!),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
