// lib/core/services/storage/autosave_service.dart
// خدمة الحفظ التلقائي - تحفظ TimelineState تلقائياً على فترات زمنية منتظمة
import 'dart:async';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import '../../models/timeline_models.dart';
import 'app_database.dart';
import 'repositories/project_repository.dart';

class AutosaveService {
  final ProjectRepository projectRepository;
  final Duration autosaveInterval;

  String? _currentProjectId;
  Timer? _autosaveTimer;
  TimelineState? _lastSavedState;
  bool _hasUnsavedChanges = false;

  // للإخطار عند إكمال الحفظ
  final _autosaveController = StreamController<AutosaveEvent>.broadcast();
  Stream<AutosaveEvent> get autosaveStream => _autosaveController.stream;

  AutosaveService({
    required this.projectRepository,
    this.autosaveInterval = const Duration(seconds: 60),
  });

  /// بدء الحفظ التلقائي لمشروع
  void startAutosave(String projectId) {
    _currentProjectId = projectId;
    _hasUnsavedChanges = false;

    // إيقاف أي توقيت سابق
    _autosaveTimer?.cancel();

    // إنشاء توقيت جديد
    _autosaveTimer = Timer.periodic(autosaveInterval, (_) async {
      if (_hasUnsavedChanges && _lastSavedState != null) {
        await _performAutosave();
      }
    });
  }

  /// إيقاف الحفظ التلقائي
  void stopAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    _currentProjectId = null;
  }

  /// إخطار الخدمة بحدوث تغيير
  void markAsModified(TimelineState newState) {
    _lastSavedState = newState;
    _hasUnsavedChanges = true;
    _autosaveController.add(AutosaveEvent.modified());
  }

  /// القيام بالحفظ التلقائي الفعلي
  Future<void> _performAutosave() async {
    if (_currentProjectId == null || _lastSavedState == null) return;

    try {
      _autosaveController.add(AutosaveEvent.started());

      final snapshotId = await projectRepository.saveSnapshot(
        projectId: _currentProjectId!,
        state: _lastSavedState!,
        label: 'autosave',
        isPinned: false,
      );

      // تحديث حالة الautosave في قاعدة البيانات
      await _updateAutosaveState(
        projectId: _currentProjectId!,
        snapshotId: snapshotId,
        hasUnsavedChanges: false,
      );

      _hasUnsavedChanges = false;
      _autosaveController.add(AutosaveEvent.completed(snapshotId));

      // تنظيف اللقطات القديمة كل 10 مرات
      if (int.parse(snapshotId.split('-')[0]) % 10 == 0) {
        await projectRepository.cleanupOldSnapshots(_currentProjectId!);
      }
    } catch (e) {
      _autosaveController.add(AutosaveEvent.failed(e.toString()));
    }
  }

  /// حفظ فوري (يُستدعى عند إغلاق التطبيق أو المشروع)
  Future<void> performImmediateSave() async {
    if (_hasUnsavedChanges) {
      await _performAutosave();
    }
  }

  /// تحديث حالة الautosave في قاعدة البيانات
  Future<void> _updateAutosaveState({
    required String projectId,
    required String snapshotId,
    required bool hasUnsavedChanges,
  }) async {
    final database = projectRepository.database;
    await (database.update(database.autosaveStates)
          ..where((tbl) => tbl.projectId.equals(projectId)))
        .write(
          AutosaveStatesCompanion(
            lastAutosaveAt: drift.Value(DateTime.now()),
            lastSnapshotId: drift.Value(snapshotId),
            hasUnsavedChanges: drift.Value(hasUnsavedChanges),
          ),
        );
  }

  /// الحصول على حالة الautosave الحالية
  Future<AutosaveStateData?> getAutosaveState(String projectId) async {
    final database = projectRepository.database;
    return (database.select(database.autosaveStates)
          ..where((tbl) => tbl.projectId.equals(projectId)))
        .getSingleOrNull();
  }

  /// هل هناك تغييرات غير محفوظة؟
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  /// تنظيف الموارد
  void dispose() {
    stopAutosave();
    _autosaveController.close();
  }
}

// ====================================================
// أحداث الحفظ التلقائي
// ====================================================

class AutosaveEvent {
  final AutosaveEventType type;
  final String? snapshotId;
  final String? errorMessage;

  AutosaveEvent({
    required this.type,
    this.snapshotId,
    this.errorMessage,
  });

  factory AutosaveEvent.started() {
    return AutosaveEvent(type: AutosaveEventType.started);
  }

  factory AutosaveEvent.completed(String snapshotId) {
    return AutosaveEvent(
      type: AutosaveEventType.completed,
      snapshotId: snapshotId,
    );
  }

  factory AutosaveEvent.failed(String errorMessage) {
    return AutosaveEvent(
      type: AutosaveEventType.failed,
      errorMessage: errorMessage,
    );
  }

  factory AutosaveEvent.modified() {
    return AutosaveEvent(type: AutosaveEventType.modified);
  }
}

enum AutosaveEventType {
  started,
  completed,
  failed,
  modified,
}
