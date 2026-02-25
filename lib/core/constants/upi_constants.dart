/// UPI-specific constants — URL scheme, known apps, response codes
class UpiConstants {
  UpiConstants._();

  // UPI URL scheme
  static const String upiScheme = 'upi';
  static const String upiAction = 'pay';
  static const String upiPrefix = 'upi://pay?';

  // UPI URI parameters
  static const String paramPayeeAddress = 'pa';
  static const String paramPayeeName = 'pn';
  static const String paramAmount = 'am';
  static const String paramCurrency = 'cu';
  static const String paramTransactionRef = 'tr';
  static const String paramTransactionNote = 'tn';
  static const String paramMerchantCode = 'mc';
  static const String paramUrl = 'url';
  static const String paramMode = 'mode';

  // UPI response fields
  static const String respTxnId = 'txnId';
  static const String respResponseCode = 'responseCode';
  static const String respApprovalRefNo = 'ApprovalRefNo';
  static const String respStatus = 'Status';
  static const String respTxnRef = 'txnRef';

  // UPI response codes
  static const String responseSuccess = '00';

  // Known UPI app package names (Android)
  static const Map<String, String> knownApps = {
    'com.google.android.apps.nbu.paisa.user': 'Google Pay',
    'com.phonepe.app': 'PhonePe',
    'net.one97.paytm': 'Paytm',
    'in.org.npci.upiapp': 'BHIM',
    'com.whatsapp': 'WhatsApp',
    'in.amazon.mShop.android.shopping': 'Amazon Pay',
    'com.csam.icici.bank.imobile': 'iMobile Pay',
    'com.freecharge': 'Freecharge',
    'com.mobikwik_new': 'MobiKwik',
  };

  // UPI app icons mapping (for display)
  static const Map<String, String> appIcons = {
    'Google Pay': '💳',
    'PhonePe': '📱',
    'Paytm': '💰',
    'BHIM': '🏦',
    'WhatsApp': '💬',
    'Amazon Pay': '📦',
    'iMobile Pay': '🏧',
    'Freecharge': '⚡',
    'MobiKwik': '📲',
  };
}
