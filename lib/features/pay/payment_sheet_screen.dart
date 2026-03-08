import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/category_engine.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/qr_parser.dart';
import '../../core/utils/validators.dart';
import '../../data/database/app_database.dart';
import '../../services/upi_service.dart';
import '../../state/providers.dart';

class PaymentSheetScreen extends ConsumerStatefulWidget {
  final QrPaymentData qrData;

  const PaymentSheetScreen({
    super.key,
    required this.qrData,
  });

  @override
  ConsumerState<PaymentSheetScreen> createState() => _PaymentSheetScreenState();
}

class _PaymentSheetScreenState extends ConsumerState<PaymentSheetScreen> {
  static const Uuid _uuid = Uuid();

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _merchantController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  late String _selectedCategory;
  bool _isPaying = false;

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(text: widget.qrData.payeeName);
    _amountController = TextEditingController(
      text: widget.qrData.amount != null
          ? widget.qrData.amount!.toStringAsFixed(2)
          : '',
    );
    _noteController = TextEditingController(
      text: widget.qrData.transactionNote ?? '',
    );

    _selectedCategory = CategoryEngine.categorize(
      payeeName: widget.qrData.payeeName,
      upiId: widget.qrData.payeeAddress,
      merchantCode: widget.qrData.merchantCode,
    );
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _onPay() async {
    if (_isPaying) return;
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text.trim());
    final merchantName = _merchantController.text.trim();
    final note = _noteController.text.trim();

    setState(() => _isPaying = true);

    final txnId = _uuid.v4();
    final txnRef = UpiService.generateTxnRef();

    final launched = await UpiService.launchUpiPayIntent(
      payeeUpiId: widget.qrData.payeeAddress,
      payeeName: merchantName,
      amount: amount,
      note: note.isEmpty ? null : note,
      txnRef: txnRef,
      currency: AppConstants.currency,
    );

    if (!launched) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open a UPI app for payment intent'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.error,
          ),
        );
      }
      setState(() => _isPaying = false);
      return;
    }

    try {
      final db = ref.read(databaseProvider);
      await db.insertTransaction(
        TransactionsCompanion(
          id: Value(txnId),
          payeeUpiId: Value(widget.qrData.payeeAddress),
          payeeName: Value(merchantName),
          amount: Value(amount),
          transactionNote: Value(note.isEmpty ? null : note),
          transactionRef: Value(txnRef),
          status: const Value(AppConstants.statusSubmitted),
          paymentMode: const Value(AppConstants.modeQrScan),
          qrType: Value(
            widget.qrData.isDynamic
                ? AppConstants.qrTypeDynamic
                : AppConstants.qrTypeStatic,
          ),
          category: Value(_selectedCategory),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment opened, but local save failed'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.warning,
          ),
        );
      }
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Payment initiated for ${Formatters.currency(amount)}',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.success,
      ),
    );

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UPI ID',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: widget.qrData.payeeAddress,
                  readOnly: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Merchant Name',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _merchantController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Merchant name',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                  validator: Validators.payeeName,
                ),
                const SizedBox(height: 20),
                Text('Amount', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    prefixText: '₹ ',
                    prefixIcon: Icon(Icons.currency_rupee_rounded),
                  ),
                  validator: Validators.amount,
                ),
                const SizedBox(height: 20),
                Text('Category', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  items: AppConstants.defaultCategories
                      .map(
                        (category) => DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedCategory = value);
                  },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Note (Optional)',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteController,
                  maxLength: AppConstants.maxNoteLength,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Add a note',
                    prefixIcon: Icon(Icons.sticky_note_2_outlined),
                  ),
                  validator: Validators.note,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isPaying ? null : _onPay,
                    child: _isPaying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Pay'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
