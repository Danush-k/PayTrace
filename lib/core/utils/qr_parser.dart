import '../constants/upi_constants.dart';

/// Parsed data from a UPI QR code
class QrPaymentData {
  final String payeeAddress; // pa — UPI VPA
  final String payeeName; // pn — display name
  final double? amount; // am — null for static QR
  final String? transactionNote; // tn
  final String? merchantCode; // mc
  final String? transactionRef; // tr
  final String? referenceUrl; // url
  final bool isDynamic; // true if amount is embedded

  const QrPaymentData({
    required this.payeeAddress,
    required this.payeeName,
    this.amount,
    this.transactionNote,
    this.merchantCode,
    this.transactionRef,
    this.referenceUrl,
    required this.isDynamic,
  });

  @override
  String toString() =>
      'QrPaymentData(pa: $payeeAddress, pn: $payeeName, am: $amount, '
      'isDynamic: $isDynamic)';
}

/// Parses UPI QR code strings into structured payment data.
///
/// Handles both:
/// - **Static QR**: `upi://pay?pa=merchant@ybl&pn=StoreName`
///   (no amount — user enters manually)
/// - **Dynamic QR**: `upi://pay?pa=merchant@ybl&pn=StoreName&am=150.00`
///   (amount pre-filled, read-only)
class QrParser {
  QrParser._();

  /// Parse a raw QR code string into [QrPaymentData].
  /// Returns `null` if the QR is not a valid UPI payment QR.
  static QrPaymentData? parse(String rawQrData) {
    final trimmed = rawQrData.trim();

    // Must start with upi://pay?
    if (!trimmed.toLowerCase().startsWith(UpiConstants.upiPrefix.toLowerCase())) {
      return null;
    }

    try {
      final uri = Uri.parse(trimmed);
      final params = uri.queryParameters;

      // pa (payee address) is mandatory
      final payeeAddress = params[UpiConstants.paramPayeeAddress];
      if (payeeAddress == null || payeeAddress.isEmpty) {
        return null;
      }

      // pn (payee name) — default to UPI ID if missing
      final payeeName = params[UpiConstants.paramPayeeName] ?? payeeAddress;

      // am (amount) — determines static vs dynamic
      double? amount;
      final amountStr = params[UpiConstants.paramAmount];
      if (amountStr != null && amountStr.isNotEmpty) {
        amount = double.tryParse(amountStr);
      }

      final isDynamic = amount != null && amount > 0;

      return QrPaymentData(
        payeeAddress: payeeAddress,
        payeeName: Uri.decodeComponent(payeeName),
        amount: amount,
        transactionNote: params[UpiConstants.paramTransactionNote],
        merchantCode: params[UpiConstants.paramMerchantCode],
        transactionRef: params[UpiConstants.paramTransactionRef],
        referenceUrl: params[UpiConstants.paramUrl],
        isDynamic: isDynamic,
      );
    } catch (e) {
      return null;
    }
  }

  /// Build a UPI URI string from payment details.
  /// Used to trigger UPI intent.
  ///
  /// CRITICAL: Only send the 4 mandatory NPCI params: pa, pn, am, cu.
  /// GPay/PhonePe REJECT intents with `tr` (transaction ref) from
  /// non-registered PSP apps — they show "bank limit exceeded" which
  /// is actually a parameter validation failure on their end.
  /// The `tn` (transaction note) is also skipped as some banks flag it.
  ///
  /// PayTrace generates its own `tr` locally for tracking — it's NOT
  /// sent in the UPI URI.
  static String buildUpiUri({
    required String payeeAddress,
    required String payeeName,
    required double amount,
    String currency = 'INR',
  }) {
    // Format amount to exactly 2 decimal places per NPCI spec
    final formattedAmount = amount.toStringAsFixed(2);

    // Clean payee name — only alphanumeric, spaces, and dots
    final cleanName = payeeName.trim().replaceAll(RegExp(r'[^a-zA-Z0-9 .]'), '');
    // Encode spaces as %20 for the name field
    final encodedName = cleanName.replaceAll(' ', '%20');

    // Only the 4 essential params — nothing else
    // pa = payee VPA, pn = payee name, am = amount, cu = currency
    return 'upi://pay?pa=${payeeAddress.trim()}&pn=$encodedName&am=$formattedAmount&cu=${currency.toUpperCase()}';
  }

  /// Validate a UPI VPA format (basic check).
  /// Format: username@bankcode (e.g., user@ybl, shop@paytm)
  static bool isValidUpiId(String upiId) {
    final regex = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$');
    return regex.hasMatch(upiId.trim());
  }
}
