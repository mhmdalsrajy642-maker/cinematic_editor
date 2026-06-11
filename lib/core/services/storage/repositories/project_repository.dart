// lib/core/services/storage/repositories/project_repository.dart
// مستودع المشاريع - مسؤول عن حفظ وتحميل بيانات المشروع
import 'dart:convert';
import 'dart:crypto';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../../../models/timeline_models.dart';
import '../app_database.dart';

class ProjectRepository {
  final AppDatabase database;

  ProjectRepository({required this.database});

  /// إنشاء مشروع جديد
  Future<String> createNewProject({
    required String name,
    String? description,
    String resolution = '1080p',
    String aspectRatio = '16:9',
    String frameRate = '30',
  }) async {
    final projectId = const Uuid().v4();

    await database.createProject(
      projectId: projectId,
      name: name,
      description: description,
      resolution: resolution,
      aspectRatio: aspectRatio,
      frameRate: frameRate,
    );

    // إنشاء لقطة أولية فارغة
    final initialState = TimelineState.empty(projectId);
    await saveSnapshot(
      projectId: projectId,
      state: initialState,
      label: 'initial',
      isPinned: true,
    );

    return projectId;
  }

  /// الحصول على مشروع
  Future<ProjectData?> getProject(String projectId) {
    return database.getProject(projectId);
  }

  /// الحصول على جميع المشاريع
  Future<List<ProjectData>> getAllProjects() {
    return database.getAllProjects();
  }

  /// تحديث معلومات المشروع
  Future<void> updateProject({
    required String projectId,
    String? name,
    String? description,
  }) async {
    final project = await database.getProject(projectId);
    if (project == null) return;

    await (database.update(database.projects)
          ..where((tbl) => tbl.projectId.equals(projectId)))
        .write(
          ProjectsCompanion(
            name: name != null ? drift.Value(name) : drift.Value(project.name),
            description: description != null
                ? drift.Value(description)
                : drift.Value(project.description),
            updatedAt: drift.Value(DateTime.now()),
          ),
        );
  }

  /// حذف مشروع
  Future<void> deleteProject(String projectId) async {
    await database.deleteProject(projectId);
  }

  /// الحصول على إحصائيات المشروع
  Future<ProjectStatistics> getProjectStatistics(String projectId) async {
    final snapshotsCount = await (database.select(database.timelineSnapshots)
          ..where((tbl) => tbl.projectId.equals(projectId)))
        .get()
        .then((list) => list.length);

    final assetsCount = await (database.select(database.assets)
          ..where((tbl) => tbl.projectId.equals(projectId)))
        .get()
        .then((list) => list.length);

    final exportsCount = await (database.select(database.exports)
          ..where((tbl) => tbl.projectId.equals(projectId)))
        .get()
        .then((list) => list.length);

    final totalAssetSize = await (database.select(database.assets)
          ..where((tbl) => tbl.projectId.equals(projectId)))
        .get()
        .then((list) => list.fold<int>(0, (sum, asset) => sum + asset.fileSize));

    return ProjectStatistics(
      snapshotsCount: snapshotsCount,
      assetsCount: assetsCount,
      exportsCount: exportsCount,
      totalAssetSize: totalAssetSize,
    );
  }

  /// حفظ لقطة جديدة من TimelineState
  Future<String> saveSnapshot({
    required String projectId,
    required TimelineState state,
    String? label,
    bool isPinned = false,
  }) async {
    final snapshotId = const Uuid().v4();
    final jsonString = jsonEncode(state.toJson());
    final checksumHash = _calculateChecksum(jsonString);

    // الحصول على آخر version
    final lastVersion = await (database.select(database.timelineSnapshots)
          ..where((tbl) => tbl.projectId.equals(projectId))
          ..orderBy([(tbl) => drift.OrderingTerm(
                expression: tbl.version,
                mode: drift.OrderingMode.desc,
              )]))
        .getSingleOrNull();

    final version = (lastVersion?.version ?? 0) + 1;

    await database.into(database.timelineSnapshots).insert(
      TimelineSnapshotData(
        snapshotId: snapshotId,
        projectId: projectId,
        version: version,
        snapshotJson: jsonString,
        fileSize: jsonString.length,
        checksumHash: checksumHash,
        createdAt: DateTime.now(),
        lastAccessedAt: DateTime.now(),
        labels: label,
        isAutosave: label == 'autosave',
        isPinned: isPinned,
      ),
    );

    return snapshotId;
  }

  /// تحميل أحدث لقطة
  Future<TimelineState?> loadLatestSnapshot(String projectId) async {
    final snapshot = await (database.select(database.timelineSnapshots)
          ..where((tbl) => tbl.projectId.equals(projectId))
          ..orderBy([(tbl) => drift.OrderingTerm(
                expression: tbl.version,
                mode: drift.OrderingMode.desc,
              )])
          ..limit(1))
        .getSingleOrNull();

    if (snapshot == null) return null;

    // تحديث lastAccessedAt
    await (database.update(database.timelineSnapshots)
          ..where((tbl) => tbl.snapshotId.equals(snapshot.snapshotId)))
        .write(
          TimelineSnapshotData(
            snapshotId: snapshot.snapshotId,
            projectId: snapshot.projectId,
            version: snapshot.version,
            snapshotJson: snapshot.snapshotJson,
            fileSize: snapshot.fileSize,
            checksumHash: snapshot.checksumHash,
            createdAt: snapshot.createdAt,
            lastAccessedAt: DateTime.now(),
            labels: snapshot.labels,
            isAutosave: snapshot.isAutosave,
            isPinned: snapshot.isPinned,
          ),
        );

    try {
      final jsonMap = jsonDecode(snapshot.snapshotJson) as Map<String, dynamic>;
      return TimelineState.fromJson(jsonMap);
    } catch (e) {
      return null;
    }
  }

  /// تحميل لقطة محددة بواسطة ID
  Future<TimelineState?> loadSnapshot(String snapshotId) async {
    final snapshot = await (database.select(database.timelineSnapshots)
          ..where((tbl) => tbl.snapshotId.equals(snapshotId)))
        .getSingleOrNull();

    if (snapshot == null) return null;

    try {
      final jsonMap = jsonDecode(snapshot.snapshotJson) as Map<String, dynamic>;
      return TimelineState.fromJson(jsonMap);
    } catch (e) {
      return null;
    }
  }

  /// الحصول على جميع اللقطات للمشروع
  Future<List<SnapshotInfo>> getAllSnapshots(String projectId) async {
    final snapshots = await (database.select(database.timelineSnapshots)
          ..where((tbl) => tbl.projectId.equals(projectId))
          ..orderBy([(tbl) => drift.OrderingTerm(
                expression: tbl.version,
                mode: drift.OrderingMode.desc,
              )]))
        .get();

    return snapshots
        .map((s) => SnapshotInfo(
              snapshotId: s.snapshotId,
              version: s.version,
              createdAt: s.createdAt,
              fileSize: s.fileSize,
              labels: s.labels?.split(',') ?? [],
              isPinned: s.isPinned,
              isAutosave: s.isAutosave,
            ))
        .toList();
  }

  /// حذف لقطات قديمة (عدا المثبتة)
  Future<void> cleanupOldSnapshots(
    String projectId, {
    int keepCount = 50,
  }) async {
    final snapshots = await (database.select(database.timelineSnapshots)
          ..where((tbl) => tbl.projectId.equals(projectId))
          ..where((tbl) => tbl.isPinned.equals(false))
          ..orderBy([(tbl) => drift.OrderingTerm(
                expression: tbl.version,
                mode: drift.OrderingMode.desc,
              )]))
        .get();

    if (snapshots.length > keepCount) {
      final toDelete = snapshots.sublist(keepCount);
      for (final snapshot in toDelete) {
        await (database.delete(database.timelineSnapshots)
              ..where((tbl) => tbl.snapshotId.equals(snapshot.snapshotId)))
            .go();
      }
    }
  }

  /// حفظ الأصول (الملفات المرفقة)
  Future<String> saveAsset({
    required String projectId,
    required String name,
    required String assetType,
    required String originalPath,
    String? proxyPath,
    String? thumbnailPath,
    required int fileSize,
    double? duration,
    int? width,
    int? height,
    String? metadata,
  }) async {
    final assetId = const Uuid().v4();

    await database.into(database.assets).insert(
      AssetData(
        assetId: assetId,
        projectId: projectId,
        name: name,
        assetType: assetType,
        originalPath: originalPath,
        proxyPath: proxyPath,
        thumbnailPath: thumbnailPath,
        fileSize: fileSize,
        duration: duration,
        width: width,
        height: height,
        uploadedAt: DateTime.now(),
        metadata: metadata,
      ),
    );

    return assetId;
  }

  /// الحصول على جميع الأصول للمشروع
  Future<List<AssetData>> getProjectAssets(String projectId) {
    return (database.select(database.assets)
          ..where((tbl) => tbl.projectId.equals(projectId)))
        .get();
  }

  /// حذف أصل
  Future<void> deleteAsset(String assetId) async {
    await (database.delete(database.assets)
          ..where((tbl) => tbl.assetId.equals(assetId)))
        .go();
  }

  // ====================================================
  // الدوال المساعدة
  // ====================================================

  /// حساب Checksum للتحقق من السلامة
  String _calculateChecksum(String data) {
    return sha256.convert(utf8.encode(data)).toString();
  }

  /// التحقق من تكامل اللقطة
  bool verifySnapshot(TimelineSnapshotData snapshot) {
    final calculatedHash = _calculateChecksum(snapshot.snapshotJson);
    return calculatedHash == snapshot.checksumHash;
  }
}

// ====================================================
// نماذج البيانات المساعدة
// ====================================================

class ProjectStatistics {
  final int snapshotsCount;
  final int assetsCount;
  final int exportsCount;
  final int totalAssetSize;

  ProjectStatistics({
    required this.snapshotsCount,
    required this.assetsCount,
    required this.exportsCount,
    required this.totalAssetSize,
  });

  String get totalAssetSizeFormatted {
    if (totalAssetSize < 1024) return '$totalAssetSize B';
    if (totalAssetSize < 1024 * 1024) return '${(totalAssetSize / 1024).toStringAsFixed(2)} KB';
    if (totalAssetSize < 1024 * 1024 * 1024) {
      return '${(totalAssetSize / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(totalAssetSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class SnapshotInfo {
  final String snapshotId;
  final int version;
  final DateTime createdAt;
  final int fileSize;
  final List<String> labels;
  final bool isPinned;
  final bool isAutosave;

  SnapshotInfo({
    required this.snapshotId,
    required this.version,
    required this.createdAt,
    required this.fileSize,
    required this.labels,
    required this.isPinned,
    required this.isAutosave,
  });
}
