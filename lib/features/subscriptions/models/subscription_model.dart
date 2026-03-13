class SubscriptionModel {
  final String merchantName;
  final double amount;
  final String frequency; // "Monthly", "Yearly", "Weekly"
  final DateTime nextExpectedPayment;
  final DateTime lastPaymentDate;

  SubscriptionModel({
    required this.merchantName,
    required this.amount,
    required this.frequency,
    required this.nextExpectedPayment,
    required this.lastPaymentDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubscriptionModel &&
          runtimeType == other.runtimeType &&
          merchantName == other.merchantName &&
          amount == other.amount &&
          frequency == other.frequency;

  @override
  int get hashCode =>
      merchantName.hashCode ^ amount.hashCode ^ frequency.hashCode;
}
