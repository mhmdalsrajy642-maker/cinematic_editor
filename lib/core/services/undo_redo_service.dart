// lib/core/services/undo_redo_service.dart
// هذه الخدمة هي قلب نظام التراجع/الإعادة
// كل تعديل يُحفظ كـ JSON خفيف على التخزين المحلي
// بدلاً من تخزين كل الفيديوهات نفسها نُخزّن فقط "وصف" التايم لاين
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/timeline_models.dart';
class UndoRedoService {
  // الحد الأقصى لعدد الخطوات المحفوظة (لتوفير الذاكرة)
  static const int _maxHistorySize = 100;
  // اسم المشروع الحالي
  final String projectId;
  // مؤشر الخطوة الحالية في التاريخ
  int _currentIndex = -1;
  // قائمة مسارات ملفات JSON المحفوظة على القرص
  final List<String> _historyFilePaths = [];
  UndoRedoService({required this.projectId});
  // ====================================================
  // هل يمكن التراجع؟
  // ====================================================
  bool get canUndo => _currentIndex > 0;
  // ====================================================
  // هل يمكن الإعادة؟
  // ====================================================
  bool get canRedo => _currentIndex < _historyFilePaths.length - 1;
  // ====================================================
  // حفظ حالة جديدة (يُستدعى بعد كل تعديل)
  // ====================================================
  Future<void> pushState(TimelineState state) async {
    // إذا أجرى المستخدم تعديلاً جديداً بعد التراجع، احذف المستقبل
    if (_currentIndex < _historyFilePaths.length - 1) {
      final filesToDelete = _historyFilePaths.sublist(_currentIndex + 1);
      for (final path in filesToDelete) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
      _historyFilePaths.removeRange(_currentIndex + 1, _historyFilePaths.length);
    }
    // إذا وصلنا للحد الأقصى، احذف أقدم حالة
    if (_historyFilePaths.length >= _maxHistorySize) {
      final oldestPath = _historyFilePaths.removeAt(0);
      final file = File(oldestPath);
      if (await file.exists()) {
        await file.delete();
      }
      _currentIndex--;
    }
    // احفظ الحالة الجديدة كملف JSON
    final filePath = await _saveStateToFile(state);
    _historyFilePaths.add(filePath);
    _currentIndex = _historyFilePaths.length - 1;
  }
  // ====================================================
  // تراجع (Undo) - ارجع للحالة السابقة
  // ====================================================
  Future<TimelineState?> undo() async {
    if (!canUndo) return null;
    _currentIndex--;
    return await _loadStateFromFile(_historyFilePaths[_currentIndex]);
  }
  // ====================================================
  // إعادة (Redo) - اذهب للحالة التالية
  // ====================================================
  Future<TimelineState?> redo() async {
    if (!canRedo) return null;
    _currentIndex++;
    return await _loadStateFromFile(_historyFilePaths[_currentIndex]);
  }
  // ====================================================
  // حفظ الحالة في ملف JSON على القرص
  // ====================================================
  Future<String> _saveStateToFile(TimelineState state) async {
    // الحصول على مجلد مؤقت للتطبيق
    final tempDir = await getTemporaryDirectory();
    final historyDir = Directory('${tempDir.path}/undo_history/$projectId');
    
    // إنشاء المجلد إذا لم يكن موجوداً
    if (!await historyDir.exists()) {
      await historyDir.create(recursive: true);
    }
    // اسم الملف يحتوي على الطابع الزمني لضمان التفرد
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final filePath = '${historyDir.path}/state_$timestamp.json';
    // تحويل الحالة إلى JSON وحفظها
    final jsonString = json.encode(state.toJson());
    final file = File(filePath);
    await file.writeAsString(jsonString, flush: true);
    return filePath;
  }
  // ====================================================
  // تحميل الحالة من ملف JSON
  // ====================================================
  Future<TimelineState?> _loadStateFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      
      final jsonString = await file.readAsString();
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      return TimelineState.fromJson(jsonMap);
    } catch (e) {
      // إذا فسد الملف، تجاهله وأعد null
      return null;
    }
  }
  // ====================================================
  // مسح كل التاريخ عند إغلاق المشروع
  // ====================================================
  Future<void> clearHistory() async {
    for (final path in _historyFilePaths) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    _historyFilePaths.clear();
    _currentIndex = -1;
  }
  // ====================================================
  // الحصول على معلومات التاريخ (للعرض في الـ UI)
  // ====================================================
  HistoryInfo get historyInfo => HistoryInfo(
    totalSteps: _historyFilePaths.length,
    currentStep: _currentIndex,
    canUndo: canUndo,
    canRedo: canRedo,
  );
}
// نموذج معلومات التاريخ للعرض
class HistoryInfo {
  final int totalSteps;
  final int currentStep;
  final bool canUndo;
  final bool canRedo;
  const HistoryInfo({
    required this.totalSteps,
    required this.currentStep,
    required this.canUndo,
    required this.canRedo,
  });
}
