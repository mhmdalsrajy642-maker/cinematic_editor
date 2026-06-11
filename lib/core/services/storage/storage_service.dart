// lib/core/services/storage/storage_service.dart
// خدمة التخزين الرئيسية - تنسيق جميع عمليات التخزين والاسترجاع والحفظ التلقائي
import 'package:flutter/foundation.dart';
import '../../models/timeline_models.dart';
import 'app_database.dart';
import 'autosave_service.dart';
import 'recovery_service.dart';
import 'repositories/project_repository.dart';

class StorageService {
  late final AppDatabase _database;
  late final ProjectRepository _projectRepository;
  late final AutosaveService _autosaveService;
  late final RecoveryService _recoveryService;

  bool _isInitialized = false;

  // Getters للخدمات
  AppDatabase get database => _database;
  ProjectRepository get projectRepository => _projectRepository;
  AutosaveService get autosaveService => _autosaveService;
  RecoveryService get recoveryService => _recoveryService;

  bool get isInitialized => _isInitialized;

  /// تهيئة خدمة التخزين
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🔧 جاري تهيئة خدمة التخزين...');

      // إنشاء قاعدة البيانات
      _database = AppDatabase();

      // إنشاء المستودعات والخدمات
      _projectRepository = ProjectRepository(database: _database);
      _autosaveService = AutosaveService(
        projectRepository: _projectRepository,
        autosaveInterval: const Duration(seconds: 60),
      );
      _recoveryService = RecoveryService(projectRepository: _projectRepository);

      _isInitialized = true;
      debugPrint('✓ تمت تهيئة خدمة التخزين بنجاح');
    } catch (e) {
      debugPrint('✗ خطأ في تهيئة خدمة التخزين: $e');
      rethrow;
    }
  }

  /// فتح مشروع (تحميل أو استرجاع)
  Future<ProjectOpenResult> openProject(String projectId) async {
    if (!_isInitialized) {
      return ProjectOpenResult.error(
        'خدمة التخزين لم تُهيأ بعد',
      );
    }

    try {
      // التحقق من وجود المشروع
      final project = await _projectRepository.getProject(projectId);
      if (project == null) {
        return ProjectOpenResult.error('المشروع غير موجود');
      }

      // محاولة تحميل أحدث لقطة
      final timelineState =
          await _projectRepository.loadLatestSnapshot(projectId);

      if (timelineState != null) {
        // بدء الحفظ التلقائي
        _autosaveService.startAutosave(projectId);

        return ProjectOpenResult.success(
          projectData: project,
          timelineState: timelineState,
          isRecovered: false,
        );
      } else {
        // لم نتمكن من تحميل لقطة، إرجاع مشروع فارغ
        final emptyState = TimelineState.empty(projectId);
        return ProjectOpenResult.success(
          projectData: project,
          timelineState: emptyState,
          isRecovered: false,
        );
      }
    } catch (e) {
      debugPrint('✗ خطأ في فتح المشروع $projectId: $e');
      return ProjectOpenResult.error('فشل في فتح المشروع: $e');
    }
  }

  /// إنشاء مشروع جديد
  Future<ProjectCreationResult> createNewProject({
    required String name,
    String? description,
    String resolution = '1080p',
    String aspectRatio = '16:9',
    String frameRate = '30',
  }) async {
    if (!_isInitialized) {
      return ProjectCreationResult.error('خدمة التخزين لم تُهيأ بعد');
    }

    try {
      final projectId = await _projectRepository.createNewProject(
        name: name,
        description: description,
        resolution: resolution,
        aspectRatio: aspectRatio,
        frameRate: frameRate,
      );

      final project = await _projectRepository.getProject(projectId);
      if (project != null) {
        // بدء الحفظ التلقائي
        _autosaveService.startAutosave(projectId);

        return ProjectCreationResult.success(projectId);
      }

      return ProjectCreationResult.error('فشل في إنشاء المشروع');
    } catch (e) {
      debugPrint('✗ خطأ في إنشاء مشروع جديد: $e');
      return ProjectCreationResult.error('$e');
    }
  }

  /// حفظ حالة المشروع الحالية
  Future<SaveResult> saveCurrentState(TimelineState state) async {
    if (!_isInitialized) {
      return SaveResult.error('خدمة التخزين لم تُهيأ بعد');
    }

    try {
      _autosaveService.markAsModified(state);

      // حفظ فوري
      final snapshotId = await _projectRepository.saveSnapshot(
        projectId: state.projectId,
        state: state,
        label: 'manual',
      );

      return SaveResult.success(snapshotId);
    } catch (e) {
      debugPrint('✗ خطأ في حفظ حالة المشروع: $e');
      return SaveResult.error('$e');
    }
  }

  /// الحصول على جميع المشاريع
  Future<List<ProjectData>> getAllProjects() async {
    if (!_isInitialized) return [];

    try {
      return await _projectRepository.getAllProjects();
    } catch (e) {
      debugPrint('✗ خطأ في الحصول على المشاريع: $e');
      return [];
    }
  }

  /// إغلاق المشروع الحالي
  Future<void> closeCurrentProject() async {
    try {
      await _autosaveService.performImmediateSave();
      _autosaveService.stopAutosave();
      debugPrint('✓ تم إغلاق المشروع بنجاح');
    } catch (e) {
      debugPrint('✗ خطأ في إغلاق المشروع: $e');
    }
  }

  /// تنظيف الموارد
  Future<void> dispose() async {
    try {
      await closeCurrentProject();
      _autosaveService.dispose();
      await _database.close();
      _isInitialized = false;
      debugPrint('✓ تم تنظيف خدمة التخزين');
    } catch (e) {
      debugPrint('✗ خطأ في تنظيف خدمة التخزين: $e');
    }
  }
}

// ====================================================
// نتائج العمليات
// ====================================================

class ProjectOpenResult {
  final bool success;
  final ProjectData? projectData;
  final TimelineState? timelineState;
  final bool isRecovered;
  final String? errorMessage;

  ProjectOpenResult({
    required this.success,
    this.projectData,
    this.timelineState,
    this.isRecovered = false,
    this.errorMessage,
  });

  factory ProjectOpenResult.success({
    required ProjectData projectData,
    required TimelineState timelineState,
    required bool isRecovered,
  }) {
    return ProjectOpenResult(
      success: true,
      projectData: projectData,
      timelineState: timelineState,
      isRecovered: isRecovered,
    );
  }

  factory ProjectOpenResult.error(String errorMessage) {
    return ProjectOpenResult(
      success: false,
      errorMessage: errorMessage,
    );
  }
}

class ProjectCreationResult {
  final bool success;
  final String? projectId;
  final String? errorMessage;

  ProjectCreationResult({
    required this.success,
    this.projectId,
    this.errorMessage,
  });

  factory ProjectCreationResult.success(String projectId) {
    return ProjectCreationResult(
      success: true,
      projectId: projectId,
    );
  }

  factory ProjectCreationResult.error(String errorMessage) {
    return ProjectCreationResult(
      success: false,
      errorMessage: errorMessage,
    );
  }
}

class SaveResult {
  final bool success;
  final String? snapshotId;
  final String? errorMessage;

  SaveResult({
    required this.success,
    this.snapshotId,
    this.errorMessage,
  });

  factory SaveResult.success(String snapshotId) {
    return SaveResult(
      success: true,
      snapshotId: snapshotId,
    );
  }

  factory SaveResult.error(String errorMessage) {
    return SaveResult(
      success: false,
      errorMessage: errorMessage,
    );
  }
}
