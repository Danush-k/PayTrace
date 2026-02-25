/// Classification result for a payee
enum PayeeType { merchant, personal, unknown }

/// Detects whether a UPI payee is a merchant or personal account.
///
/// Uses multiple heuristics:
/// 1. Merchant Code (`mc`) parameter in QR — definitive merchant signal
/// 2. VPA handle — certain handles are merchant-only (e.g. @yesb, @axisbank)
/// 3. VPA structure — numeric-heavy VPAs are usually merchant accounts
/// 4. Payee name keywords — "store", "mart", "hotel", etc.
class MerchantDetector {
  MerchantDetector._();

  /// Classify a payee based on available QR data
  static PayeeType classify({
    required String upiId,
    required String payeeName,
    String? merchantCode,
  }) {
    // Signal 1: Merchant Code present → definitive merchant
    if (merchantCode != null && merchantCode.isNotEmpty) {
      return PayeeType.merchant;
    }

    // Signal 2: VPA handle check
    final handle = _extractHandle(upiId);
    if (_merchantHandles.contains(handle)) {
      return PayeeType.merchant;
    }
    if (_personalHandles.contains(handle)) {
      return PayeeType.personal;
    }

    // Signal 3: VPA username structure — numeric-heavy = likely merchant
    final username = upiId.split('@').first;
    final digitCount = username.replaceAll(RegExp(r'[^0-9]'), '').length;
    final digitRatio = username.isEmpty ? 0.0 : digitCount / username.length;
    if (digitRatio > 0.7 && username.length > 6) {
      return PayeeType.merchant;
    }

    // Signal 4: Payee name keywords
    final nameLower = payeeName.toLowerCase().trim();
    for (final keyword in _merchantNameKeywords) {
      if (nameLower.contains(keyword)) {
        return PayeeType.merchant;
      }
    }

    // Signal 5: Payee name looks like a person (2-3 words, all alpha)
    final words = nameLower.split(RegExp(r'\s+'));
    if (words.length >= 2 &&
        words.length <= 4 &&
        words.every((w) => RegExp(r'^[a-z]+$').hasMatch(w))) {
      return PayeeType.personal;
    }

    return PayeeType.unknown;
  }

  /// Get a display label for the payee type
  static String label(PayeeType type) {
    switch (type) {
      case PayeeType.merchant:
        return 'Merchant';
      case PayeeType.personal:
        return 'Personal';
      case PayeeType.unknown:
        return 'Unknown';
    }
  }

  /// Get an icon for the payee type
  static String icon(PayeeType type) {
    switch (type) {
      case PayeeType.merchant:
        return '🏪';
      case PayeeType.personal:
        return '👤';
      case PayeeType.unknown:
        return '❓';
    }
  }

  static String _extractHandle(String upiId) {
    final parts = upiId.split('@');
    return parts.length == 2 ? parts[1].toLowerCase() : '';
  }

  // VPA handles that are merchant/business-only
  static const _merchantHandles = {
    'yesb',
    'yesbiz',
    'axisbank',
    'okbizaxis',
    'hdfcbank',
    'icici',
    'sbi',
    'ratn',
    'cnrb',
    'barodampay',
    'abfspay',
    'freecharge',
    'jupiteraxis',
    'slash',
    'rzp',
    'paysharp',
    'cashfree',
    'payu',
    'zoho',
  };

  // VPA handles that are typically personal accounts
  static const _personalHandles = {
    'ybl',       // PhonePe personal
    'ibl',       // PhonePe
    'axl',       // PhonePe on Axis
    'okhdfcbank', // Google Pay
    'okicici',   // Google Pay
    'oksbi',     // Google Pay
    'paytm',     // Paytm personal
    'ptyes',     // Paytm
    'pthdfc',    // Paytm
    'ptaxis',    // Paytm
    'upi',       // BHIM generic
    'apl',       // Amazon Pay
    'waicici',   // WhatsApp Pay
    'wahdfcbank', // WhatsApp Pay
    'wasbi',     // WhatsApp Pay
  };

  // Keywords in payee name indicating a merchant
  static const _merchantNameKeywords = [
    'store',
    'shop',
    'mart',
    'market',
    'hotel',
    'restaurant',
    'cafe',
    'coffee',
    'pizza',
    'burger',
    'food',
    'pharmacy',
    'medical',
    'hospital',
    'clinic',
    'labs',
    'diagnostic',
    'salon',
    'spa',
    'gym',
    'fitness',
    'electronics',
    'mobile',
    'recharge',
    'telecom',
    'airtel',
    'jio',
    'bsnl',
    'vodafone',
    'petrol',
    'fuel',
    'gas',
    'station',
    'garage',
    'service',
    'repair',
    'laundry',
    'dry clean',
    'super',
    'hyper',
    'bazaar',
    'mall',
    'plaza',
    'enterprise',
    'trading',
    'pvt ltd',
    'private limited',
    'llp',
    'limited',
    'inc',
    'corp',
    'industries',
    'solutions',
    'tech',
    'digital',
    'online',
    'payments',
    'insurance',
    'finance',
    'bank',
    'mutual fund',
    'swiggy',
    'zomato',
    'dunzo',
    'bigbasket',
    'grofers',
    'blinkit',
    'flipkart',
    'amazon',
    'myntra',
    'ajio',
    'nykaa',
    'uber',
    'ola',
    'rapido',
  ];
}
