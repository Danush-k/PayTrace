/// Builds a stable, unique merchant key from available transaction signals.
///
/// Priority (highest to lowest):
///   1. mc::<merchantCode>   — QR merchant code (definitive, globally unique)
///   2. vpa::<upi@handle>   — real named VPA (alpha prefix, non-phone)
///   3. personal::<upi>     — phone-number VPA (personal contact)
///   4. name::<normalized>  — normalised merchant name from SMS/display
///   5. unknown::<ms>       — per-transaction fallback (cannot be grouped)
///
/// Synthetic IDs ('notif::' / 'sms::') fall through to Signal 4 (name-based
/// key) so two notifications from the SAME merchant produce the SAME key
/// and are correctly grouped — instead of both becoming unknown::.
///
/// Phone-number VPAs get a dedicated 'personal::' prefix so they are
/// never mixed with merchant VPAs and renaming one person does not
/// rename another who happens to share the same bank handle.
class MerchantIdentity {
  MerchantIdentity._();

  // Generic names that must never become a merchant key.
  static const _genericPayeeNames = {
    'unknown', 'payment', 'upi', 'bank', 'google', 'phonepe', 'paytm',
    'amazon', 'bhim', 'pay', 'googlepay', 'gpay',
  };

  /// Noise words stripped when building a name-based key.
  static const _noiseWords = {
    'ltd', 'llp', 'pvt', 'private', 'limited', 'india', 'the', 'and',
    'co', 'corp', 'corporation', 'inc', 'technologies', 'tech', 'services',
    'payment', 'via', 'pay', 'bank', 'upi',
  };

  /// Build the merchant key from available payment signals.
  static String buildKey({
    required String upiId,
    required String payeeName,
    String? merchantCode,
    String? accountHint,
    String? bankName,
  }) {
    // Signal 1: QR merchant code — universally unique across all merchants
    if (merchantCode != null && merchantCode.isNotEmpty) {
      return 'mc::$merchantCode';
    }

    // Signal 2 / 3: Real VPA — only non-synthetic IDs
    if (upiId.contains('@') &&
        !upiId.startsWith('notif::') &&
        !upiId.startsWith('sms::')) {
      final lower = upiId.toLowerCase();
      final prefix = lower.split('@').first;
      final isPhoneNumber = RegExp(r'^\d{8,}$').hasMatch(prefix);

      if (isPhoneNumber) {
        // Signal 3: Phone-number VPA — stable personal key
        return 'personal::$lower';
      }

      if (prefix.length >= 3) {
        // Signal 2: Named VPA (business / personal with alpha username)
        return 'vpa::$lower';
      }
    }

    // Signal: Peer Account — stable grouping for numeric account hints in SMS
    if (RegExp(r'^\d{3,4}$').hasMatch(payeeName) && bankName != null) {
      final sanitizedBank = bankName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      return 'peer_acc::$sanitizedBank::$payeeName';
    }

    // Signal: Bank Account — stable grouping for generic bank SMS
    if (accountHint != null && accountHint.isNotEmpty && bankName != null) {
      final sanitizedBank = bankName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      return 'acc::$sanitizedBank::$accountHint';
    }

    // Signal 4: Normalised merchant name.
    // Uses the SAME normalisation as MerchantLearningService so category
    // lookups always find the right row in merchant_categories.
    final nameKey = _normalizeName(payeeName);
    if (nameKey.isNotEmpty && !_isTooGeneric(nameKey)) {
      return 'name::$nameKey';
    }

    // Signal 5: Unique per-transaction key — cannot be grouped
    return 'unknown::${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Normalise a payee name into a stable lowercase key.
  static String normalizeName(String name) => _normalizeName(name);

  static String _normalizeName(String name) {
    final cleaned = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .trim();
    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !_noiseWords.contains(w))
        .take(3)
        .toList();
    final key = words.join(' ').trim();
    return key.isEmpty ? name.toLowerCase().trim() : key;
  }

  /// Returns true if the normalised key is too generic to be a useful
  /// merchant identifier.
  static bool _isTooGeneric(String key) {
    if (key.length < 3) return true;
    if (RegExp(r'^\d+$').hasMatch(key)) return true;
    final words = key.split(' ');
    if (words.every((w) => _genericPayeeNames.contains(w))) return true;
    return _genericPayeeNames.contains(key);
  }
}
