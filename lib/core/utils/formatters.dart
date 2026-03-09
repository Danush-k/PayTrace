import 'package:intl/intl.dart';

/// Currency and date formatting utilities
class Formatters {
  Formatters._();

  // ─── Currency ───
  static final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final _compactCurrencyFormat = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 1,
  );

  /// Format amount as ₹1,234.56
  static String currency(double amount) => _currencyFormat.format(amount);

  /// Format amount as ₹1.2K, ₹3.4L etc.
  static String currencyCompact(double amount) =>
      _compactCurrencyFormat.format(amount).replaceAll('T', 'K');

  /// Format amount without symbol: 1,234.56
  static String amountOnly(double amount) =>
      NumberFormat('#,##,##0.00', 'en_IN').format(amount);

  // ─── Dates ───

  /// "12 Feb 2026"
  static String dateShort(DateTime date) =>
      DateFormat('dd MMM yyyy').format(date);

  /// "12 Feb 2026, 3:45 PM"
  static String dateTime(DateTime date) =>
      DateFormat('dd MMM yyyy, h:mm a').format(date);

  /// "3:45 PM"
  static String timeOnly(DateTime date) =>
      DateFormat('h:mm a').format(date);

  /// "Today", "Yesterday", or "12 Feb"
  static String dateRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);

    final diff = today.difference(dateDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(date); // "Monday"
    return DateFormat('dd MMM').format(date); // "12 Feb"
  }

  /// "Feb 2026"
  static String monthYear(DateTime date) =>
      DateFormat('MMM yyyy').format(date);

  // ─── UPI ───

  /// Mask UPI ID: "user@ybl" → "us***@ybl"
  static String maskUpiId(String upiId) {
    final parts = upiId.split('@');
    if (parts.length != 2) return upiId;
    final name = parts[0];
    final bank = parts[1];
    if (name.length <= 2) return '$name***@$bank';
    return '${name.substring(0, 2)}***@$bank';
  }

  /// Truncate text with ellipsis
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
