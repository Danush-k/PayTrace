import 'package:drift/drift.dart';

/// Monthly budget targets — one row per month/year
class Budgets extends Table {
  TextColumn get id => text()();
  IntColumn get year => integer()();
  IntColumn get month => integer()();
  RealColumn get limitAmount => real()();

  // Timestamps
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
