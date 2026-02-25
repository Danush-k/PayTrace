import '../constants/app_constants.dart';
import 'merchant_detector.dart';

/// Auto-categorizes transactions based on payee name and UPI ID patterns.
/// Inspired by GPay/Paytm's smart categorization.
class CategoryEngine {
  CategoryEngine._();

  /// Categorize a transaction based on payee info
  static String categorize({
    required String payeeName,
    required String upiId,
    String? merchantCode,
  }) {
    final nameLower = payeeName.toLowerCase().trim();
    final upiLower = upiId.toLowerCase().trim();

    // Check if personal transfer first
    final payeeType = MerchantDetector.classify(
      upiId: upiId,
      payeeName: payeeName,
      merchantCode: merchantCode,
    );
    if (payeeType == PayeeType.personal) {
      return 'Transfer';
    }

    // Match against category patterns
    for (final entry in _categoryPatterns.entries) {
      for (final keyword in entry.value) {
        if (nameLower.contains(keyword) || upiLower.contains(keyword)) {
          return entry.key;
        }
      }
    }

    return 'Others';
  }

  /// Category → icon mapping
  static String categoryIcon(String category) {
    return _categoryIcons[category] ?? '📋';
  }

  /// Category → color index (for charts)
  static int categoryColorIndex(String category) {
    final idx = AppConstants.defaultCategories.indexOf(category);
    return idx >= 0 ? idx : AppConstants.defaultCategories.length - 1;
  }

  // ─── Keyword patterns per category ───

  static const Map<String, List<String>> _categoryPatterns = {
    'Food & Dining': [
      'swiggy', 'zomato', 'restaurant', 'cafe', 'coffee', 'pizza',
      'burger', 'food', 'bakery', 'dhaba', 'biryani', 'chicken',
      'kitchen', 'eat', 'dine', 'canteen', 'mess', 'tiffin',
      'dominos', 'mcdonalds', 'kfc', 'subway', 'starbucks',
      'dunzo', 'blinkit', 'bigbasket', 'grofers', 'zepto',
      'instamart', 'swiggy.com', 'zomato.com',
    ],
    'Transport': [
      'uber', 'ola', 'rapido', 'metro', 'fuel', 'petrol', 'diesel',
      'parking', 'toll', 'fastag', 'irctc', 'railway', 'bus',
      'cab', 'taxi', 'auto', 'ride', 'yulu', 'bounce', 'vogo',
      'bp.', 'iocl', 'hpcl', 'bpcl', 'indian oil', 'shell',
    ],
    'Bills & Utilities': [
      'airtel', 'jio', 'bsnl', 'vodafone', 'vi.', 'electricity',
      'water', 'gas', 'broadband', 'recharge', 'postpaid',
      'prepaid', 'dth', 'tatasky', 'dish', 'wifi', 'internet',
      'bescom', 'msedcl', 'torrent', 'adani', 'bill',
      'municipal', 'kseb', 'tneb', 'subscription',
    ],
    'Shopping': [
      'flipkart', 'amazon', 'myntra', 'ajio', 'nykaa', 'meesho',
      'store', 'shop', 'mart', 'bazaar', 'mall', 'retail',
      'fashion', 'clothing', 'wear', 'electronics', 'mobile',
      'croma', 'reliance', 'dmart', 'bigbazaar', 'lifestyle',
      'decathlon', 'ikea', 'pepperfry',
    ],
    'Health': [
      'pharmacy', 'medical', 'hospital', 'clinic', 'doctor',
      'apollo', 'medplus', 'labs', 'diagnostic', 'netmeds',
      'pharmeasy', 'practo', '1mg', 'healthkart', 'dental',
      'optical', 'eye', 'pathology',
    ],
    'Entertainment': [
      'netflix', 'spotify', 'hotstar', 'prime', 'cinema',
      'theatre', 'multiplex', 'pvr', 'inox', 'bookmyshow',
      'gaming', 'game', 'youtube', 'disney', 'zee', 'sony',
      'jiocinema', 'music', 'concert',
    ],
    'Education': [
      'school', 'college', 'university', 'tuition', 'coaching',
      'course', 'udemy', 'coursera', 'unacademy', 'byju',
      'vedantu', 'exam', 'fee', 'library', 'book',
    ],
    'Rent': [
      'rent', 'landlord', 'society', 'maintenance', 'flat',
      'apartment', 'housing', 'pg ', 'hostel', 'lease',
    ],
  };

  static const Map<String, String> _categoryIcons = {
    'Food & Dining': '🍔',
    'Shopping': '🛍️',
    'Transport': '🚗',
    'Bills & Utilities': '💡',
    'Entertainment': '🎬',
    'Health': '💊',
    'Education': '📚',
    'Rent': '🏠',
    'Transfer': '💸',
    'Others': '📋',
  };
}
