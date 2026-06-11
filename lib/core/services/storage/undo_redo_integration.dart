// lib/core/services/storage/undo_redo_integration.dart
// تكامل خدمة Undo/Redo مع نظام Drift الدائم
// يضمن توافق الميزتين معاً
import 'dart:async';
import '../../models/timeline_models.dart';
import '../undo_redo_service.dart';
import 'repositories/project_repository.dart';
import 'autosave_service.dart';

/// خدمة مُحسَّنة لـ Undo/Redo تتكامل مع Drift
/// تحافظ على الأداء السريع مع ضمان الحفظ الدائم
class IntegratedUndoRedoService {
  final UndoRedoService undoRedoService;
  final ProjectRepository projectRepository;
  final AutosaveService autosaveService;

  IntegratedUndoRedoService({
    required this.undoRedoService,
    required this.projectRepository,
    required this.autosaveService,
  });

  /// دفع حالة جديدة - تجمع بين Undo/Redo و Drift
  Future<void> pushState(TimelineState state) async {
    // 1. إضافة إلى Undo/Redo للعكس السريع (في الذاكرة)
    await undoRedoService.pushState(state);

    // 2. إخطار خدمة الحفظ التلقائي (حفظ دائم كل 60 ثانية)
    autosaveService.markAsModified(state);
  }

  /// العودة للحالة السابقة (Undo)
  Future<TimelineState?> undo() async {
    // 1. الحصول من Undo/Redo (سريع - من الذاكرة)
    final state = await undoRedoService.undo();

    if (state != null) {
      // 2. حفظ في Drift كـ "undo" snapshot
      await projectRepository.saveSnapshot(
        projectId: state.projectId,
        state: state,
        label: 'undo',
      );
    }

    return state;
  }

  /// الذهاب للحالة التالية (Redo)
  Future<TimelineState?> redo() async {
    // 1. الحصول من Redo (سريع - من الذاكرة)
    final state = await undoRedoService.redo();

    if (state != null) {
      // 2. حفظ في Drift كـ "redo" snapshot
      await projectRepository.saveSnapshot(
        projectId: state.projectId,
        state: state,
        label: 'redo',
      );
    }

    return state;
  }

  /// الحصول على معلومات التاريخ
  HistoryInfo get historyInfo => undoRedoService.historyInfo;

  /// هل يمكن العودة؟
  bool get canUndo => undoRedoService.canUndo;

  /// هل يمكن الإعادة؟
  bool get canRedo => undoRedoService.canRedo;

  /// تنظيف التاريخ
  Future<void> clearHistory() async {
    await undoRedoService.clearHistory();
  }
}

// ====================================================
// BLoC Event للتعامل مع Undo/Redo
// ====================================================

abstract class UndoRedoEvent {
  const UndoRedoEvent();
}

class UndoEvent extends UndoRedoEvent {
  const UndoEvent();
}

class RedoEvent extends UndoRedoEvent {
  const RedoEvent();
}

class PushStateEvent extends UndoRedoEvent {
  final TimelineState state;
  const PushStateEvent(this.state);
}

class ClearHistoryEvent extends UndoRedoEvent {
  const ClearHistoryEvent();
}

// ====================================================
// مثال على استخدام في EditorBloc
// ====================================================

/// هذا مثال على كيفية دمج الخدمة في BLoC
/// (انسخ هذا إلى ملف EditorBloc الفعلي)
/*
class EditorBloc extends Bloc<EditorEvent, EditorState> {
  final IntegratedUndoRedoService _undoRedoService;
  
  EditorBloc({required IntegratedUndoRedoService undoRedoService})
    : _undoRedoService = undoRedoService,
      super(const EditorState.initial()) {
    
    on<UndoEvent>(_onUndo);
    on<RedoEvent>(_onRedo);
    on<PushStateEvent>(_onPushState);
  }
  
  Future<void> _onUndo(UndoEvent event, Emitter<EditorState> emit) async {
    final previousState = await _undoRedoService.undo();
    
    if (previousState != null) {
      emit(state.copyWith(
        timelineState: previousState,
        historyInfo: _undoRedoService.historyInfo,
      ));
    }
  }
  
  Future<void> _onRedo(RedoEvent event, Emitter<EditorState> emit) async {
    final nextState = await _undoRedoService.redo();
    
    if (nextState != null) {
      emit(state.copyWith(
        timelineState: nextState,
        historyInfo: _undoRedoService.historyInfo,
      ));
    }
  }
  
  Future<void> _onPushState(
    PushStateEvent event,
    Emitter<EditorState> emit,
  ) async {
    // عند حدوث أي تعديل من المستخدم
    await _undoRedoService.pushState(event.state);
    
    emit(state.copyWith(
      timelineState: event.state,
      historyInfo: _undoRedoService.historyInfo,
    ));
  }
}
*/

// ====================================================
// Widget لعرض أزرار Undo/Redo
// ====================================================

import 'package:flutter/material.dart';

/// widget يعرض أزرار Undo/Redo مع حالتها
/// (مثال لاستخدام الخدمة في الـ UI)
/*
class UndoRedoToolbar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditorBloc, EditorState>(
      builder: (context, state) {
        final historyInfo = state.historyInfo;
        
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // زر Undo
              Tooltip(
                message: 'تراجع (Ctrl+Z)',
                child: IconButton(
                  icon: const Icon(Icons.undo),
                  onPressed: historyInfo.canUndo
                    ? () => context.read<EditorBloc>().add(const UndoEvent())
                    : null,
                  tooltip: 'تراجع${historyInfo.canUndo ? '' : ' (متاح)'}',
                ),
              ),
              
              // زر Redo
              Tooltip(
                message: 'إعادة (Ctrl+Y)',
                child: IconButton(
                  icon: const Icon(Icons.redo),
                  onPressed: historyInfo.canRedo
                    ? () => context.read<EditorBloc>().add(const RedoEvent())
                    : null,
                  tooltip: 'إعادة${historyInfo.canRedo ? '' : ' (متاح)'}',
                ),
              ),
              
              // معلومات التاريخ
              Text(
                'الخطوة ${historyInfo.currentStep + 1}/${historyInfo.totalSteps}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}
*/

// ====================================================
// Mixin للـ BLoC للتعامل مع اختصارات لوحة المفاتيح
// ====================================================

/// Mixin يمكن إضافته إلى EditorBloc للتعامل مع اختصارات Undo/Redo
mixin UndoRedoKeyboardShortcuts {
  // للاستخدام في Widget:
  // void _handleKeyEvent(RawKeyEvent event) {
  //   if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyZ) {
  //     context.read<EditorBloc>().add(const UndoEvent());
  //   } else if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyY) {
  //     context.read<EditorBloc>().add(const RedoEvent());
  //   }
  // }
}

// ====================================================
// اعتبارات الأداء والتحسينات
// ====================================================

/*
ملاحظات مهمة:

1. **الأداء**:
   - Undo/Redo يبقى في الذاكرة للسرعة
   - Drift يحفظ نسخة واحدة فقط من الحالة الحالية
   - لا تأثير على سرعة التطبيق

2. **التوافق**:
   - يمكن استخدام Undo/Redo بدون Drift
   - يمكن استخدام Drift بدون Undo/Redo
   - تعمل معاً بسلاسة

3. **الاسترجاع**:
   - إذا انقطع التطبيق، يتم تحميل آخر حالة محفوظة
   - سجل Undo/Redo لن يكون متاحاً (يبدأ من جديد)
   - هذا أمر طبيعي وسلوك متوقع

4. **الحد الأقصى للذاكرة**:
   - اضبط _maxHistorySize في UndoRedoService
   - إذا كان 100 = حفظ آخر 100 تعديل
   - كل تعديل إضافي يحذف الأقدم

5. **التنظيف**:
   - عند إغلاق المشروع، احذف الذاكرة المؤقتة
   - الـ Drift snapshots تبقى للاسترجاع المستقبلي
*/
