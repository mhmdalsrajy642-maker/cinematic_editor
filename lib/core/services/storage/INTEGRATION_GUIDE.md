// lib/core/services/storage/INTEGRATION_GUIDE.md
# دليل التكامل مع نظام Drift للتخزين الدائم

## نظرة عامة

هذا الدليل يشرح كيفية دمج نظام التخزين الدائم (Drift) مع الميزات الموجودة:
- Undo/Redo Service
- BLoC Pattern
- TimelineState Management

## الهدف من النظام

1. **الحفظ التلقائي**: حفظ حالة المشروع تلقائياً كل 60 ثانية
2. **الاسترجاع**: استعادة المشروع بعد تعطل التطبيق
3. **إدارة اللقطات**: حفظ نسخ متعددة من المشروع
4. **الأداء**: عدم التأثير على سرعة التطبيق

---

## 1. الإعداد الأولي

### في main.dart

```dart
import 'package:cinematic_editor/core/services/storage/storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة خدمة التخزين
  final storageService = StorageService();
  await storageService.initialize();
  
  // حقن الخدمة في GetIt
  getIt.registerSingleton<StorageService>(storageService);
  
  runApp(const CinematicEditorApp());
}
```

### معالجة تعطل التطبيق (في EditorBloc)

```dart
class EditorBloc extends Bloc<EditorEvent, EditorState> {
  final StorageService _storageService;
  
  EditorBloc({required StorageService storageService})
    : _storageService = storageService,
      super(const EditorState.initial()) {
    on<RecoverProjectEvent>(_onRecoverProject);
    on<OpenProjectEvent>(_onOpenProject);
  }
  
  Future<void> _onRecoverProject(
    RecoverProjectEvent event,
    Emitter<EditorState> emit,
  ) async {
    emit(const EditorState.loading());
    
    // استعادة المشروع من آخر لقطة
    final result = await _storageService.openProject(event.projectId);
    
    if (result.success) {
      emit(EditorState.loaded(
        projectId: result.projectData!.projectId,
        timelineState: result.timelineState!,
        isRecovered: result.isRecovered,
      ));
    } else {
      emit(EditorState.error(result.errorMessage!));
    }
  }
}
```

---

## 2. التكامل مع Undo/Redo Service

### المشروع الحالي

الـ UndoRedoService يحفظ كل حالة في ملفات JSON على القرص. نظام Drift يعتمد على نفس المبدأ:

```
UndoRedoService     → يحفظ في Temporary Directory
↓
Drift (New)         → يحفظ في Application Documents Directory
```

### التدفق المقترح

```
User edits Timeline
        ↓
EditorBloc emits new state
        ↓
Autosave marks as modified
        ↓
Every 60 seconds: Save to Drift
        ↓
Drift saves TimelineState as JSON + snapshot
```

### الترقية تدريجية

يمكنك الاحتفاظ بـ UndoRedoService للـ Undo/Redo السريع، واستخدام Drift للحفظ الدائم:

```dart
class ProjectEditingService {
  final UndoRedoService _undoRedoService;
  final AutosaveService _autosaveService;
  final ProjectRepository _projectRepository;
  
  // عند كل تعديل من المستخدم
  void handleTimelineEdit(TimelineState newState) {
    // 1. إضافة إلى Undo/Redo (للعكس السريع)
    _undoRedoService.pushState(newState);
    
    // 2. إخطار خدمة الحفظ التلقائي
    _autosaveService.markAsModified(newState);
  }
  
  // عند الضغط على Undo
  Future<TimelineState?> performUndo() async {
    // الحصول من UndoRedoService (سريع)
    final state = await _undoRedoService.undo();
    
    // تحديث آخر لقطة في Drift (للاسترجاع لاحقاً)
    if (state != null) {
      await _projectRepository.saveSnapshot(
        projectId: state.projectId,
        state: state,
        label: 'manual-undo',
      );
    }
    
    return state;
  }
}
```

---

## 3. في EditorBloc

### مراقبة التغييرات

```dart
class EditorBloc extends Bloc<EditorEvent, EditorState> {
  final AutosaveService _autosaveService;
  StreamSubscription? _autosaveSubscription;
  
  EditorBloc() {
    // مراقبة أحداث الحفظ التلقائي
    _autosaveSubscription = 
      _autosaveService.autosaveStream.listen((event) {
      switch (event.type) {
        case AutosaveEventType.started:
          add(const AutosaveStartedEvent());
          break;
        case AutosaveEventType.completed:
          add(AutosaveCompletedEvent(event.snapshotId!));
          break;
        case AutosaveEventType.failed:
          add(AutosaveFailedEvent(event.errorMessage!));
          break;
        case AutosaveEventType.modified:
          // لا تحتاج إلى أي شيء هنا
          break;
      }
    });
  }
  
  Future<void> _onTimelineModified(
    TimelineModifiedEvent event,
    Emitter<EditorState> emit,
  ) async {
    // تحديث الحالة المحلية
    emit(state.copyWith(timelineState: event.newState));
    
    // إخطار خدمة الحفظ التلقائي
    _autosaveService.markAsModified(event.newState);
  }
  
  @override
  Future<void> close() async {
    await _autosaveSubscription?.cancel();
    super.close();
  }
}
```

---

## 4. عند إغلاق التطبيق

```dart
class CinematicEditorApp extends StatefulWidget {
  @override
  State<CinematicEditorApp> createState() => _CinematicEditorAppState();
}

class _CinematicEditorAppState extends State<CinematicEditorApp> {
  @override
  void initState() {
    super.initState();
    // التقاط حدث الإغلاق
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // حفظ فوري عند الإغلاق
        getIt<StorageService>().closeCurrentProject();
        break;
      default:
        break;
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
```

---

## 5. استعادة بعد التعطل

```dart
class ProjectRecoveryWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditorBloc, EditorState>(
      builder: (context, state) {
        if (state is EditorStateRecoveryRequired) {
          return Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('تم اكتشاف حفظ سابق'),
                const SizedBox(height: 16),
                Text(
                  'آخر حفظ: ${state.lastSnapshot.lastSnapshotFormatted}',
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        context.read<EditorBloc>().add(
                          RecoverProjectEvent(state.projectId),
                        );
                      },
                      child: const Text('استعادة'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        context.read<EditorBloc>().add(
                          CreateNewProjectEvent(),
                        );
                      },
                      child: const Text('جديد'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
        
        return const SizedBox.shrink();
      },
    );
  }
}
```

---

## 6. عرض حالة الحفظ التلقائي

```dart
class AutosaveIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocListener<EditorBloc, EditorState>(
      listener: (context, state) {
        if (state is AutosaveCompletedState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('تم الحفظ التلقائي'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: BlocBuilder<EditorBloc, EditorState>(
        builder: (context, state) {
          bool isAutosaving = state is AutosavingState;
          
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isAutosaving)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  isAutosaving ? 'جاري الحفظ...' : 'محفوظ',
                  style: TextStyle(
                    color: isAutosaving ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

---

## 7. اعتبارات الأداء

### تقليل حجم اللقطات

```dart
// عند الحفظ، يمكنك ضغط البيانات
String _compressSnapshotJson(String json) {
  // استخدام gzip للضغط
  return base64.encode(gzip.encode(utf8.encode(json)));
}

// عند التحميل، فك الضغط
String _decompressSnapshotJson(String compressed) {
  return utf8.decode(
    gzip.decode(base64.decode(compressed))
  );
}
```

### تحديد الحد الأقصى للقطات

```dart
// تنظيف تلقائي للقطات القديمة
Future<void> _cleanupSnapshots() async {
  final projectId = state.projectId;
  
  // الاحتفاظ بـ 50 لقطة فقط
  await _projectRepository.cleanupOldSnapshots(
    projectId,
    keepCount: 50,
  );
}
```

### الحفظ غير المتزامن

```dart
// الحفظ التلقائي يعمل بدون تأخير واجهة المستخدم
_autosaveService.autosaveInterval = const Duration(seconds: 60);
```

---

## 8. التوافق مع الميزات الحالية

| الميزة | الوضع الحالي | مع Drift |
|------|-----------|----------|
| Undo/Redo | في الذاكرة | بقي كما هو + حفظ دائم |
| حفظ يدوي | ملفات JSON | قاعدة بيانات |
| الاسترجاع | يدوي | تلقائي |
| الأصول | مسارات | مسارات + بيانات وصفية |
| الصادرات | حفظ مباشر | تتبع في قاعدة بيانات |

---

## 9. قائمة التحقق من الدمج

- [ ] تهيئة StorageService في main.dart
- [ ] إضافة RecoveryBloc للتعامل مع الاسترجاع
- [ ] دمج AutosaveService في EditorBloc
- [ ] إضافة UI لعرض حالة الحفظ
- [ ] اختبار الحفظ التلقائي كل 60 ثانية
- [ ] اختبار الاسترجاع بعد الإغلاق القسري
- [ ] قياس حجم قاعدة البيانات
- [ ] اختبار تنظيف اللقطات القديمة
- [ ] التحقق من الأداء على أجهزة قديمة

---

## 10. استكشاف الأخطاء

### المشروع لا يُحفظ
- تحقق من صلاحيات الكتابة على الجهاز
- تأكد من تهيئة StorageService
- تحقق من سجلات الخطأ

### لا يمكن استعادة المشروع
- تحقق من وجود اللقطات في قاعدة البيانات
- تحقق من صحة JSON
- جرب استخدام إصدار أقدم من اللقطات

### بطء التطبيق
- قلل عدد اللقطات المحفوظة
- زيادة IntervalAutosave
- استخدم Proguard على Android

---

تم الانتهاء من دليل التكامل. للمزيد من الأسئلة، راجع الملفات المرفقة.
