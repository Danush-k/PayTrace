import 'package:flutter/foundation.dart';

import '../core/utils/category_engine.dart';
import '../core/utils/merchant_identity.dart';
import '../data/database/app_database.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  MERCHANT LEARNING SERVICE
//
//  Provides category resolution with a learn-and-remember capability.
//
//  Resolution order (highest to lowest priority):
//    1. User-learned mapping stored in merchant_categories table
//       (looked up by merchantKey from MerchantIdentity.buildKey())
//    2. CategoryEngine keyword heuristics
//    3. "Others" (fallback)
//
//  IMPORTANT: This service now uses the SAME key format as
//  MerchantIdentity.buildKey() for merchant_categories lookups.
//  The old normalizeKey() is kept for backward compatibility but
//  all new code should pass merchantKey explicitly.
// ═══════════════════════════════════════════════════════════════════════════

class MerchantLearningService {
  MerchantLearningService._();

  // ─────────────────────────────────────────────────────────────────────────
  //  Key normalisation (backward compatibility)
  // ─────────────────────────────────────────────────────────────────────────

  /// Noise words that are stripped when building the merchant key from names.
  static const _noiseWords = {
    'ltd', 'llp', 'pvt', 'private', 'limited', 'india', 'the', 'and',
    'co', 'corp', 'corporation', 'inc', 'technologies', 'tech', 'services',
    'payment', 'via', 'pay', 'bank', 'upi',
  };

  /// Compute the normalised merchant key for a payee.
  ///
  /// **Prefer passing [merchantKey] to [categorize]/[learn]/[forget] directly
  /// instead of calling this method.** This method exists for backward
  /// compatibility with UI code that does not yet have the merchantKey.
  ///
  /// Strategy:
  ///   1. If [upiId] looks like a merchant UPI VPA (contains '@' and the
  ///      prefix contains alpha characters), extract the first meaningful
  ///      alpha word from the prefix.
  ///   2. Otherwise normalise [payeeName]:
  ///      lower-case → strip punctuation → drop noise words → first 3 words.
  static String normalizeKey(String payeeName, String upiId) {
    // ── Attempt 1: UPI ID prefix ──
    if (upiId.contains('@') &&
        !upiId.startsWith('notif::') &&
        !upiId.startsWith('sms::')) {
      final prefix = upiId.split('@').first.toLowerCase();
      final parts = prefix
          .replaceAll(RegExp(r'[^a-z0-9]'), ' ')
          .trim()
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 3 && !RegExp(r'^\d+$').hasMatch(w))
          .toList();

      if (parts.isNotEmpty) {
        final candidate = parts.firstWhere(
          (p) => p.length >= 4,
          orElse: () => parts.first,
        );
        if (candidate.length >= 3) return candidate;
      }
    }

    // ── Attempt 2: Normalise payeeName ──
    return _normalizeName(payeeName);
  }

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

  // ─────────────────────────────────────────────────────────────────────────
  //  Category resolution
  // ─────────────────────────────────────────────────────────────────────────

  /// Resolve the category for a transaction.
  ///
  /// When [merchantKey] is supplied (from [MerchantIdentity.buildKey]),
  /// the lookup uses that key directly against the merchant_categories table.
  /// This ensures the SAME key used for transaction grouping is also used
  /// for category learning — solving the key-format mismatch bug.
  ///
  /// Fallback:
  ///   1. [merchantKey] lookup in merchant_categories
  ///   2. Legacy [normalizeKey] lookup (in case old data exists)
  ///   3. [CategoryEngine] keyword heuristics
  ///   4. "Others"
  static Future<String> categorize(
    AppDatabase db, {
    required String payeeName,
    required String upiId,
    String? merchantKey,
  }) async {
    // 1 — primary: use merchantKey if provided
    if (merchantKey != null && merchantKey.isNotEmpty) {
      final learned = await db.getMerchantCategory(merchantKey);
      if (learned != null && learned.isNotEmpty) {
        debugPrint(
          'MerchantLearning: [$merchantKey] → "$learned" (from learned table)',
        );
        return learned;
      }
    }

    // 2 — fallback: try legacy normalizeKey (for old data migrating in)
    final legacyKey = normalizeKey(payeeName, upiId);
    if (legacyKey.isNotEmpty) {
      final learned = await db.getMerchantCategory(legacyKey);
      if (learned != null && learned.isNotEmpty) {
        debugPrint(
          'MerchantLearning: [$legacyKey] → "$learned" (legacy key match)',
        );
        // Migrate: also store under the new merchantKey so future lookups
        // use the unified key directly.
        if (merchantKey != null && merchantKey.isNotEmpty) {
          await db.upsertMerchantCategory(merchantKey, learned);
        }
        return learned;
      }
    }

    // 3 — keyword heuristics
    final heuristic = CategoryEngine.categorize(
      payeeName: payeeName,
      upiId: upiId,
    );
    debugPrint(
      'MerchantLearning: [${merchantKey ?? legacyKey}] → "$heuristic" (heuristic)',
    );
    return heuristic;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Learning
  // ─────────────────────────────────────────────────────────────────────────

  /// Persist a user-chosen category for a merchant.
  ///
  /// When [merchantKey] is provided, the mapping is stored under that key
  /// (matching the transactions.merchantKey column). This ensures future
  /// category lookups find the correct mapping.
  ///
  /// For backward compatibility, the mapping is ALSO stored under the
  /// legacy normalizeKey so older transactions still resolve correctly.
  static Future<void> learn(
    AppDatabase db, {
    required String payeeName,
    required String upiId,
    required String category,
    String? merchantKey,
  }) async {
    // Store under the unified merchantKey
    if (merchantKey != null && merchantKey.isNotEmpty) {
      await db.upsertMerchantCategory(merchantKey, category);
      debugPrint(
        'MerchantLearning: learned [$merchantKey] → "$category"',
      );
    }

    // Also store under legacy key for backward compat
    final legacyKey = normalizeKey(payeeName, upiId);
    if (legacyKey.isNotEmpty && legacyKey != merchantKey) {
      await db.upsertMerchantCategory(legacyKey, category);
      debugPrint(
        'MerchantLearning: learned (legacy) [$legacyKey] → "$category"',
      );
    }
  }

  /// Remove the learned category for a merchant (reset to heuristic).
  static Future<void> forget(
    AppDatabase db, {
    required String payeeName,
    required String upiId,
    String? merchantKey,
  }) async {
    if (merchantKey != null && merchantKey.isNotEmpty) {
      await db.deleteMerchantCategory(merchantKey);
    }
    final legacyKey = normalizeKey(payeeName, upiId);
    if (legacyKey.isNotEmpty) {
      await db.deleteMerchantCategory(legacyKey);
    }
    debugPrint('MerchantLearning: forgot [${merchantKey ?? legacyKey}]');
  }
}
