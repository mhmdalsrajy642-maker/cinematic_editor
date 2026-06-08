// lib/features/editor/presentation/cubit/editor_cubit.dart
// هذا الـ Cubit هو المحرك المركزي لكل عمليات المحرر
// كل تعديل في التايم لاين يمر عبر هذا الكلاس
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/models/timeline_models.dart';
import '../../../../core/services/undo_redo_service.dart';
import '../../../../shared/constants/app_constants.dart';
// ====================================================
// حالة المحرر
// ====================================================
class EditorState extends Equatable {
  final TimelineState timelineState;
  final double currentPlayheadPosition;    // موضع مؤشر التشغيل بالثانية
  final bool isPlaying;                    // هل الفيديو يشتغل؟
  final double timelineZoom;               // مستوى التكبير (1.0 = عادي)
  final double timelineScrollOffset;       // موضع التمرير
  final String? selectedClipId;           // معرف المقطع المحدد
  final EditorTool activeTool;            // الأداة النشطة حالياً
  final bool canUndo;
  final bool canRedo;
  final bool isExporting;
  final double exportProgress;
  final EditorStatus status;
  final String? errorMessage;
  final bool isAIPanelOpen;               // هل لوحة الذكاء الاصطناعي مفتوحة؟
  final bool isAudioPanelOpen;            // هل لوحة الصوت مفتوحة؟
  final bool isTextPanelOpen;             // هل لوحة النص مفتوحة؟
  const EditorState({
    required this.timelineState,
    this.currentPlayheadPosition = 0.0,
    this.isPlaying = false,
    this.timelineZoom = 1.0,
    this.timelineScrollOffset = 0.0,
    this.selectedClipId,
    this.activeTool = EditorTool.select,
    this.canUndo = false,
    this.canRedo = false,
    this.isExporting = false,
    this.exportProgress = 0.0,
    this.status = EditorStatus.idle,
    this.errorMessage,
    this.isAIPanelOpen = false,
    this.isAudioPanelOpen = false,
    this.isTextPanelOpen = false,
  });
  factory EditorState.initial(String projectId) {
    return EditorState(
      timelineState: TimelineState.empty(projectId),
    );
  }
  EditorState copyWith({
    TimelineState? timelineState,
    double? currentPlayheadPosition,
    bool? isPlaying,
    double? timelineZoom,
    double? timelineScrollOffset,
    String? selectedClipId,
    EditorTool? activeTool,
    bool? canUndo,
    bool? canRedo,
    bool? isExporting,
    double? exportProgress,
    EditorStatus? status,
    String? errorMessage,
    bool? isAIPanelOpen,
    bool? isAudioPanelOpen,
    bool? isTextPanelOpen,
    bool clearSelectedClip = false,
    bool clearError = false,
  }) {
    return EditorState(
      timelineState: timelineState ?? this.timelineState,
      currentPlayheadPosition: currentPlayheadPosition ?? this.currentPlayheadPosition,
      isPlaying: isPlaying ?? this.isPlaying,
      timelineZoom: timelineZoom ?? this.timelineZoom,
      timelineScrollOffset: timelineScrollOffset ?? this.timelineScrollOffset,
      selectedClipId: clearSelectedClip ? null : (selectedClipId ?? this.selectedClipId),
      activeTool: activeTool ?? this.activeTool,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      isExporting: isExporting ?? this.isExporting,
      exportProgress: exportProgress ?? this.exportProgress,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isAIPanelOpen: isAIPanelOpen ?? this.isAIPanelOpen,
      isAudioPanelOpen: isAudioPanelOpen ?? this.isAudioPanelOpen,
      isTextPanelOpen: isTextPanelOpen ?? this.isTextPanelOpen,
    );
  }
  @override
  List<Object?> get props => [
    timelineState, currentPlayheadPosition, isPlaying,
    timelineZoom, timelineScrollOffset, selectedClipId,
    activeTool, canUndo, canRedo, isExporting, exportProgress,
    status, errorMessage, isAIPanelOpen, isAudioPanelOpen, isTextPanelOpen,
  ];
}
enum EditorTool { select, cut, text, audio, templates, aiCommands }
enum EditorStatus { idle, loading, processing, error }
// ====================================================
// محرك الحالة (Cubit)
// ====================================================
class EditorCubit extends Cubit<EditorState> {
  final UndoRedoService _undoRedoService;
  EditorCubit({required String projectId})
      : _undoRedoService = UndoRedoService(projectId: projectId),
        super(EditorState.initial(projectId));
  // ====================================================
  // إضافة مقطع فيديو للتايم لاين
  // ====================================================
  Future<void> addVideoClip(VideoClip clip) async {
    final newClips = [...state.timelineState.videoClips, clip];
    final newTimelineState = state.timelineState.copyWith(
      videoClips: newClips,
      totalDuration: _calculateTotalDuration(newClips, state.timelineState.audioClips),
    );
    
    // حفظ الحالة الجديدة لنظام Undo
    await _undoRedoService.pushState(newTimelineState);
    
    final historyInfo = _undoRedoService.historyInfo;
    emit(state.copyWith(
      timelineState: newTimelineState,
      canUndo: historyInfo.canUndo,
      canRedo: historyInfo.canRedo,
    ));
  }
  // ====================================================
  // إضافة مقطع صوت للتايم لاين
  // ====================================================
  Future<void> addAudioClip(AudioClip clip) async {
    final newClips = [...state.timelineState.audioClips, clip];
    final newTimelineState = state.timelineState.copyWith(
      audioClips: newClips,
      totalDuration: _calculateTotalDuration(
          state.timelineState.videoClips, newClips),
    );
    
    await _undoRedoService.pushState(newTimelineState);
    final historyInfo = _undoRedoService.historyInfo;
    emit(state.copyWith(
      timelineState: newTimelineState,
      canUndo: historyInfo.canUndo,
      canRedo: historyInfo.canRedo,
    ));
  }
  // ====================================================
  // تحريك مقطع على التايم لاين (Drag)
  // ====================================================
  Future<void> moveVideoClip({
    required String clipId,
    required double newStartTime,
    required int newTrackIndex,
  }) async {
    final clipIndex = state.timelineState.videoClips
        .indexWhere((c) => c.id == clipId);
    if (clipIndex == -1) return;
    final clip = state.timelineState.videoClips[clipIndex];
    final duration = clip.duration;
    
    final updatedClip = clip.copyWith(
      startTime: newStartTime,
      endTime: newStartTime + duration,
      trackIndex: newTrackIndex,
    );
    
    final newClips = [...state.timelineState.videoClips];
    newClips[clipIndex] = updatedClip;
    
    final newTimelineState = state.timelineState.copyWith(
      videoClips: newClips,
      totalDuration: _calculateTotalDuration(newClips, state.timelineState.audioClips),
    );
    
    await _undoRedoService.pushState(newTimelineState);
    final historyInfo = _undoRedoService.historyInfo;
    emit(state.copyWith(
      timelineState: newTimelineState,
      canUndo: historyInfo.canUndo,
      canRedo: historyInfo.canRedo,
    ));
  }
  // ====================================================
  // قص مقطع (Trim) من اليمين أو اليسار
  // ====================================================
  Future<void> trimVideoClip({
    required String clipId,
    double? newStartTime,
    double? newEndTime,
    double? newClipStartOffset,
    double? newClipEndOffset,
  }) async {
    final clipIndex = state.timelineState.videoClips
        .indexWhere((c) => c.id == clipId);
    if (clipIndex == -1) return;
    final clip = state.timelineState.videoClips[clipIndex];
    final updatedClip = clip.copyWith(
      startTime: newStartTime,
      endTime: newEndTime,
      clipStartOffset: newClipStartOffset,
      clipEndOffset: newClipEndOffset,
    );
    
    final newClips = [...state.timelineState.videoClips];
    newClips[clipIndex] = updatedClip;
    
    final newTimelineState = state.timelineState.copyWith(
      videoClips: newClips,
      totalDuration: _calculateTotalDuration(newClips, state.timelineState.audioClips),
    );
    
    await _undoRedoService.pushState(newTimelineState);
    final historyInfo = _undoRedoService.historyInfo;
    emit(state.copyWith(
      timelineState: newTimelineState,
      canUndo: historyInfo.canUndo,
      canRedo: historyInfo.canRedo,
    ));
  }
  // ====================================================
  // حذف مقطع
  // ====================================================
  Future<void> deleteVideoClip(String clipId) async {
    final newClips = state.timelineState.videoClips
        .where((c) => c.id != clipId)
        .toList();
    
    final newTimelineState = state.timelineState.copyWith(
      videoClips: newClips,
      totalDuration: _calculateTotalDuration(newClips, state.timelineState.audioClips),
    );
    
    await _undoRedoService.pushState(newTimelineState);
    final historyInfo = _undoRedoService.historyInfo;
    emit(state.copyWith(
      timelineState: newTimelineState,
      canUndo: historyInfo.canUndo,
      canRedo: historyInfo.canRedo,
      clearSelectedClip: true,
    ));
  }
  // ====================================================
  // تطبيق تأثير على مقطع
  // ====================================================
  Future<void> applyEffectToClip({
    required String clipId,
    required VideoEffect effect,
  }) async {
    final clipIndex = state.timelineState.videoClips
        .indexWhere((c) => c.id == clipId);
    if (clipIndex == -1) return;
    final clip = state.timelineState.videoClips[clipIndex];
    
    // تحقق إذا كان التأثير موجوداً بالفعل وقم بتحديثه
    final existingEffectIndex = clip.effects.indexWhere((e) => e.type == effect.type);
    List<VideoEffect> newEffects;
    
    if (existingEffectIndex >= 0) {
      newEffects = [...clip.effects];
      newEffects[existingEffectIndex] = effect;
    } else {
      newEffects = [...clip.effects, effect];
    }
    
    final updatedClip = clip.copyWith(effects: newEffects);
    final newClips = [...state.timelineState.videoClips];
    newClips[clipIndex] = updatedClip;
    
    final newTimelineState = state.timelineState.copyWith(videoClips: newClips);
    await _undoRedoService.pushState(newTimelineState);
    final historyInfo = _undoRedoService.historyInfo;
    emit(state.copyWith(
      timelineState: newTimelineState,
      canUndo: historyInfo.canUndo,
      canRedo: historyInfo.canRedo,
    ));
  }
  // ====================================================
  // تنفيذ أوامر الذكاء الاصطناعي على التايم لاين
  // تأخذ هذه الدالة قائمة JSON Actions وتطبقها
  // ====================================================
  Future<void> applyAIActions(List<Map<String, dynamic>> actions) async {
    emit(state.copyWith(status: EditorStatus.processing));
    
    TimelineState currentTimeline = state.timelineState;
    
    // تطبيق كل أمر واحداً تلو الآخر
    for (final action in actions) {
      final actionType = action['type'] as String;
      
      switch (actionType) {
        case 'apply_color_grade':
          // تطبيق تصحيح الألوان على كل مقاطع الفيديو
          final parameters = action['parameters'] as Map<String, dynamic>;
          final effect = VideoEffect.create(
            type: EffectType.colorGrade,
            parameters: parameters,
          );
          final updatedClips = currentTimeline.videoClips.map((clip) {
            final existingIdx = clip.effects.indexWhere(
                (e) => e.type == EffectType.colorGrade);
            List<VideoEffect> newEffects;
            if (existingIdx >= 0) {
              newEffects = [...clip.effects];
              newEffects[existingIdx] = effect;
            } else {
              newEffects = [...clip.effects, effect];
            }
            return clip.copyWith(effects: newEffects);
          }).toList();
          currentTimeline = currentTimeline.copyWith(videoClips: updatedClips);
          break;
          
        case 'remove_background':
          // تطبيق إزالة الخلفية على مقطع محدد أو الكل
          final targetClipId = action['clipId'] as String?;
          final effect = VideoEffect.create(
            type: EffectType.backgroundRemoval,
            parameters: action['parameters'] as Map<String, dynamic>? ?? {},
          );
          if (targetClipId != null) {
            final idx = currentTimeline.videoClips
                .indexWhere((c) => c.id == targetClipId);
            if (idx >= 0) {
              final clip = currentTimeline.videoClips[idx];
              final newClips = [...currentTimeline.videoClips];
              newClips[idx] = clip.copyWith(effects: [...clip.effects, effect]);
              currentTimeline = currentTimeline.copyWith(videoClips: newClips);
            }
          }
          break;
          
        case 'add_audio':
          // إضافة مسار صوتي من الذكاء الاصطناعي
          final audioPath = action['audioPath'] as String;
          final startTime = (action['startTime'] as num).toDouble();
          final duration = (action['duration'] as num).toDouble();
          final newAudioClip = AudioClip.create(
            filePath: audioPath,
            startTime: startTime,
            duration: duration,
            audioType: AudioType.music,
          );
          currentTimeline = currentTimeline.copyWith(
            audioClips: [...currentTimeline.audioClips, newAudioClip],
          );
          break;
          
        case 'apply_motion_tracking':
          final clipId = action['clipId'] as String;
          final effect = VideoEffect.create(
            type: EffectType.motionTracking,
            parameters: action['parameters'] as Map<String, dynamic>? ?? {},
          );
          final idx = currentTimeline.videoClips
              .indexWhere((c) => c.id == clipId);
          if (idx >= 0) {
            final clip = currentTimeline.videoClips[idx];
            final newClips = [...currentTimeline.videoClips];
            newClips[idx] = clip.copyWith(effects: [...clip.effects, effect]);
            currentTimeline = currentTimeline.copyWith(videoClips: newClips);
          }
          break;
          
        case 'add_text_caption':
          final text = action['text'] as String;
          final startTime = (action['startTime'] as num).toDouble();
          final duration = (action['duration'] as num?)?.toDouble() ?? 3.0;
          final textLayer = TextLayer.create(
            text: text,
            startTime: startTime,
            duration: duration,
          );
          currentTimeline = currentTimeline.copyWith(
            textLayers: [...currentTimeline.textLayers, textLayer],
          );
          break;
      }
    }
    
    // حفظ الحالة النهائية كخطوة واحدة في Undo
    await _undoRedoService.pushState(currentTimeline);
    final historyInfo = _undoRedoService.historyInfo;
    emit(state.copyWith(
      timelineState: currentTimeline,
      canUndo: historyInfo.canUndo,
      canRedo: historyInfo.canRedo,
      status: EditorStatus.idle,
    ));
  }
  // ====================================================
  // تراجع (Undo)
  // ====================================================
  Future<void> undo() async {
    final previousState = await _undoRedoService.undo();
    if (previousState != null) {
      final historyInfo = _undoRedoService.historyInfo;
      emit(state.copyWith(
        timelineState: previousState,
        canUndo: historyInfo.canUndo,
        canRedo: historyInfo.canRedo,
      ));
    }
  }
  // ====================================================
  // إعادة (Redo)
  // ====================================================
  Future<void> redo() async {
    final nextState = await _undoRedoService.redo();
    if (nextState != null) {
      final historyInfo = _undoRedoService.historyInfo;
      emit(state.copyWith(
        timelineState: nextState,
        canUndo: historyInfo.canUndo,
        canRedo: historyInfo.canRedo,
      ));
    }
  }
  // ====================================================
  // تغيير موضع مؤشر التشغيل
  // ====================================================
  void seekTo(double position) {
    final clampedPosition = position.clamp(
        0.0, state.timelineState.totalDuration);
    emit(state.copyWith(currentPlayheadPosition: clampedPosition));
  }
  // ====================================================
  // تشغيل/إيقاف الفيديو
  // ====================================================
  void togglePlayPause() {
    emit(state.copyWith(isPlaying: !state.isPlaying));
  }
  // ====================================================
  // تغيير تكبير التايم لاين
  // ====================================================
  void setTimelineZoom(double zoom) {
    final clampedZoom = zoom.clamp(0.1, 10.0);
    emit(state.copyWith(timelineZoom: clampedZoom));
  }
  // ====================================================
  // تحديد مقطع
  // ====================================================
  void selectClip(String? clipId) {
    emit(state.copyWith(
      selectedClipId: clipId,
      clearSelectedClip: clipId == null,
    ));
  }
  // ====================================================
  // تغيير الأداة النشطة
  // ====================================================
  void setActiveTool(EditorTool tool) {
    emit(state.copyWith(
      activeTool: tool,
      isAIPanelOpen: tool == EditorTool.aiCommands,
      isAudioPanelOpen: tool == EditorTool.audio,
      isTextPanelOpen: tool == EditorTool.text,
    ));
  }
  // ====================================================
  // دالة مساعدة لحساب المدة الإجمالية
  // ====================================================
  double _calculateTotalDuration(
      List<VideoClip> videoClips, List<AudioClip> audioClips) {
    double maxTime = 0;
    for (final clip in videoClips) {
      if (clip.endTime > maxTime) maxTime = clip.endTime;
    }
    for (final clip in audioClips) {
      if (clip.endTime > maxTime) maxTime = clip.endTime;
    }
    return maxTime;
  }
  @override
  Future<void> close() async {
    await _undoRedoService.clearHistory();
    return super.close();
  }
}
