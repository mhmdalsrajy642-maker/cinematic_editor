import '../models/subscription_models.dart';
import 'subscription_provider.dart';

/// Service layer that orchestrates subscription actions using a provider.
class SubscriptionService {
  final SubscriptionProvider _provider;
  UserSubscription? _currentSubscription;
  SubscriptionPlan? _activePlan;
  List<SubscriptionPlan> _availablePlans = const [];

  SubscriptionService({required SubscriptionProvider provider}) : _provider = provider;

  /// Initializes the underlying subscription provider.
  Future<void> initialize() async {
    await _provider.initialize();
    _availablePlans = await _provider.loadProducts();
  }

  /// Returns the current cached subscription, if any.
  UserSubscription? get currentSubscription => _currentSubscription;

  /// Returns the currently cached active plan, if any.
  SubscriptionPlan? get activePlan => _activePlan;

  /// Returns cached subscription products.
  List<SubscriptionPlan> get availablePlans => List.unmodifiable(_availablePlans);

  /// Loads the current subscription for the user.
  Future<UserSubscription?> loadCurrentSubscription(String userId) async {
    final status = await _provider.getSubscriptionStatus(userId);
    final subscription = _currentSubscription?.copyWith(status: status) ??
        UserSubscription(
          userId: userId,
          planId: '',
          status: status,
          startedAt: DateTime.now(),
          expiresAt: null,
          autoRenew: false,
        );

    _currentSubscription = subscription;
    return _currentSubscription;
  }

  /// Finds the active plan by identifier.
  Future<SubscriptionPlan?> loadActivePlan(String planId) async {
    final planIndex = _availablePlans.indexWhere((plan) => plan.id == planId);
    _activePlan = planIndex == -1 ? null : _availablePlans[planIndex];
    return _activePlan;
  }

  /// Starts a purchase flow for the selected plan.
  Future<UserSubscription> purchasePlan(String userId, String planId) async {
    final result = await _provider.purchase(planId);
    _currentSubscription = result.copyWith(userId: userId);
    final planIndex = _availablePlans.indexWhere((plan) => plan.id == planId);
    _activePlan = planIndex == -1 ? null : _availablePlans[planIndex];
    return _currentSubscription!;
  }

  /// Restores purchases and updates the cached subscription state.
  Future<List<UserSubscription>> restorePurchases(String userId) async {
    final restored = await _provider.restorePurchases();
    final userSubscriptions = restored.where((sub) => sub.userId == userId).toList();
    if (userSubscriptions.isNotEmpty) {
      _currentSubscription = userSubscriptions.last;
      _activePlan = _availablePlans.firstWhere(
        (plan) => plan.id == _currentSubscription!.planId,
        orElse: () => null,
      );
    }
    return userSubscriptions;
  }

  /// Refreshes the subscription status for the active user.
  Future<SubscriptionStatus> refreshSubscriptionStatus(String userId) async {
    final status = await _provider.getSubscriptionStatus(userId);
    if (_currentSubscription != null && _currentSubscription!.userId == userId) {
      _currentSubscription = _currentSubscription!.copyWith(status: status);
    }
    return status;
  }
}
