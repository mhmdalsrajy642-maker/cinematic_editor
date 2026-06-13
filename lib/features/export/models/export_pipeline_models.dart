import 'package:flutter/foundation.dart';

/// Lifecycle stages for an export job.
enum ExportStage {
  queued,
  preparing,
  exporting,
  finalizing,
  completed,
  failed,
  canceled,
}

/// Tracks progress information for an export job.
class ExportProgress {
  final String jobId;
  final ExportStage stage;
  final double percentComplete;
  final Duration elapsed;
  final String? detail;

  const ExportProgress({
    required this.jobId,
    required this.stage,
    this.percentComplete = 0.0,
    this.elapsed = Duration.zero,
    this.detail,
  });

  ExportProgress copyWith({
    String? jobId,
    ExportStage? stage,
    double? percentComplete,
    Duration? elapsed,
    String? detail,
  }) {
    return ExportProgress(
      jobId: jobId ?? this.jobId,
      stage: stage ?? this.stage,
      percentComplete: percentComplete ?? this.percentComplete,
      elapsed: elapsed ?? this.elapsed,
      detail: detail ?? this.detail,
    );
  }
}

/// Represents a single export job in the pipeline.
class ExportJob {
  final String id;
  final String sourceProjectId;
  final String outputPath;
  final ExportStage currentStage;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const ExportJob({
    required this.id,
    required this.sourceProjectId,
    required this.outputPath,
    this.currentStage = ExportStage.queued,
    DateTime? createdAt,
    this.startedAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  ExportJob copyWith({
    String? id,
    String? sourceProjectId,
    String? outputPath,
    ExportStage? currentStage,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return ExportJob(
      id: id ?? this.id,
      sourceProjectId: sourceProjectId ?? this.sourceProjectId,
      outputPath: outputPath ?? this.outputPath,
      currentStage: currentStage ?? this.currentStage,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

/// Final result of an export operation.
class ExportResult {
  final String jobId;
  final bool success;
  final ExportStage stage;
  final String? outputPath;
  final String? errorMessage;

  const ExportResult({
    required this.jobId,
    required this.success,
    required this.stage,
    this.outputPath,
    this.errorMessage,
  });

  factory ExportResult.success({
    required String jobId,
    required String outputPath,
  }) {
    return ExportResult(
      jobId: jobId,
      success: true,
      stage: ExportStage.completed,
      outputPath: outputPath,
    );
  }

  factory ExportResult.failure({
    required String jobId,
    required String errorMessage,
    ExportStage stage = ExportStage.failed,
  }) {
    return ExportResult(
      jobId: jobId,
      success: false,
      stage: stage,
      errorMessage: errorMessage,
    );
  }
}
