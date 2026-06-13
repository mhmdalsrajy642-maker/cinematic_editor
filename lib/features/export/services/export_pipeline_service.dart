import 'dart:async';

import 'package:uuid/uuid.dart';

import '../models/export_pipeline_models.dart' as pipeline_models;
import '../domain/export_service.dart';
import '../domain/ffmpeg_command_builder.dart';
import '../../../core/models/timeline_models.dart';

class ExportPipelineService {
  final ExportService _exportService;

  ExportPipelineService({required ExportService exportService})
      : _exportService = exportService;

  Future<ExportResult> exportTimeline(
    TimelineState timeline,
    ExportProfile profile, {
    required bool hasSubscription,
    void Function(double)? onProgress,
  }) async {
    final job = _buildExportJob(timeline, profile);

    onProgress?.call(0.0);
    final preparingJob = job.copyWith(
      currentStage: pipeline_models.ExportStage.preparing,
      startedAt: DateTime.now(),
    );
    onProgress?.call(0.10);

    await _prepare(preparingJob);

    final exportingJob = preparingJob.copyWith(currentStage: pipeline_models.ExportStage.exporting);
    onProgress?.call(0.20);

    final result = await _exportService.exportTimeline(
      timeline,
      profile,
      hasSubscription: hasSubscription,
      onProgress: (progress) {
        final mappedProgress = 0.20 + (progress * 0.70);
        onProgress?.call(mappedProgress.clamp(0.0, 0.90));
      },
    );

    if (result.cancelled) {
      exportingJob.copyWith(currentStage: pipeline_models.ExportStage.canceled);
      onProgress?.call(1.0);
      return result;
    }

    if (!result.success) {
      exportingJob.copyWith(currentStage: pipeline_models.ExportStage.failed);
      onProgress?.call(1.0);
      return result;
    }

    exportingJob.copyWith(
      currentStage: pipeline_models.ExportStage.completed,
      outputPath: result.outputPath,
      completedAt: DateTime.now(),
    );
    onProgress?.call(1.0);
    return result;
  }

  Future<void> _prepare(pipeline_models.ExportJob job) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  pipeline_models.ExportJob _buildExportJob(
    TimelineState timeline,
    ExportProfile profile,
  ) {
    final outputFileName =
        '${timeline.projectId}_${profile.resolutionName}_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final outputPath = 'exports/$outputFileName';

    return pipeline_models.ExportJob(
      id: const Uuid().v4(),
      sourceProjectId: timeline.projectId,
      outputPath: outputPath,
      currentStage: pipeline_models.ExportStage.queued,
      createdAt: DateTime.now(),
    );
  }
}
