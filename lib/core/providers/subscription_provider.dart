import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/subscription_service.dart';

/// Returns true if the user has an active Dig Deeper Pro subscription.
/// Watches the ChangeNotifier so the UI rebuilds on purchase/restore.
final subscriptionProvider = ChangeNotifierProvider<SubscriptionService>(
  (_) => SubscriptionService.instance,
);

/// Convenience selector — use this in widgets that only need the bool.
final isProProvider = Provider<bool>(
  (ref) => ref.watch(subscriptionProvider).isPro,
);
