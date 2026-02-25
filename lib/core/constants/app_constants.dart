/// App-wide constants for PayTrace
class AppConstants {
  AppConstants._();

  static const String appName = 'PayTrace';
  static const String appVersion = '1.0.0';

  // Transaction statuses
  static const String statusInitiated = 'INITIATED';
  static const String statusSuccess = 'SUCCESS';
  static const String statusFailure = 'FAILURE';
  static const String statusSubmitted = 'SUBMITTED';
  static const String statusCancelled = 'CANCELLED';
  static const String statusAbandoned = 'ABANDONED';
  static const String statusUnknown = 'UNKNOWN';

  // Transaction note max length (NPCI spec)
  static const int maxNoteLength = 50;

  // Currency
  static const String currency = 'INR';
  static const String currencySymbol = '₹';

  // Timeout for UPI response (5 minutes)
  static const Duration upiTimeout = Duration(minutes: 5);

  // QR types
  static const String qrTypeStatic = 'STATIC';
  static const String qrTypeDynamic = 'DYNAMIC';

  // Payment modes
  static const String modeQrScan = 'QR_SCAN';
  static const String modeContact = 'CONTACT';
  static const String modeManual = 'MANUAL';

  // Database
  static const String dbName = 'paytrace.db';

  // Expense categories
  static const List<String> defaultCategories = [
    'Food & Dining',
    'Shopping',
    'Transport',
    'Bills & Utilities',
    'Entertainment',
    'Health',
    'Education',
    'Rent',
    'Transfer',
    'Others',
  ];
}
