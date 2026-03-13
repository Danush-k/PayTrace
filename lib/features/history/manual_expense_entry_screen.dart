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
      appBar: AppBar(
        title: const Text('Add Expense'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount Section
                      Center(
                        child: Text(
                          'ENTER AMOUNT',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.grey,
                                letterSpacing: 1.2,
                              ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                            begin: 1.0, 
                            end: _amountController.text.isNotEmpty ? 1.05 : 1.0
                        ),
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        builder: (context, scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: child,
                          );
                        },
                        child: TextFormField(
                          controller: _amountController,
                          autofocus: true,
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                          decoration: InputDecoration(
                            prefixText: '₹ ',
                            prefixStyle: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                              letterSpacing: -1,
                            ),
                            hintText: '0',
                            hintStyle: TextStyle(
                              fontSize: 48,
                              color: Colors.grey.withValues(alpha: 0.3),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (val) {
                            setState(() {}); // Trigger the scale animation
                          },
                          validator: Validators.amount,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Category Section
                      Text(
                        'CATEGORY',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.grey,
                              letterSpacing: 1.2,
                            ),
                      ),
                      const SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _categories.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemBuilder: (_, index) {
                          final category = _categories[index];
                          final selected = _selectedCategory == category.name;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppTheme.primary.withValues(alpha: 0.1)
                                  : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected ? AppTheme.primary : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: InkWell(
                              onTap: () {
                                setState(() => _selectedCategory = category.name);
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    category.icon,
                                    size: 26,
                                    color: selected
                                        ? AppTheme.primary
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    category.name,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          fontSize: 10,
                                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                          color: selected ? AppTheme.primary : null,
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
                      const SizedBox(height: 32),

                      // Date Section
                      Text(
                        'DATE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.grey,
                              letterSpacing: 1.2,
                            ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.calendar_month_rounded, size: 20, color: AppTheme.primary),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                Formatters.dateShort(_selectedDate),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const Spacer(),
                              const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Payment Method Section
                      Text(
                        'PAYMENT METHOD',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.grey,
                              letterSpacing: 1.2,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: ['Cash', 'Bank', 'UPI'].map((method) {
                          final selected = _selectedPaymentMethod == method;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: selected
                                      ? const LinearGradient(
                                          colors: [Color(0xFF7B61FF), Color(0xFF4DA1FF)],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        )
                                      : null,
                                  border: selected
                                      ? null
                                      : Border.all(
                                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                        ),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setState(() => _selectedPaymentMethod = method);
                                  },
                                  borderRadius: BorderRadius.circular(24),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: Text(
                                        method,
                                        style: TextStyle(
                                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                          color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 32),

                      // Note Section
                      Text(
                        'NOTE (OPTIONAL)',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.grey,
                              letterSpacing: 1.2,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextFormField(
                          controller: _noteController,
                          maxLength: AppConstants.maxNoteLength,
                          textCapitalization: TextCapitalization.sentences,
                          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                          decoration: InputDecoration(
                            hintText: 'Add a note',
                            hintStyle: TextStyle(
                              color: Colors.grey.withValues(alpha: 0.8),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            prefixIcon: const Icon(Icons.edit_note_rounded, color: Colors.grey),
                          ),
                          validator: Validators.note,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Save Button Section
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    )
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _amountController.text.isNotEmpty ? 1.0 : 0.5,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7B61FF), Color(0xFF4DA1FF)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: (_amountController.text.isNotEmpty && !_isSaving) ? _saveTransaction : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Save Expense',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
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
