import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../state/providers.dart';
import '../models/subscription_model.dart';
import '../services/subscription_detector.dart';

// Provides all currently generated subscription instances
final subscriptionsProvider = FutureProvider<List<SubscriptionModel>>((ref) async {
  // We use `future` to easily await the whole list
  final transactions = await ref.watch(allTransactionsProvider.future);
  return SubscriptionDetector.detectSubscriptions(transactions);
});
