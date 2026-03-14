import 'package:drift/drift.dart';

/// Frequently used recipients for quick re-pay and insights.
class Payees extends Table {
  // Stable local identifier used by update/delete APIs.
  TextColumn get id => text().clientDefault(
    () => DateTime.now().microsecondsSinceEpoch.toString(),
  )();

  // Payee virtual payment address (unique logical identity).
  TextColumn get upiId => text()();

  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();

  // Optional learned category for this payee.
  TextColumn get category => text().nullable()();

  IntColumn get transactionCount => integer().withDefault(const Constant(0))();
  RealColumn get totalSent => real().withDefault(const Constant(0.0))();
  RealColumn get totalReceived => real().withDefault(const Constant(0.0))();

  DateTimeColumn get lastPaidAt => dateTime().nullable()();
  DateTimeColumn get lastTransactionAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {upiId},
  ];
}
