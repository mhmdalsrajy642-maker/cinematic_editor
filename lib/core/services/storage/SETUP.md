// lib/core/services/storage/SETUP.md
# 🔧 دليل الإعداد والتثبيت

## خطوات الإعداد

### الخطوة 1: التحقق من Dependencies

تأكد أن `pubspec.yaml` يحتوي على:

```yaml
dependencies:
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.24
  path_provider: ^2.1.3
  path: ^1.9.0

dev_dependencies:
  build_runner: ^2.4.11
  drift_dev: ^2.18.0
```

**الكل موجود بالفعل في المشروع ✓**

---

### الخطوة 2: توليد ملف قاعدة البيانات

يجب توليد ملف `app_database.g.dart` من `app_database.dart`:

```bash
# في مجلد المشروع الجذر
flutter pub run build_runner build
```

أو للمراقبة المستمرة:

```bash
flutter pub run build_runner watch
```

**الناتج المتوقع**:
```
lib/core/services/storage/app_database.g.dart
```

---

### الخطوة 3: استيراد الملفات الجديدة

في الملفات التي تحتاج الخدمات:

```dart
// الاستيراد الكامل
import 'package:cinematic_editor/core/services/storage/storage.dart';

// أو استيراد محدد
import 'package:cinematic_editor/core/services/storage/storage_service.dart';
import 'package:cinematic_editor/core/services/storage/autosave_service.dart';
import 'package:cinematic_editor/core/services/storage/recovery_service.dart';
```

---

### الخطوة 4: تهيئة في main.dart

```dart
import 'package:get_it/get_it.dart';
import 'package:cinematic_editor/core/services/storage/storage.dart';

final getIt = GetIt.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة StorageService
  final storageService = StorageService();
  await storageService.initialize();
  
  // تسجيل الخدمة
  getIt.registerSingleton<StorageService>(storageService);
  
  // بقية التطبيق
  runApp(const CinematicEditorApp());
}
```

---

### الخطوة 5: التعامل مع الإغلاق

```dart
class CinematicEditorApp extends StatefulWidget {
  @override
  State<CinematicEditorApp> createState() => _CinematicEditorAppState();
}

class _CinematicEditorAppState extends State<CinematicEditorApp> 
    with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.detached) {
      // حفظ فوري عند إغلاق التطبيق
      getIt<StorageService>().closeCurrentProject();
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    getIt<StorageService>().dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // بقية الـ UI
  }
}
```

---

## 📋 قائمة التحقق من الإعداد

- [ ] جميع Dependencies موجودة في pubspec.yaml
- [ ] تم تشغيل `flutter pub run build_runner build`
- [ ] تم إنشاء `app_database.g.dart` بدون أخطاء
- [ ] تم استيراد `StorageService` في main.dart
- [ ] تم تهيئة `StorageService()` في `main()`
- [ ] تم تسجيل الخدمة في GetIt
- [ ] تم إضافة WidgetsBindingObserver للإغلاق
- [ ] لا توجد أخطاء compile
- [ ] التطبيق يعمل بدون crashes

---

## 🐛 استكشاف الأخطاء الشائعة

### ❌ خطأ: "Build failed"

```
Exception: Unable to create databases in application directory
```

**الحل**:
```bash
# امسح ملفات البناء
flutter clean

# جرب مجدداً
flutter pub run build_runner build --verbose
```

---

### ❌ خطأ: "app_database.g.dart not found"

```
File not found: app_database.g.dart
```

**الحل**:
```bash
# تأكد من تشغيل build_runner
flutter pub run build_runner build

# إذا فشل، حاول:
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

---

### ❌ خطأ: "StorageService not initialized"

```
Exception: خدمة التخزين لم تُهيأ بعد
```

**الحل**:
- تأكد من استدعاء `await storageService.initialize()` في `main()`
- تأكد من تسجيل الخدمة في GetIt قبل استخدامها

---

### ❌ خطأ: "Database locked"

```
Exception: database is locked
```

**الحل**:
- تأكد من إغلاق قاعدة البيانات بشكل صحيح عند الإغلاق
- اجعل `dispose()` فقط في نقطة واحدة

```dart
@override
void dispose() {
  getIt<StorageService>().dispose(); // مرة واحدة فقط
  super.dispose();
}
```

---

### ❌ خطأ: "Crash on Android"

```
E/AndroidRuntime: java.io.FileNotFoundException
```

**الحل**:
- تأكد من الصلاحيات في `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

---

## 📊 اختبار الإعداد

### اختبار 1: إنشاء مشروع

```dart
final storageService = getIt<StorageService>();

final result = await storageService.createNewProject(
  name: 'اختبار',
  description: 'مشروع اختبار',
);

if (result.success) {
  print('✓ تم إنشاء المشروع بنجاح: ${result.projectId}');
} else {
  print('✗ فشل: ${result.errorMessage}');
}
```

### اختبار 2: حفظ واسترجاع

```dart
// حفظ
final saveResult = await storageService.saveCurrentState(timelineState);
if (saveResult.success) {
  print('✓ تم الحفظ: ${saveResult.snapshotId}');
}

// تحميل
final openResult = await storageService.openProject(projectId);
if (openResult.success) {
  print('✓ تم التحميل: ${openResult.timelineState?.projectId}');
}
```

### اختبار 3: الاسترجاع

```dart
final recoveryInfo = await storageService.recoveryService.getRecoveryInfo();
print('المشاريع: ${recoveryInfo.projectsCount}');
print('اللقطات: ${recoveryInfo.totalSnapshots}');
print('الحجم: ${recoveryInfo.totalSizeFormatted}');
```

---

## 🚀 الخطوات التالية

بعد الإعداد الناجح:

1. **دمج مع BLoC** - انظر [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)
2. **إضافة UI للحفظ** - عرض حالة الحفظ التلقائي
3. **اختبار الاسترجاع** - اختبر إيقاف التطبيق وإعادة فتحه
4. **تحسين الأداء** - قياس استهلاك الذاكرة

---

## 📞 الدعم

إذا واجهت مشاكل:

1. تحقق من السجلات: `flutter run -v`
2. اقرأ [README.md](README.md) للمرجع
3. انظر [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md) للأمثلة

---

**آخر تحديث**: 2026-06-10
