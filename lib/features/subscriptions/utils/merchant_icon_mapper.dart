import 'package:flutter/material.dart';

class MerchantIconMapper {
  /// Returns an appropriate icon for a given merchant name.
  static Widget getIconForMerchant(String merchantName, {double size = 24}) {
    final name = merchantName.toLowerCase().trim();

    // Map known brands to Material Icons that look similar
    // Alternatively, this could load network/asset images for accurate branding.
    if (name.contains('netflix')) {
      return Icon(Icons.movie_rounded, color: const Color(0xFFE50914), size: size);
    } else if (name.contains('spotify')) {
      return Icon(Icons.music_note_rounded, color: const Color(0xFF1DB954), size: size);
    } else if (name.contains('google') || name.contains('gpay')) {
      return Icon(Icons.g_mobiledata_rounded, color: Colors.blue, size: size * 1.5);
    } else if (name.contains('amazon')) {
      return Icon(Icons.shopping_cart_rounded, color: const Color(0xFFFF9900), size: size);
    } else if (name.contains('swiggy')) {
      return Icon(Icons.fastfood_rounded, color: const Color(0xFFFC8019), size: size);
    } else if (name.contains('zomato')) {
      return Icon(Icons.restaurant_rounded, color: const Color(0xFFCB202D), size: size);
    } else if (name.contains('uber')) {
      return Icon(Icons.local_taxi_rounded, color: Colors.black, size: size);
    } else if (name.contains('prime')) {
      return Icon(Icons.play_circle_filled_rounded, color: const Color(0xFF00A8E1), size: size);
    } else if (name.contains('apple')) {
      return Icon(Icons.apple_rounded, color: Colors.grey.shade400, size: size);
    }

    // Generic fallback icon
    return Icon(Icons.account_balance_wallet_rounded, color: Colors.grey.shade400, size: size);
  }
}
