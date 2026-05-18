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
//    2. CategoryEngine keyword heuristics
//    3. "Others" (fallback)
//
//  The [normalizeKey] function converts a payee name / UPI ID into a
//  stable lowercase key so that minor variations of the same merchant
//  (e.g. "SWIGGY", "Swiggy India", "swiggy@icici") all map to the
//  same entry.
// ═══════════════════════════════════════════════════════════════════════════

class MerchantLearningService {
  MerchantLearningService._();

  // ─────────────────────────────────────────────────────────────────────────
  //  Key normalisation
  // ─────────────────────────────────────────────────────────────────────────

  /// Noise words that are stripped when building the merchant key from names.
  static const _noiseWords = {
    'ltd', 'llp', 'pvt', 'private', 'limited', 'india', 'the', 'and',
    'co', 'corp', 'corporation', 'inc', 'technologies', 'tech', 'services',
    'payment', 'via', 'pay', 'bank', 'upi',
  };

  /// Compute the normalised merchant key for a payee.
  ///
  /// Strategy:
  ///   1. If [upiId] looks like a merchant UPI VPA (contains '@' and the
  ///      prefix contains alpha characters), extract the first meaningful
  ///      alpha word from the prefix.
  ///      e.g. "swiggy.icici@hdfcbank" → "swiggy"
  ///           "orderswiggy@icici"     → "orderswiggy" (long prefix, fallback)
  ///   2. Otherwise normalise [payeeName]:
  ///      lower-case → strip punctuation → drop noise words → first 3 words.
  static String normalizeKey(String payeeName, String upiId) {
    // ── Attempt 1: UPI ID prefix ──
    if (upiId.contains('@') &&
        !upiId.startsWith('notif::') &&
        !upiId.startsWith('sms::')) {
      final prefix = upiId.split('@').first.toLowerCase();
      // e.g. "swiggy.icici" → ["swiggy", "icici"]
      final parts = prefix
          .replaceAll(RegExp(r'[^a-z0-9]'), ' ')
          .trim()
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 3 && !RegExp(r'^\d+$').hasMatch(w))
          .toList();

      if (parts.isNotEmpty) {
        // First alpha word of ≥4 chars yields a clean merchant token
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
    // If normalisation produced nothing, fall back to raw lowercase name
    return key.isEmpty ? name.toLowerCase().trim() : key;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Category resolution
  // ─────────────────────────────────────────────────────────────────────────

  /// Resolve the category for a transaction.
  ///
  /// When [merchantKey] is supplied (from [MerchantIdentity.buildKey]),
  /// lookup uses it directly — solving the key-format mismatch bug where
  /// category lookups failed because MerchantIdentity and MerchantLearning
  /// used different key schemes.
  ///
  /// Fallback order:
  ///   1. merchantKey lookup in merchant_categories
  ///   2. Legacy normalizeKey lookup (auto-migrates to merchantKey on hit)
  ///   3. CategoryEngine keyword heuristics
  ///   4. "Others"
  static Future<String> categorize(
    AppDatabase db, {
    required String payeeName,
    required String upiId,
    String? merchantKey,
  }) async {
    // 1. Primary: use unified merchantKey
    if (merchantKey != null && merchantKey.isNotEmpty) {
      final learned = await db.getMerchantCategory(merchantKey);
      if (learned != null && learned.isNotEmpty) {
        debugPrint('MerchantLearning: [$merchantKey] → "$learned" (learned)');
        return learned;
      }
    }

    // 2. Legacy key fallback (for data inserted before this change)
    final legacyKey = normalizeKey(payeeName, upiId);
    if (legacyKey.isNotEmpty) {
      final learned = await db.getMerchantCategory(legacyKey);
      if (learned != null && learned.isNotEmpty) {
        debugPrint('MerchantLearning: [$legacyKey] → "$learned" (legacy)');
        // Migrate to new key so future lookups use the unified key
        if (merchantKey != null && merchantKey.isNotEmpty) {
          await db.upsertMerchantCategory(merchantKey, learned);
        }
        return learned;
      }
    }

    // 3. Keyword heuristics
    final heuristic = CategoryEngine.categorize(
      payeeName: payeeName,
      upiId: upiId,
    );
    debugPrint(
        'MerchantLearning: [${merchantKey ?? legacyKey}] → "$heuristic" (heuristic)');
    return heuristic;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Learning
  // ─────────────────────────────────────────────────────────────────────────

  /// Persist a user-chosen category for a merchant.
  /// Stores under both the unified merchantKey AND the legacy key for compat.
  static Future<void> learn(
    AppDatabase db, {
    required String payeeName,
    required String upiId,
    required String category,
    String? merchantKey,
  }) async {
    if (merchantKey != null && merchantKey.isNotEmpty) {
      await db.upsertMerchantCategory(merchantKey, category);
      debugPrint('MerchantLearning: learned [$merchantKey] → "$category"');
    }
    final legacyKey = normalizeKey(payeeName, upiId);
    if (legacyKey.isNotEmpty && legacyKey != merchantKey) {
      await db.upsertMerchantCategory(legacyKey, category);
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
