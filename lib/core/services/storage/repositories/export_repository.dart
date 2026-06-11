// lib/core/services/storage/repositories/export_repository.dart
// مستودع الصادرات - مسؤول عن إدارة عمليات التصدير
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../app_database.dart';

class ExportRepository {
  final AppDatabase database;

  ExportRepository({required this.database});

  /// إنشاء عملية تصدير جديدة
  Future<String> createExport({
    required String projectId,
    required String exportFormat,
    String? snapshotId,
    String resolution = '1080p',
    String codec = 'h264',
    int fps = 30,
    double bitrate = 5.0,
  }) async {
    final exportId = const Uuid().v4();
    final duration = 0; // سيتم تحديثه لاحقاً

    await database.into(database.exports).insert(
      ExportData(
        exportId: exportId,
        projectId: projectId,
        snapshotId: snapshotId,
        exportFormat: exportFormat,
        status: 'pending',
        resolution: resolution,
        codec: codec,
        fps: fps,
        bitrate: bitrate,
        duration: duration,
      ),
    );

    return exportId;
  }

  /// الحصول على عملية تصدير
  Future<ExportData?> getExport(String exportId) {
    return (database.select(database.exports)
          ..where((tbl) => tbl.exportId.equals(exportId)))
        .getSingleOrNull();
  }

  /// الحصول على جميع الصادرات للمشروع
  Future<List<ExportData>> getProjectExports(
    String projectId, {
    String? statusFilter,
  }) async {
    var query = database.select(database.exports)
      ..where((tbl) => tbl.projectId.equals(projectId));

    if (statusFilter != null) {
      query = query..where((tbl) => tbl.status.equals(statusFilter));
    }

    query = query
      ..orderBy(
        [(tbl) => drift.OrderingTerm(
          expression: tbl.startedAt,
          mode: drift.OrderingMode.desc,
        )],
      );

    return query.get();
  }

  /// تحديث حالة الصادرة
  Future<void> updateExportStatus(
    String exportId,
    String status, {
    String? errorMessage,
    int? fileSize,
  }) async {
    await (database.update(database.exports)
          ..where((tbl) => tbl.exportId.equals(exportId)))
        .write(
          ExportData(
            exportId: exportId,
            projectId: '',
            exportFormat: '',
            status: status,
            errorMessage: errorMessage,
            fileSize: fileSize,
            duration: 0,
            codec: '',
            fps: 0,
            bitrate: 0.0,
          ),
        );
  }

  /// بدء عملية تصدير
  Future<void> startExport(String exportId) async {
    await (database.update(database.exports)
          ..where((tbl) => tbl.exportId.equals(exportId)))
        .write(
          ExportData(
            exportId: exportId,
            projectId: '',
            exportFormat: '',
            status: 'processing',
            startedAt: drift.Value(DateTime.now()),
            duration: 0,
            codec: '',
            fps: 0,
            bitrate: 0.0,
          ),
        );
  }

  /// إكمال عملية تصدير
  Future<void> completeExport(
    String exportId, {
    required String exportPath,
    required int fileSize,
  }) async {
    await (database.update(database.exports)
          ..where((tbl) => tbl.exportId.equals(exportId)))
        .write(
          ExportData(
            exportId: exportId,
            projectId: '',
            exportFormat: '',
            status: 'completed',
            exportPath: drift.Value(exportPath),
            fileSize: drift.Value(fileSize),
            completedAt: drift.Value(DateTime.now()),
            duration: 0,
            codec: '',
            fps: 0,
            bitrate: 0.0,
          ),
        );
  }

  /// فشل عملية تصدير
  Future<void> failExport(
    String exportId, {
    required String errorMessage,
  }) async {
    await (database.update(database.exports)
          ..where((tbl) => tbl.exportId.equals(exportId)))
        .write(
          ExportData(
            exportId: exportId,
            projectId: '',
            exportFormat: '',
            status: 'failed',
            errorMessage: drift.Value(errorMessage),
            completedAt: drift.Value(DateTime.now()),
            duration: 0,
            codec: '',
            fps: 0,
            bitrate: 0.0,
          ),
        );
  }

  /// حذف عملية تصدير
  Future<void> deleteExport(String exportId) async {
    await (database.delete(database.exports)
          ..where((tbl) => tbl.exportId.equals(exportId)))
        .go();
  }

  /// إحصائيات التصدير
  Future<ExportStatistics> getExportStatistics(String projectId) async {
    final exports = await getProjectExports(projectId);

    int completed = 0;
    int failed = 0;
    int pending = 0;
    int totalSize = 0;

    for (final export in exports) {
      switch (export.status) {
        case 'completed':
          completed++;
          totalSize += export.fileSize ?? 0;
          break;
        case 'failed':
          failed++;
          break;
        case 'pending':
        case 'processing':
          pending++;
          break;
      }
    }

    return ExportStatistics(
      totalExports: exports.length,
      completedCount: completed,
      failedCount: failed,
      pendingCount: pending,
      totalExportSize: totalSize,
    );
  }

  /// مسح الصادرات القديمة (أكثر من 30 يوم)
  Future<void> cleanupOldExports(String projectId) async {
    final thirtyDaysAgo =
        DateTime.now().subtract(const Duration(days: 30));

    await (database.delete(database.exports)
          ..where((tbl) =>
              tbl.projectId.equals(projectId) &
              tbl.completedAt.isSmallerThanValue(thirtyDaysAgo) &
              tbl.status.equals('completed')))
        .go();
  }
}

// ====================================================
// نماذج البيانات المساعدة
// ====================================================

class ExportStatistics {
  final int totalExports;
  final int completedCount;
  final int failedCount;
  final int pendingCount;
  final int totalExportSize;

  ExportStatistics({
    required this.totalExports,
    required this.completedCount,
    required this.failedCount,
    required this.pendingCount,
    required this.totalExportSize,
  });

  double get successRate =>
      totalExports == 0 ? 0.0 : (completedCount / totalExports) * 100;

  String get totalExportSizeFormatted {
    if (totalExportSize < 1024) return '$totalExportSize B';
    if (totalExportSize < 1024 * 1024) {
      return '${(totalExportSize / 1024).toStringAsFixed(2)} KB';
    }
    if (totalExportSize < 1024 * 1024 * 1024) {
      return '${(totalExportSize / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(totalExportSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
