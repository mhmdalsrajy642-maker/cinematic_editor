// lib/core/services/storage/app_database.dart
// قاعدة البيانات الرئيسية باستخدام Drift
// تخزن جميع حالات المشروع والأصول والعمليات
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../models/timeline_models.dart';

part 'app_database.g.dart';

// ====================================================
// جدول المشاريع
// ====================================================
@DataClassName('ProjectData')
class Projects extends Table {
  TextColumn get projectId => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get thumbnailPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get resolution => text().withDefault(const Constant('1080p'))();
  TextColumn get aspectRatio => text().withDefault(const Constant('16:9'))();
  TextColumn get frameRate => text().withDefault(const Constant('30'))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {projectId};
}

// ====================================================
// جدول الأصول (Assets) - الفيديوهات والصور والصوتيات
// ====================================================
@DataClassName('AssetData')
class Assets extends Table {
  TextColumn get assetId => text()();
  TextColumn get projectId => text()();
  TextColumn get name => text()();
  TextColumn get assetType => text()(); // 'video', 'image', 'audio', 'font'
  TextColumn get originalPath => text()();
  TextColumn get proxyPath => text().nullable()(); // النسخة المضغوطة
  TextColumn get thumbnailPath => text().nullable()();
  IntColumn get fileSize => integer()(); // بالبايت
  RealColumn get duration => real().nullable()(); // للفيديو والصوت
  IntColumn get width => integer().nullable()(); // للصور والفيديو
  IntColumn get height => integer().nullable()();
  DateTimeColumn get uploadedAt => dateTime()();
  TextColumn get metadata => text().nullable()(); // JSON للبيانات الإضافية

  @override
  Set<Column> get primaryKey => {assetId};
  @override
  List<Set<Column>> get uniqueKeys => [
    {projectId, originalPath}
  ];
}

// ====================================================
// جدول لقطات التايم لاين (Snapshots)
// تخزن كل حالة من حالات المشروع لدعم الاسترجاع
// ====================================================
@DataClassName('TimelineSnapshotData')
class TimelineSnapshots extends Table {
  TextColumn get snapshotId => text()();
  TextColumn get projectId => text()();
  IntColumn get version => integer()(); // رقم النسخة للترتيب
  TextColumn get snapshotJson => text()(); // TimelineState كـ JSON مضغوط
  IntColumn get fileSize => integer()(); // حجم JSON بالبايت
  TextColumn get checksumHash => text()(); // SHA256 للتحقق من السلامة
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastAccessedAt => dateTime()();
  TextColumn get labels => text().nullable()(); // "autosave,backup,manual" مفصول بفاصلة
  BoolColumn get isAutosave => boolean().withDefault(const Constant(true))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))(); // محفوظة لا تُحذف

  @override
  Set<Column> get primaryKey => {snapshotId};
  @override
  List<Set<Column>> get uniqueKeys => [
    {projectId, version}
  ];
}

// ====================================================
// جدول الصادرات (Exports)
// ====================================================
@DataClassName('ExportData')
class Exports extends Table {
  TextColumn get exportId => text()();
  TextColumn get projectId => text()();
  TextColumn get snapshotId => text().nullable()(); // اللقطة المصدرة
  TextColumn get exportFormat => text()(); // 'mp4', 'mov', 'webm'
  TextColumn get exportPath => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // 'pending', 'processing', 'completed', 'failed'
  IntColumn get fileSize => integer().nullable()(); // بالبايت
  IntColumn get duration => integer()(); // بالثانية
  TextColumn get resolution => text()(); // '1080p', '4K'
  TextColumn get codec => text()(); // 'h264', 'h265', 'vp9'
  RealColumn get bitrate => real()(); // Mbps
  IntColumn get fps => integer()(); // frames per second
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {exportId};
}

// ====================================================
// جدول الاشتراكات (Subscriptions)
// ====================================================
@DataClassName('SubscriptionData')
class Subscriptions extends Table {
  TextColumn get subscriptionId => text()();
  TextColumn get userId => text()();
  TextColumn get tier => text()(); // 'free', 'pro', 'premium'
  TextColumn get status => text().withDefault(const Constant('active'))(); // 'active', 'expired', 'cancelled'
  DateTimeColumn get activatedAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime().nullable()();
  TextColumn get renewalStatus => text().withDefault(const Constant('auto'))(); // 'auto', 'manual', 'cancelled'
  TextColumn get features => text()(); // JSON قائمة الميزات المفعلة
  IntColumn get maxProjects => integer().withDefault(const Constant(3))();
  IntColumn get maxExports => integer().withDefault(const Constant(5))();
  IntColumn get maxResolution => integer().withDefault(const Constant(1080))();

  @override
  Set<Column> get primaryKey => {subscriptionId};
}

// ====================================================
// جدول تتبع الحالة التلقائية (Autosave State)
// ====================================================
@DataClassName('AutosaveStateData')
class AutosaveStates extends Table {
  TextColumn get projectId => text()();
  DateTimeColumn get lastAutosaveAt => dateTime()();
  TextColumn get lastSnapshotId => text().nullable()();
  BoolColumn get hasUnsavedChanges => boolean().withDefault(const Constant(false))();
  IntColumn get autoSaveIntervalSeconds => integer().withDefault(const Constant(60))();

  @override
  Set<Column> get primaryKey => {projectId};
}

// ====================================================
// تعريف قاعدة البيانات
// ====================================================
@DriftDatabase(
  tables: [
    Projects,
    Assets,
    TimelineSnapshots,
    Exports,
    Subscriptions,
    AutosaveStates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // معالجة الترقيات المستقبلية
      },
    );
  }

  // ====================================================
  // طرق مساعدة للتشغيل السلس
  // ====================================================
  
  /// إنشاء مشروع جديد
  Future<void> createProject({
    required String projectId,
    required String name,
    String? description,
    String resolution = '1080p',
    String aspectRatio = '16:9',
    String frameRate = '30',
  }) async {
    await into(projects).insert(
      ProjectsCompanion(
        projectId: Value(projectId),
        name: Value(name),
        description: Value(description),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        resolution: Value(resolution),
        aspectRatio: Value(aspectRatio),
        frameRate: Value(frameRate),
      ),
    );

    // إنشاء حالة autosave أولية
    await into(autosaveStates).insert(
      AutosaveStatesCompanion(
        projectId: Value(projectId),
        lastAutosaveAt: Value(DateTime.now()),
        hasUnsavedChanges: Value(false),
      ),
    );
  }

  /// الحصول على مشروع بواسطة ID
  Future<ProjectData?> getProject(String projectId) {
    return (select(projects)..where((tbl) => tbl.projectId.equals(projectId)))
        .getSingleOrNull();
  }

  /// الحصول على جميع المشاريع (مرتبة حسب آخر تحديث)
  Future<List<ProjectData>> getAllProjects() {
    return (select(projects)
          ..orderBy(
            [(tbl) => OrderingTerm(expression: tbl.updatedAt, mode: OrderingMode.desc)],
          ))
        .get();
  }

  /// حذف مشروع وجميع بيانات الأصول والعمليات
  Future<void> deleteProject(String projectId) async {
    await transaction(() async {
      await (delete(projects)..where((tbl) => tbl.projectId.equals(projectId))).go();
      await (delete(assets)..where((tbl) => tbl.projectId.equals(projectId))).go();
      await (delete(timelineSnapshots)
            ..where((tbl) => tbl.projectId.equals(projectId)))
          .go();
      await (delete(exports)..where((tbl) => tbl.projectId.equals(projectId))).go();
      await (delete(autosaveStates)..where((tbl) => tbl.projectId.equals(projectId))).go();
    });
  }
}

// ====================================================
// فتح الاتصال بقاعدة البيانات
// ====================================================
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'cinematic_db.sqlite'));
    
    if (Platform.isAndroid) {
      // استخدام sqlite3_flutter_libs على Android
      return NativeDatabase(file, setup: (rawDb) {
        rawDb.execute('PRAGMA journal_mode=WAL');
        rawDb.execute('PRAGMA foreign_keys=ON');
        rawDb.execute('PRAGMA synchronous=NORMAL');
      });
    } else if (Platform.isIOS || Platform.isMacOS) {
      return NativeDatabase(file, setup: (rawDb) {
        rawDb.execute('PRAGMA journal_mode=WAL');
        rawDb.execute('PRAGMA foreign_keys=ON');
        rawDb.execute('PRAGMA synchronous=NORMAL');
      });
    } else {
      return NativeDatabase(file, setup: (rawDb) {
        rawDb.execute('PRAGMA journal_mode=WAL');
        rawDb.execute('PRAGMA foreign_keys=ON');
        rawDb.execute('PRAGMA synchronous=NORMAL');
      });
    }
  });
}
