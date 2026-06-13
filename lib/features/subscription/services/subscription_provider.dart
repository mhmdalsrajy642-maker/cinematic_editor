import 'dart:async';

import '../models/subscription_models.dart';

/// Subscription provider abstraction used by subscription services.
abstract class SubscriptionProvider {
  /// Initialize the provider.
  Future<void> initialize();

  /// Load available subscription products.
  Future<List<SubscriptionPlan>> loadProducts();

  /// Purchase a subscription plan.
  Future<UserSubscription> purchase(String planId);

  /// Restore previously purchased subscriptions.
  Future<List<UserSubscription>> restorePurchases();

  /// Retrieve current subscription status for the active user.
  Future<SubscriptionStatus> getSubscriptionStatus(String userId);
}

/// RevenueCat provider placeholder implementation.
class RevenueCatProvider implements SubscriptionProvider {
  const RevenueCatProvider();

  @override
  Future<void> initialize() async {
    // TODO: Add RevenueCat SDK initialization when integration begins.
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<List<SubscriptionPlan>> loadProducts() async {
    // TODO: Load products from RevenueCat.
    return const [];
  }

  @override
  Future<UserSubscription> purchase(String planId) async {
    // TODO: Perform purchase flow via RevenueCat.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return UserSubscription(
      userId: 'unknown',
      planId: planId,
      status: SubscriptionStatus.trial,
      startedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      autoRenew: false,
    );
  }

  @override
  Future<List<UserSubscription>> restorePurchases() async {
    // TODO: Restore purchases via RevenueCat.
    return const [];
  }

  @override
  Future<SubscriptionStatus> getSubscriptionStatus(String userId) async {
    // TODO: Query active subscription state from RevenueCat.
    return SubscriptionStatus.expired;
  }
}

/// In-memory mock provider for subscription flows.
class MockSubscriptionProvider implements SubscriptionProvider {
  final List<SubscriptionPlan> _products;
  final Map<String, UserSubscription> _subscriptions;

  MockSubscriptionProvider({
    List<SubscriptionPlan>? products,
    Map<String, UserSubscription>? subscriptions,
  })  : _products = products ?? const [],
        _subscriptions = subscriptions ?? {};

  @override
  Future<void> initialize() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  @override
  Future<List<SubscriptionPlan>> loadProducts() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return List<SubscriptionPlan>.unmodifiable(_products);
  }

  @override
  Future<UserSubscription> purchase(String planId) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final product = _products.firstWhere(
      (plan) => plan.id == planId,
      orElse: () => throw StateError('Subscription plan not found: $planId'),
    );
    final subscription = UserSubscription(
      userId: 'mock-user',
      planId: product.id,
      status: SubscriptionStatus.active,
      startedAt: DateTime.now(),
      expiresAt: DateTime.now().add(product.period),
      autoRenew: true,
    );
    _subscriptions[subscription.userId] = subscription;
    return subscription;
  }

  @override
  Future<List<UserSubscription>> restorePurchases() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return List<UserSubscription>.unmodifiable(_subscriptions.values.toList());
  }

  @override
  Future<SubscriptionStatus> getSubscriptionStatus(String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final subscription = _subscriptions[userId];
    return subscription?.status ?? SubscriptionStatus.expired;
  }
}
