// lib/features/templates/models/creator_revenue_models.dart

import 'package:equatable/equatable.dart';

class CreatorAccount extends Equatable {
  final String id;
  final String creatorId;
  final String displayName;
  final String email;
  final double balance;
  final String currency;

  const CreatorAccount({
    required this.id,
    required this.creatorId,
    required this.displayName,
    required this.email,
    required this.balance,
    required this.currency,
  });

  CreatorAccount copyWith({
    String? id,
    String? creatorId,
    String? displayName,
    String? email,
    double? balance,
    String? currency,
  }) {
    return CreatorAccount(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'creatorId': creatorId,
      'displayName': displayName,
      'email': email,
      'balance': balance,
      'currency': currency,
    };
  }

  factory CreatorAccount.fromJson(Map<String, dynamic> json) {
    return CreatorAccount(
      id: json['id'] as String,
      creatorId: json['creatorId'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String,
      balance: (json['balance'] as num).toDouble(),
      currency: json['currency'] as String,
    );
  }

  @override
  List<Object?> get props => [id, creatorId, displayName, email, balance, currency];
}

class RevenueTransaction extends Equatable {
  final String id;
  final String creatorId;
  final String templateId;
  final DateTime createdAt;
  final double amount;
  final String currency;
  final String description;
  final bool isSettled;

  const RevenueTransaction({
    required this.id,
    required this.creatorId,
    required this.templateId,
    required this.createdAt,
    required this.amount,
    required this.currency,
    required this.description,
    this.isSettled = false,
  });

  RevenueTransaction copyWith({
    String? id,
    String? creatorId,
    String? templateId,
    DateTime? createdAt,
    double? amount,
    String? currency,
    String? description,
    bool? isSettled,
  }) {
    return RevenueTransaction(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      templateId: templateId ?? this.templateId,
      createdAt: createdAt ?? this.createdAt,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      description: description ?? this.description,
      isSettled: isSettled ?? this.isSettled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'creatorId': creatorId,
      'templateId': templateId,
      'createdAt': createdAt.toIso8601String(),
      'amount': amount,
      'currency': currency,
      'description': description,
      'isSettled': isSettled,
    };
  }

  factory RevenueTransaction.fromJson(Map<String, dynamic> json) {
    return RevenueTransaction(
      id: json['id'] as String,
      creatorId: json['creatorId'] as String,
      templateId: json['templateId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      description: json['description'] as String,
      isSettled: json['isSettled'] as bool,
    );
  }

  @override
  List<Object?> get props => [id, creatorId, templateId, createdAt, amount, currency, description, isSettled];
}

class RevenueReport extends Equatable {
  final String creatorId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double totalRevenue;
  final double pendingRevenue;
  final double settledRevenue;
  final int transactionCount;

  const RevenueReport({
    required this.creatorId,
    required this.periodStart,
    required this.periodEnd,
    required this.totalRevenue,
    required this.pendingRevenue,
    required this.settledRevenue,
    required this.transactionCount,
  });

  RevenueReport copyWith({
    String? creatorId,
    DateTime? periodStart,
    DateTime? periodEnd,
    double? totalRevenue,
    double? pendingRevenue,
    double? settledRevenue,
    int? transactionCount,
  }) {
    return RevenueReport(
      creatorId: creatorId ?? this.creatorId,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      pendingRevenue: pendingRevenue ?? this.pendingRevenue,
      settledRevenue: settledRevenue ?? this.settledRevenue,
      transactionCount: transactionCount ?? this.transactionCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'creatorId': creatorId,
      'periodStart': periodStart.toIso8601String(),
      'periodEnd': periodEnd.toIso8601String(),
      'totalRevenue': totalRevenue,
      'pendingRevenue': pendingRevenue,
      'settledRevenue': settledRevenue,
      'transactionCount': transactionCount,
    };
  }

  factory RevenueReport.fromJson(Map<String, dynamic> json) {
    return RevenueReport(
      creatorId: json['creatorId'] as String,
      periodStart: DateTime.parse(json['periodStart'] as String),
      periodEnd: DateTime.parse(json['periodEnd'] as String),
      totalRevenue: (json['totalRevenue'] as num).toDouble(),
      pendingRevenue: (json['pendingRevenue'] as num).toDouble(),
      settledRevenue: (json['settledRevenue'] as num).toDouble(),
      transactionCount: json['transactionCount'] as int,
    );
  }

  @override
  List<Object?> get props => [creatorId, periodStart, periodEnd, totalRevenue, pendingRevenue, settledRevenue, transactionCount];
}

class PayoutRequest extends Equatable {
  final String id;
  final String creatorId;
  final double amount;
  final String currency;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String status;

  const PayoutRequest({
    required this.id,
    required this.creatorId,
    required this.amount,
    required this.currency,
    required this.requestedAt,
    this.processedAt,
    required this.status,
  });

  PayoutRequest copyWith({
    String? id,
    String? creatorId,
    double? amount,
    String? currency,
    DateTime? requestedAt,
    DateTime? processedAt,
    String? status,
  }) {
    return PayoutRequest(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      requestedAt: requestedAt ?? this.requestedAt,
      processedAt: processedAt ?? this.processedAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'creatorId': creatorId,
      'amount': amount,
      'currency': currency,
      'requestedAt': requestedAt.toIso8601String(),
      'processedAt': processedAt?.toIso8601String(),
      'status': status,
    };
  }

  factory PayoutRequest.fromJson(Map<String, dynamic> json) {
    return PayoutRequest(
      id: json['id'] as String,
      creatorId: json['creatorId'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      requestedAt: DateTime.parse(json['requestedAt'] as String),
      processedAt: json['processedAt'] == null
          ? null
          : DateTime.parse(json['processedAt'] as String),
      status: json['status'] as String,
    );
  }

  @override
  List<Object?> get props => [id, creatorId, amount, currency, requestedAt, processedAt, status];
}
