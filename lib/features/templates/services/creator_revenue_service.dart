import '../models/creator_revenue_models.dart';

/// Service responsible for calculating creator revenue, generating reports,
/// and handling payout requests.
class CreatorRevenueService {
  final List<RevenueTransaction> _transactions;
  final List<PayoutRequest> _payoutRequests;

  CreatorRevenueService({
    List<RevenueTransaction>? transactions,
    List<PayoutRequest>? payoutRequests,
  })  : _transactions = transactions ?? const [],
        _payoutRequests = payoutRequests ?? const [];

  /// Calculates total, pending, and settled revenue for a creator.
  Future<RevenueReport> calculateRevenue({
    required String creatorId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 30));

    final periodTransactions = _transactions.where((transaction) {
      return transaction.creatorId == creatorId &&
          !transaction.createdAt.isBefore(periodStart) &&
          !transaction.createdAt.isAfter(periodEnd);
    }).toList(growable: false);

    final totalRevenue = periodTransactions.fold<double>(0.0, (sum, transaction) => sum + transaction.amount);
    final settledRevenue = periodTransactions
        .where((transaction) => transaction.isSettled)
        .fold<double>(0.0, (sum, transaction) => sum + transaction.amount);
    final pendingRevenue = totalRevenue - settledRevenue;

    return RevenueReport(
      creatorId: creatorId,
      periodStart: periodStart,
      periodEnd: periodEnd,
      totalRevenue: totalRevenue,
      pendingRevenue: pendingRevenue,
      settledRevenue: settledRevenue,
      transactionCount: periodTransactions.length,
    );
  }

  /// Generates a revenue report for the creator based on current transaction data.
  Future<RevenueReport> generateReport({
    required CreatorAccount creatorAccount,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    return calculateRevenue(
      creatorId: creatorAccount.creatorId,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
  }

  /// Creates a payout request for the creator.
  Future<PayoutRequest> requestPayout({
    required String requestId,
    required String creatorId,
    required double amount,
    required String currency,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 30));

    final request = PayoutRequest(
      id: requestId,
      creatorId: creatorId,
      amount: amount,
      currency: currency,
      requestedAt: DateTime.now(),
      processedAt: null,
      status: 'pending',
    );

    _payoutRequests.add(request);
    return request;
  }

  /// Returns all payout requests for the given creator.
  List<PayoutRequest> getPayoutRequests(String creatorId) {
    return _payoutRequests.where((request) => request.creatorId == creatorId).toList(growable: false);
  }
}
