// lib/core/services/storage/QUICK_START.md
# ⚡ دليل البدء السريع

## في 5 دقائق

### 1️⃣ توليد قاعدة البيانات

```bash
flutter pub run build_runner build
```

### 2️⃣ تهيئة في main.dart

```dart
import 'package:cinematic_editor/core/services/storage/storage.dart';
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final storageService = StorageService();
  await storageService.initialize();
  getIt.registerSingleton<StorageService>(storageService);
  
  runApp(const CinematicEditorApp());
}
```

### 3️⃣ إنشاء مشروع جديد

```dart
final storageService = getIt<StorageService>();

final result = await storageService.createNewProject(
  name: 'مشروعي الأول',
);

if (result.success) {
  print('✓ تم الإنشاء: ${result.projectId}');
}
```

### 4️⃣ حفظ حالة المشروع

```dart
// يحدث تلقائياً كل 60 ثانية، أو حفظ فوري:
await storageService.saveCurrentState(timelineState);
```

### 5️⃣ فتح المشروع (مع استرجاع)

```dart
final result = await storageService.openProject(projectId);

if (result.success) {
  final state = result.timelineState;
  print('✓ تم الفتح');
}
```

---

## الأوامر السريعة

```dart
// الحصول على الخدمة
final storage = getIt<StorageService>();

// إنشاء
await storage.createNewProject(name: 'اسم المشروع');

// فتح
await storage.openProject(projectId);

// حفظ
await storage.saveCurrentState(state);

// إغلاق
await storage.closeCurrentProject();

// استعادة
await storage.recoveryService.recoverProject(projectId);

// الإحصائيات
await storage.projectRepository.getProjectStatistics(projectId);

// تنظيف
await storage.projectRepository.cleanupOldSnapshots(projectId);

// الاسترجاع الآمن
await storage.dispose();
```

---

## الحفظ التلقائي

### في EditorBloc

```dart
// عند تعديل
on<TimelineModifiedEvent>((event, emit) {
  getIt<AutosaveService>().markAsModified(event.newState);
  emit(state.copyWith(timelineState: event.newState));
});
```

### مراقبة الحفظ

```dart
getIt<AutosaveService>().autosaveStream.listen((event) {
  if (event.type == AutosaveEventType.completed) {
    print('✓ تم الحفظ التلقائي');
  }
});
```

---

## الاسترجاع

```dart
// جميع المشاريع القابلة للاسترجاع
final projects = await storage.recoveryService.getRecoverableProjects();

// استعادة آخر نسخة
final state = await storage.recoveryService.recoverProject(projectId);

// استعادة نسخة قديمة
final oldState = await storage.recoveryService
  .recoverProjectVersion(projectId, versionNumber);
```

---

## عند الإغلاق

```dart
@override
void dispose() {
  getIt<StorageService>().dispose(); // حفظ فوري + تنظيف
  super.dispose();
}
```

---

## استكشاف الأخطاء

| المشكلة | الحل |
|-------|------|
| `Build failed` | `flutter clean && flutter pub run build_runner build` |
| `Database locked` | تأكد من استدعاء `dispose()` مرة واحدة فقط |
| `Not initialized` | تأكد من `await storageService.initialize()` |
| `App crashed` | استخدم `flutter run -v` للسجلات |

---

## مثال كامل

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final storageService = StorageService();
  await storageService.initialize();
  getIt.registerSingleton<StorageService>(storageService);
  
  runApp(const MyApp());
}

class MyAppState extends State {
  @override
  void initState() {
    super.initState();
    _initializeProject();
  }
  
  Future<void> _initializeProject() async {
    final storage = getIt<StorageService>();
    
    // محاولة استعادة
    final recoveryInfo = await storage
      .recoveryService.getRecoveryInfo();
    
    if (recoveryInfo.projectsCount > 0) {
      // هناك مشاريع قابلة للاسترجاع
      final projects = await storage
        .recoveryService.getRecoverableProjects();
      
      // استعادة أول مشروع
      final state = await storage
        .recoveryService.recoverProject(projects[0].projectId);
      
      context.read<EditorBloc>().add(
        ProjectLoadedEvent(state),
      );
    } else {
      // إنشاء مشروع جديد
      final result = await storage.createNewProject(
        name: 'مشروعي الأول',
      );
      
      if (result.success) {
        context.read<EditorBloc>().add(
          ProjectCreatedEvent(result.projectId),
        );
      }
    }
  }
  
  @override
  void dispose() {
    getIt<StorageService>().dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: EditorScreen(),
    );
  }
}
```

---

## المرجع السريع

- **README.md** - الشرح المفصل
- **INTEGRATION_GUIDE.md** - التكامل مع BLoC
- **SETUP.md** - خطوات الإعداد
- **FILES_SUMMARY.md** - ملخص كل ملف

---

**تذكر**: 
- ✅ بعد كتابة app_database.dart، شغّل `flutter pub run build_runner build`
- ✅ استدعِ `initialize()` قبل استخدام أي شيء
- ✅ استدعِ `dispose()` عند الإغلاق
- ✅ الحفظ التلقائي يعمل بدون تدخل من جانبك

تم إنشاؤه بـ 💙 من فريق التطوير
