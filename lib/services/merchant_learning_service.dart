import 'package:flutter/foundation.dart';

import '../core/utils/category_engine.dart';
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

  /// Resolve the category for [payeeName] / [upiId].
  ///
  /// 1. Check the learned merchant_categories table.
  /// 2. Fall back to [CategoryEngine] keyword heuristics.
  /// 3. Default → "Others".
  static Future<String> categorize(
    AppDatabase db, {
    required String payeeName,
    required String upiId,
  }) async {
    final key = normalizeKey(payeeName, upiId);

    // 1 — learned mapping
    if (key.isNotEmpty) {
      final learned = await db.getMerchantCategory(key);
      if (learned != null && learned.isNotEmpty) {
        debugPrint(
          'MerchantLearning: [$key] → "$learned" (from learned table)',
        );
        return learned;
      }
    }

    // 2 — keyword heuristics
    final heuristic = CategoryEngine.categorize(
      payeeName: payeeName,
      upiId: upiId,
    );
    debugPrint(
      'MerchantLearning: [$key] → "$heuristic" (heuristic)',
    );
    return heuristic;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Learning
  // ─────────────────────────────────────────────────────────────────────────

  /// Persist a user-chosen category for a merchant.
  ///
  /// Call this whenever the user manually changes a transaction's category.
  /// All future transactions whose [normalizeKey] matches will use the stored
  /// category instead of the heuristic fallback.
  static Future<void> learn(
    AppDatabase db, {
    required String payeeName,
    required String upiId,
    required String category,
  }) async {
    final key = normalizeKey(payeeName, upiId);
    if (key.isEmpty) return;

    await db.upsertMerchantCategory(key, category);
    debugPrint(
      'MerchantLearning: learned [$key] → "$category"',
    );
  }

  /// Remove the learned category for a merchant (reset to heuristic).
  static Future<void> forget(
    AppDatabase db, {
    required String payeeName,
    required String upiId,
  }) async {
    final key = normalizeKey(payeeName, upiId);
    if (key.isEmpty) return;
    await db.deleteMerchantCategory(key);
    debugPrint('MerchantLearning: forgot [$key]');
  }
}
