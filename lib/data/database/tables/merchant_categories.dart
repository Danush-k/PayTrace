import 'package:drift/drift.dart';

/// Merchant-to-category learning table.
///
/// Stores the user's preferred category for each merchant so that future
/// transactions from the same merchant are automatically assigned the
/// correct category without re-classifying from scratch.
///
/// [merchantKey] is a normalized, lowercase identifier derived from the
/// payee name or UPI ID prefix (see [MerchantLearningService.normalizeKey]).
/// It acts as the primary key so each merchant has exactly one entry.
class MerchantCategories extends Table {
  /// Normalized merchant identifier (primary key).
  /// Examples: "swiggy", "uber", "amazon", "john doe"
  TextColumn get merchantKey => text()();

  /// Category label, e.g. "Food & Dining", "Transport", "Shopping".
  TextColumn get category => text()();

  /// Last time this mapping was set (by user or by initial heuristic).
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {merchantKey};
}
