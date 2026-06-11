// lib/core/services/storage/recovery_service.dart
// خدمة الاسترجاع - تستعيد المشاريع بعد تعطل التطبيق
import 'package:flutter/foundation.dart';
import '../../models/timeline_models.dart';
import 'repositories/project_repository.dart';

class RecoveryService {
  final ProjectRepository projectRepository;

  RecoveryService({required this.projectRepository});

  /// استعادة المشروع - تحميل آخر لقطة محفوظة
  Future<TimelineState?> recoverProject(String projectId) async {
    try {
      final state = await projectRepository.loadLatestSnapshot(projectId);
      if (state != null) {
        debugPrint('✓ تم استرجاع المشروع $projectId بنجاح');
        return state;
      }
    } catch (e) {
      debugPrint('✗ خطأ في استعادة المشروع $projectId: $e');
    }
    return null;
  }

  /// الحصول على قائمة المشاريع القابلة للاسترجاع
  /// (تلك التي تحتوي على لقطات)
  Future<List<RecoverableProject>> getRecoverableProjects() async {
    final projects = await projectRepository.getAllProjects();
    final recoverableProjects = <RecoverableProject>[];

    for (final project in projects) {
      final snapshots =
          await projectRepository.getAllSnapshots(project.projectId);

      if (snapshots.isNotEmpty) {
        final latestSnapshot = snapshots.first;
        recoverableProjects.add(
          RecoverableProject(
            projectId: project.projectId,
            projectName: project.name,
            lastSnapshot: latestSnapshot.createdAt,
            snapshotCount: snapshots.length,
            snapshotVersion: latestSnapshot.version,
          ),
        );
      }
    }

    return recoverableProjects;
  }

  /// استرجاع نسخة قديمة من المشروع (بناءً على version)
  Future<TimelineState?> recoverProjectVersion(
    String projectId,
    int version,
  ) async {
    try {
      final snapshots =
          await projectRepository.getAllSnapshots(projectId);
      final snapshotInfo = snapshots
          .firstWhere((s) => s.version == version, orElse: () => null as dynamic)
          as SnapshotInfo?;

      if (snapshotInfo != null) {
        return await projectRepository.loadSnapshot(snapshotInfo.snapshotId);
      }
    } catch (e) {
      debugPrint('✗ خطأ في استعادة نسخة المشروع $projectId v$version: $e');
    }
    return null;
  }

  /// الحصول على تاريخ اللقطات للمشروع
  Future<List<SnapshotHistory>> getProjectSnapshotHistory(
    String projectId,
  ) async {
    final snapshots =
        await projectRepository.getAllSnapshots(projectId);

    return snapshots
        .map((s) => SnapshotHistory(
              snapshotId: s.snapshotId,
              version: s.version,
              createdAt: s.createdAt,
              fileSize: s.fileSize,
              label: s.labels.isEmpty ? 'تعديل يدوي' : s.labels.first,
              isPinned: s.isPinned,
              isAutosave: s.isAutosave,
            ))
        .toList();
  }

  /// حذف جميع لقطات المشروع عدا الأخيرة (للتنظيف)
  Future<void> cleanupOldSnapshots(
    String projectId, {
    int keepCount = 50,
  }) async {
    await projectRepository.cleanupOldSnapshots(
      projectId,
      keepCount: keepCount,
    );
  }

  /// التحقق من سلامة اللقطة
  Future<bool> verifySnapshot(String snapshotId) async {
    final database = projectRepository.database;
    final snapshot = await (database.select(database.timelineSnapshots)
          ..where((tbl) => tbl.snapshotId.equals(snapshotId)))
        .getSingleOrNull();

    if (snapshot == null) return false;

    return projectRepository.verifySnapshot(snapshot);
  }

  /// الحصول على معلومات الاسترجاع
  Future<RecoveryInfo> getRecoveryInfo() async {
    final projects = await projectRepository.getAllProjects();
    var totalSnapshots = 0;
    var totalSize = 0;

    for (final project in projects) {
      final snapshots =
          await projectRepository.getAllSnapshots(project.projectId);
      totalSnapshots += snapshots.length;
      totalSize += snapshots.fold<int>(0, (sum, s) => sum + s.fileSize);
    }

    return RecoveryInfo(
      projectsCount: projects.length,
      totalSnapshots: totalSnapshots,
      totalSize: totalSize,
    );
  }
}

// ====================================================
// نماذج البيانات المساعدة
// ====================================================

class RecoverableProject {
  final String projectId;
  final String projectName;
  final DateTime lastSnapshot;
  final int snapshotCount;
  final int snapshotVersion;

  RecoverableProject({
    required this.projectId,
    required this.projectName,
    required this.lastSnapshot,
    required this.snapshotCount,
    required this.snapshotVersion,
  });

  String get lastSnapshotFormatted {
    final difference = DateTime.now().difference(lastSnapshot);
    if (difference.inSeconds < 60) {
      return 'منذ قليل';
    } else if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    } else {
      return 'منذ ${difference.inDays} يوم';
    }
  }
}

class SnapshotHistory {
  final String snapshotId;
  final int version;
  final DateTime createdAt;
  final int fileSize;
  final String label;
  final bool isPinned;
  final bool isAutosave;

  SnapshotHistory({
    required this.snapshotId,
    required this.version,
    required this.createdAt,
    required this.fileSize,
    required this.label,
    required this.isPinned,
    required this.isAutosave,
  });

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(2)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class RecoveryInfo {
  final int projectsCount;
  final int totalSnapshots;
  final int totalSize;

  RecoveryInfo({
    required this.projectsCount,
    required this.totalSnapshots,
    required this.totalSize,
  });

  String get totalSizeFormatted {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(2)} KB';
    }
    if (totalSize < 1024 * 1024 * 1024) {
      return '${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
