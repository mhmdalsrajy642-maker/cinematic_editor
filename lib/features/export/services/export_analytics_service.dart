import '../models/export_monitoring_models.dart';

/// Service responsible for tracking export analytics and performance metrics.
class ExportAnalyticsService {
  final List<ExportSession> _sessions = [];

  /// Starts tracking a new export session.
  ExportSession startSession({
    required String sessionId,
    required DateTime startedAt,
    required ExportMetrics metrics,
    required ExportPerformance performance,
  }) {
    final session = ExportSession(
      sessionId: sessionId,
      startedAt: startedAt,
      endedAt: null,
      metrics: metrics,
      performance: performance,
      errors: const [],
      completed: false,
    );
    _sessions.add(session);
    return session;
  }

  /// Records a completed export session.
  Future<void> completeSession(String sessionId, {required DateTime endedAt}) async {
    final session = _findSession(sessionId);
    if (session == null) {
      return;
    }
    final updatedSession = session.copyWith(
      endedAt: endedAt,
      completed: true,
    );
    _replaceSession(sessionId, updatedSession);
  }

  /// Records a cancelled export session.
  Future<void> cancelSession(String sessionId, {required DateTime cancelledAt}) async {
    final session = _findSession(sessionId);
    if (session == null) {
      return;
    }
    final updatedSession = session.copyWith(
      endedAt: cancelledAt,
      completed: false,
    );
    _replaceSession(sessionId, updatedSession);
  }

  /// Records a failure for the export session.
  Future<void> recordFailure(String sessionId, ExportError error) async {
    final session = _findSession(sessionId);
    if (session == null) {
      return;
    }
    final updatedSession = session.copyWith(
      errors: [...session.errors, error],
      completed: false,
    );
    _replaceSession(sessionId, updatedSession);
  }

  /// Updates performance data for an active session.
  Future<void> updatePerformance(String sessionId, ExportPerformance performance) async {
    final session = _findSession(sessionId);
    if (session == null) {
      return;
    }
    final updatedSession = session.copyWith(performance: performance);
    _replaceSession(sessionId, updatedSession);
  }

  /// Returns metrics for all recorded sessions.
  List<ExportSession> getAllSessions() {
    return List<ExportSession>.unmodifiable(_sessions);
  }

  /// Finds a specific session by ID.
  ExportSession? getSession(String sessionId) {
    return _findSession(sessionId);
  }

  ExportSession? _findSession(String sessionId) {
    final index = _sessions.indexWhere((session) => session.sessionId == sessionId);
    if (index == -1) {
      return null;
    }
    return _sessions[index];
  }

  void _replaceSession(String sessionId, ExportSession updatedSession) {
    final index = _sessions.indexWhere((session) => session.sessionId == sessionId);
    if (index != -1) {
      _sessions[index] = updatedSession;
    }
  }
}
