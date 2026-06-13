import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/background_removal_service.dart';
import '../../services/inference_pipeline_service.dart';
import '../../services/model_download_service.dart';
import '../../../../core/models/timeline_models.dart';
import 'ai_state.dart';

/// Cubit responsible for executing AI commands through the inference pipeline.
class AICubit extends Cubit<AIState> {
  final InferencePipelineService _pipelineService;
  final BackgroundRemovalService? _backgroundRemovalService;
  final ModelDownloadService? _modelDownloadService;
  final TimelineState _timelineState;

  AICubit({
    required InferencePipelineService inferencePipelineService,
    BackgroundRemovalService? backgroundRemovalService,
    ModelDownloadService? modelDownloadService,
    TimelineState? timelineState,
  })  : _pipelineService = inferencePipelineService,
        _backgroundRemovalService = backgroundRemovalService,
        _modelDownloadService = modelDownloadService,
        _timelineState = timelineState ?? TimelineState.empty('ai_cubit'),
        super(const AIInitial());

  Future<void> executeCommand(
    String command, {
    required TimelineState timelineState,
  }) async {
    if (command.trim().isEmpty) return;
    final effectiveTimeline = timelineState;

    emit(const AIProcessing(
      status: AIInferenceStatus.parsingCommand,
      currentAction: 0,
      totalActions: 1,
      detail: 'Starting AI command',
    ));

    try {
      if (!_pipelineService.isInitialized) {
        await _pipelineService.initialize();
      }
      final results = await _pipelineService.executeCommand(
        command: command,
        timelineState: effectiveTimeline,
        onProgress: (progress) {
          if (progress.status == AIInferenceStatus.loadingModel ||
              progress.status == AIInferenceStatus.downloadingModel) {
            emit(AIModelDownloading(
              status: progress.status,
              currentAction: progress.currentAction,
              totalActions: progress.totalActions,
              detail: progress.detail,
              modelName: progress.detail,
            ));
            return;
          }

          emit(AIProcessing(
            status: progress.status,
            currentAction: progress.currentAction,
            totalActions: progress.totalActions,
            detail: progress.detail,
          ));
        },
      );

      final failedResults = results.where((result) => !result.isSuccess).toList();
      if (failedResults.isNotEmpty) {
        emit(AIError(
          status: AIInferenceStatus.failed,
          currentAction: results.length,
          totalActions: results.length,
          detail: 'AI command completed with errors',
          results: results,
          errorMessage:
              failedResults.map((r) => r.errorMessage).whereType<String>().join('; '),
        ));
        return;
      }

      emit(AICompleted(
        status: AIInferenceStatus.completed,
        currentAction: results.length,
        totalActions: results.length,
        detail: 'AI command completed successfully',
        results: results,
      ));
    } catch (error) {
      emit(AIError(
        status: AIInferenceStatus.failed,
        currentAction: 0,
        totalActions: 1,
        detail: 'AI command execution failed',
        errorMessage: error.toString(),
      ));
    }
  }
}
