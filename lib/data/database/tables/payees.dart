import 'package:drift/drift.dart';

/// Saved payees — contacts the user frequently pays
class Payees extends Table {
  TextColumn get id => text()();
  TextColumn get upiId => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();

  // Usage tracking
  IntColumn get transactionCount =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get lastPaidAt => dateTime().nullable()();

  // Preferred expense category for this payee (null = not yet set)
  TextColumn get category => text().nullable()();

  // Last time a transaction to/from this payee was imported
  DateTimeColumn get lastTransactionAt => dateTime().nullable()();

  // Timestamps
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
