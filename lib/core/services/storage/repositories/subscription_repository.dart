// lib/core/services/storage/repositories/subscription_repository.dart
// مستودع الاشتراكات - مسؤول عن إدارة بيانات الاشتراك والميزات
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../app_database.dart';

class SubscriptionRepository {
  final AppDatabase database;

  SubscriptionRepository({required this.database});

  /// إنشاء اشتراك جديد
  Future<String> createSubscription({
    required String userId,
    required String tier,
    required List<String> features,
    int maxProjects = 3,
    int maxExports = 5,
    int maxResolution = 1080,
    bool isAutoRenewal = true,
  }) async {
    final subscriptionId = const Uuid().v4();
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(days: 30));

    await database.into(database.subscriptions).insert(
      SubscriptionData(
        subscriptionId: subscriptionId,
        userId: userId,
        tier: tier,
        status: 'active',
        activatedAt: now,
        expiresAt: expiresAt,
        renewalStatus: isAutoRenewal ? 'auto' : 'manual',
        features: features.join(','),
        maxProjects: maxProjects,
        maxExports: maxExports,
        maxResolution: maxResolution,
      ),
    );

    return subscriptionId;
  }

  /// الحصول على اشتراك المستخدم
  Future<SubscriptionData?> getUserSubscription(String userId) {
    return (database.select(database.subscriptions)
          ..where((tbl) => tbl.userId.equals(userId)))
        .getSingleOrNull();
  }

  /// الحصول على الاشتراك بواسطة ID
  Future<SubscriptionData?> getSubscription(String subscriptionId) {
    return (database.select(database.subscriptions)
          ..where((tbl) => tbl.subscriptionId.equals(subscriptionId)))
        .getSingleOrNull();
  }

  /// تحديث تاريخ انتهاء الاشتراك
  Future<void> renewSubscription(String subscriptionId) async {
    final subscription = await getSubscription(subscriptionId);
    if (subscription == null) return;

    final newExpiresAt =
        DateTime.now().add(const Duration(days: 30));

    await (database.update(database.subscriptions)
          ..where((tbl) => tbl.subscriptionId.equals(subscriptionId)))
        .write(
          SubscriptionData(
            subscriptionId: subscriptionId,
            userId: subscription.userId,
            tier: subscription.tier,
            status: 'active',
            activatedAt: subscription.activatedAt,
            expiresAt: newExpiresAt,
            renewalStatus: subscription.renewalStatus,
            features: subscription.features,
            maxProjects: subscription.maxProjects,
            maxExports: subscription.maxExports,
            maxResolution: subscription.maxResolution,
          ),
        );
  }

  /// إلغاء الاشتراك
  Future<void> cancelSubscription(String subscriptionId) async {
    final subscription = await getSubscription(subscriptionId);
    if (subscription == null) return;

    await (database.update(database.subscriptions)
          ..where((tbl) => tbl.subscriptionId.equals(subscriptionId)))
        .write(
          SubscriptionData(
            subscriptionId: subscriptionId,
            userId: subscription.userId,
            tier: subscription.tier,
            status: 'cancelled',
            activatedAt: subscription.activatedAt,
            expiresAt: subscription.expiresAt,
            renewalStatus: 'cancelled',
            features: subscription.features,
            maxProjects: subscription.maxProjects,
            maxExports: subscription.maxExports,
            maxResolution: subscription.maxResolution,
          ),
        );
  }

  /// التحقق من صحة الاشتراك
  Future<bool> isSubscriptionValid(String userId) async {
    final subscription = await getUserSubscription(userId);
    if (subscription == null) return false;

    if (subscription.status != 'active') return false;

    if (subscription.expiresAt != null &&
        subscription.expiresAt!.isBefore(DateTime.now())) {
      return false;
    }

    return true;
  }

  /// الحصول على ميزات الاشتراك
  Future<List<String>> getSubscriptionFeatures(String userId) async {
    final subscription = await getUserSubscription(userId);
    if (subscription == null) return [];

    return subscription.features.split(',');
  }

  /// التحقق من ميزة معينة
  Future<bool> hasFeature(String userId, String feature) async {
    final features = await getSubscriptionFeatures(userId);
    return features.contains(feature);
  }

  /// الحصول على حد الدقة المسموحة
  Future<int> getMaxResolution(String userId) async {
    final subscription = await getUserSubscription(userId);
    return subscription?.maxResolution ?? 720;
  }

  /// الحصول على حد عدد المشاريع
  Future<int> getMaxProjects(String userId) async {
    final subscription = await getUserSubscription(userId);
    return subscription?.maxProjects ?? 1;
  }

  /// الحصول على حد عدد الصادرات الشهرية
  Future<int> getMaxExports(String userId) async {
    final subscription = await getUserSubscription(userId);
    return subscription?.maxExports ?? 1;
  }

  /// تحديث الميزات
  Future<void> updateFeatures(
    String subscriptionId,
    List<String> features,
  ) async {
    final subscription = await getSubscription(subscriptionId);
    if (subscription == null) return;

    await (database.update(database.subscriptions)
          ..where((tbl) => tbl.subscriptionId.equals(subscriptionId)))
        .write(
          SubscriptionData(
            subscriptionId: subscriptionId,
            userId: subscription.userId,
            tier: subscription.tier,
            status: subscription.status,
            activatedAt: subscription.activatedAt,
            expiresAt: subscription.expiresAt,
            renewalStatus: subscription.renewalStatus,
            features: features.join(','),
            maxProjects: subscription.maxProjects,
            maxExports: subscription.maxExports,
            maxResolution: subscription.maxResolution,
          ),
        );
  }

  /// ترقية الطبقة
  Future<void> upgradeTier(
    String subscriptionId,
    String newTier,
    List<String> newFeatures,
    int newMaxProjects,
    int newMaxExports,
    int newMaxResolution,
  ) async {
    final subscription = await getSubscription(subscriptionId);
    if (subscription == null) return;

    await (database.update(database.subscriptions)
          ..where((tbl) => tbl.subscriptionId.equals(subscriptionId)))
        .write(
          SubscriptionData(
            subscriptionId: subscriptionId,
            userId: subscription.userId,
            tier: newTier,
            status: subscription.status,
            activatedAt: subscription.activatedAt,
            expiresAt: subscription.expiresAt,
            renewalStatus: subscription.renewalStatus,
            features: newFeatures.join(','),
            maxProjects: newMaxProjects,
            maxExports: newMaxExports,
            maxResolution: newMaxResolution,
          ),
        );
  }

  /// إحصائيات الاشتراك
  Future<SubscriptionStatistics> getSubscriptionStatistics() async {
    final allSubscriptions = await database.select(database.subscriptions).get();

    int activeCount = 0;
    int expiredCount = 0;
    Map<String, int> tierCounts = {};

    for (final sub in allSubscriptions) {
      if (sub.status == 'active') {
        activeCount++;
      } else if (sub.status != 'cancelled') {
        expiredCount++;
      }

      tierCounts[sub.tier] = (tierCounts[sub.tier] ?? 0) + 1;
    }

    return SubscriptionStatistics(
      totalSubscriptions: allSubscriptions.length,
      activeSubscriptions: activeCount,
      expiredSubscriptions: expiredCount,
      tierCounts: tierCounts,
    );
  }
}

// ====================================================
// نماذج البيانات المساعدة
// ====================================================

class SubscriptionStatistics {
  final int totalSubscriptions;
  final int activeSubscriptions;
  final int expiredSubscriptions;
  final Map<String, int> tierCounts;

  SubscriptionStatistics({
    required this.totalSubscriptions,
    required this.activeSubscriptions,
    required this.expiredSubscriptions,
    required this.tierCounts,
  });

  double get activePercentage =>
      totalSubscriptions == 0
          ? 0.0
          : (activeSubscriptions / totalSubscriptions) * 100;
}
