import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../data/database/app_database.dart';
import '../../services/upi_service.dart';
import '../../state/providers.dart';

class ManualExpenseEntryScreen extends ConsumerStatefulWidget {
  const ManualExpenseEntryScreen({super.key});

  @override
  ConsumerState<ManualExpenseEntryScreen> createState() =>
      _ManualExpenseEntryScreenState();
}

class _ManualExpenseEntryScreenState
    extends ConsumerState<ManualExpenseEntryScreen> {
  static const _uuid = Uuid();

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  final List<_ExpenseCategory> _categories = const [
    _ExpenseCategory('Food', Icons.restaurant_rounded),
    _ExpenseCategory('Transport', Icons.directions_car_rounded),
    _ExpenseCategory('Shopping', Icons.shopping_bag_rounded),
    _ExpenseCategory('Groceries', Icons.local_grocery_store_rounded),
    _ExpenseCategory('Bills', Icons.receipt_long_rounded),
    _ExpenseCategory('Entertainment', Icons.movie_rounded),
    _ExpenseCategory('Health', Icons.favorite_rounded),
    _ExpenseCategory('Education', Icons.school_rounded),
    _ExpenseCategory('Transfer', Icons.swap_horiz_rounded),
    _ExpenseCategory('Other', Icons.more_horiz_rounded),
  ];

  String _selectedCategory = 'Food';
  String _selectedPaymentMethod = 'Cash';
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _saveTransaction() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text.trim());
    final note = _noteController.text.trim();

    final now = DateTime.now();
    final entryDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      now.hour,
      now.minute,
      now.second,
    );

    setState(() => _isSaving = true);

    final db = ref.read(databaseProvider);
    final txnId = _uuid.v4();

    await db.insertTransaction(
      TransactionsCompanion(
        id: Value(txnId),
        payeeUpiId: Value('manual::${_selectedPaymentMethod.toLowerCase()}'),
        payeeName: Value(
          note.isNotEmpty ? note : '$_selectedCategory Expense',
        ),
        amount: Value(amount),
        transactionNote: Value(note.isEmpty ? null : note),
        transactionRef: Value(UpiService.generateTxnRef()),
        status: const Value(AppConstants.statusSuccess),
        paymentMode: const Value(AppConstants.modeManual),
        upiApp: Value('MANUAL_${_selectedPaymentMethod.toUpperCase()}'),
        upiAppName: Value(_selectedPaymentMethod),
        category: Value(_selectedCategory == 'Other' ? 'Others' : _selectedCategory),
        direction: const Value('DEBIT'),
        createdAt: Value(entryDate),
        updatedAt: Value(entryDate),
      ),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved ${Formatters.currency(amount)} in $_selectedCategory',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.success,
      ),
    );

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual Expense')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _amountController,
                        autofocus: true,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.next,
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primary,
                                ),
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          prefixText: '${AppConstants.currencySymbol} ',
                          prefixStyle:
                              Theme.of(context).textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primary,
                                  ),
                          hintText: '0.00',
                        ),
                        validator: Validators.amount,
                      ),
                      const SizedBox(height: 22),
                      Text('Category', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _categories.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.9,
                        ),
                        itemBuilder: (_, index) {
                          final category = _categories[index];
                          final selected = _selectedCategory == category.name;
                          return InkWell(
                            onTap: () {
                              setState(() => _selectedCategory = category.name);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppTheme.primary.withValues(alpha: 0.16)
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? AppTheme.primary
                                      : Colors.transparent,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    category.icon,
                                    size: 22,
                                    color: selected
                                        ? AppTheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    category.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontSize: 11,
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Text('Date', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 18),
                              const SizedBox(width: 10),
                              Text(
                                Formatters.dateShort(_selectedDate),
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const Spacer(),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Payment Method',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: ['Cash', 'Bank', 'UPI'].map((method) {
                          final selected = _selectedPaymentMethod == method;
                          return ChoiceChip(
                            label: Text(method),
                            selected: selected,
                            onSelected: (_) {
                              setState(() => _selectedPaymentMethod = method);
                            },
                            selectedColor: AppTheme.primary.withValues(alpha: 0.16),
                            checkmarkColor: AppTheme.primary,
                            side: BorderSide(
                              color: selected
                                  ? AppTheme.primary
                                  : Theme.of(context).colorScheme.outline,
                            ),
                          );
                        }).toList(),
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
                          hintText: 'Add a quick note',
                          prefixIcon: Icon(Icons.sticky_note_2_outlined),
                        ),
                        validator: Validators.note,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveTransaction,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Transaction'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseCategory {
  final String name;
  final IconData icon;

  const _ExpenseCategory(this.name, this.icon);
}
