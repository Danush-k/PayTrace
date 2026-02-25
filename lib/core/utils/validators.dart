/// Simple form validators for UPI and payment fields
class Validators {
  Validators._();

  /// Validate UPI ID format
  static String? upiId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'UPI ID is required';
    }
    final regex = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$');
    if (!regex.hasMatch(value.trim())) {
      return 'Invalid UPI ID format (e.g., name@ybl)';
    }
    return null;
  }

  /// Validate payment amount
  static String? amount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
    }
    final amount = double.tryParse(value.trim());
    if (amount == null) {
      return 'Enter a valid amount';
    }
    if (amount <= 0) {
      return 'Amount must be greater than 0';
    }
    if (amount > 100000) {
      return 'Amount cannot exceed ₹1,00,000';
    }
    return null;
  }

  /// Validate transaction note (optional, max 50 chars)
  static String? note(String? value) {
    if (value != null && value.length > 50) {
      return 'Note cannot exceed 50 characters';
    }
    return null;
  }

  /// Validate payee name
  static String? payeeName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }
}
