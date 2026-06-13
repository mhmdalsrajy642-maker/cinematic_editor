// lib/features/subscription/models/subscription_models.dart

import 'package:equatable/equatable.dart';

enum SubscriptionStatus {
  active,
  paused,
  cancelled,
  expired,
  trial,
}

extension SubscriptionStatusX on SubscriptionStatus {
  String toJson() => name;

  static SubscriptionStatus fromJson(String value) {
    return SubscriptionStatus.values.byName(value);
  }
}

class SubscriptionFeature extends Equatable {
  final String id;
  final String name;
  final String description;
  final bool enabled;

  const SubscriptionFeature({
    required this.id,
    required this.name,
    required this.description,
    this.enabled = true,
  });

  SubscriptionFeature copyWith({
    String? id,
    String? name,
    String? description,
    bool? enabled,
  }) {
    return SubscriptionFeature(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'enabled': enabled,
    };
  }

  factory SubscriptionFeature.fromJson(Map<String, dynamic> json) {
    return SubscriptionFeature(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      enabled: json['enabled'] as bool,
    );
  }

  @override
  List<Object?> get props => [id, name, description, enabled];
}

class SubscriptionPlan extends Equatable {
  final String id;
  final String title;
  final String description;
  final double price;
  final String currency;
  final Duration period;
  final List<SubscriptionFeature> features;

  const SubscriptionPlan({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.currency,
    required this.period,
    this.features = const [],
  });

  SubscriptionPlan copyWith({
    String? id,
    String? title,
    String? description,
    double? price,
    String? currency,
    Duration? period,
    List<SubscriptionFeature>? features,
  }) {
    return SubscriptionPlan(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      period: period ?? this.period,
      features: features ?? this.features,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'currency': currency,
      'periodDays': period.inDays,
      'features': features.map((feature) => feature.toJson()).toList(),
    };
  }

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String,
      period: Duration(days: json['periodDays'] as int),
      features: (json['features'] as List<dynamic>)
          .map((item) => SubscriptionFeature.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [id, title, description, price, currency, period, features];
}

class UserSubscription extends Equatable {
  final String userId;
  final String planId;
  final SubscriptionStatus status;
  final DateTime startedAt;
  final DateTime? expiresAt;
  final bool autoRenew;

  const UserSubscription({
    required this.userId,
    required this.planId,
    required this.status,
    required this.startedAt,
    this.expiresAt,
    this.autoRenew = false,
  });

  UserSubscription copyWith({
    String? userId,
    String? planId,
    SubscriptionStatus? status,
    DateTime? startedAt,
    DateTime? expiresAt,
    bool? autoRenew,
  }) {
    return UserSubscription(
      userId: userId ?? this.userId,
      planId: planId ?? this.planId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      autoRenew: autoRenew ?? this.autoRenew,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'planId': planId,
      'status': status.toJson(),
      'startedAt': startedAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'autoRenew': autoRenew,
    };
  }

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      userId: json['userId'] as String,
      planId: json['planId'] as String,
      status: SubscriptionStatusX.fromJson(json['status'] as String),
      startedAt: DateTime.parse(json['startedAt'] as String),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      autoRenew: json['autoRenew'] as bool,
    );
  }

  @override
  List<Object?> get props => [userId, planId, status, startedAt, expiresAt, autoRenew];
}
