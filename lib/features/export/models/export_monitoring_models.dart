// lib/features/export/models/export_monitoring_models.dart

import 'package:equatable/equatable.dart';

class ExportMetrics extends Equatable {
  final Duration totalDuration;
  final int frameCount;
  final int audioSamples;
  final int outputSizeBytes;
  final double averageFps;

  const ExportMetrics({
    required this.totalDuration,
    required this.frameCount,
    required this.audioSamples,
    required this.outputSizeBytes,
    required this.averageFps,
  });

  ExportMetrics copyWith({
    Duration? totalDuration,
    int? frameCount,
    int? audioSamples,
    int? outputSizeBytes,
    double? averageFps,
  }) {
    return ExportMetrics(
      totalDuration: totalDuration ?? this.totalDuration,
      frameCount: frameCount ?? this.frameCount,
      audioSamples: audioSamples ?? this.audioSamples,
      outputSizeBytes: outputSizeBytes ?? this.outputSizeBytes,
      averageFps: averageFps ?? this.averageFps,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalDurationMs': totalDuration.inMilliseconds,
      'frameCount': frameCount,
      'audioSamples': audioSamples,
      'outputSizeBytes': outputSizeBytes,
      'averageFps': averageFps,
    };
  }

  factory ExportMetrics.fromJson(Map<String, dynamic> json) {
    return ExportMetrics(
      totalDuration: Duration(milliseconds: json['totalDurationMs'] as int),
      frameCount: json['frameCount'] as int,
      audioSamples: json['audioSamples'] as int,
      outputSizeBytes: json['outputSizeBytes'] as int,
      averageFps: (json['averageFps'] as num).toDouble(),
    );
  }

  @override
  List<Object?> get props => [totalDuration, frameCount, audioSamples, outputSizeBytes, averageFps];
}

class ExportPerformance extends Equatable {
  final double cpuUsage;
  final double memoryUsageMb;
  final double gpuUsage;
  final double diskWriteMbPerSec;
  final double exportProgress;

  const ExportPerformance({
    required this.cpuUsage,
    required this.memoryUsageMb,
    required this.gpuUsage,
    required this.diskWriteMbPerSec,
    required this.exportProgress,
  });

  ExportPerformance copyWith({
    double? cpuUsage,
    double? memoryUsageMb,
    double? gpuUsage,
    double? diskWriteMbPerSec,
    double? exportProgress,
  }) {
    return ExportPerformance(
      cpuUsage: cpuUsage ?? this.cpuUsage,
      memoryUsageMb: memoryUsageMb ?? this.memoryUsageMb,
      gpuUsage: gpuUsage ?? this.gpuUsage,
      diskWriteMbPerSec: diskWriteMbPerSec ?? this.diskWriteMbPerSec,
      exportProgress: exportProgress ?? this.exportProgress,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cpuUsage': cpuUsage,
      'memoryUsageMb': memoryUsageMb,
      'gpuUsage': gpuUsage,
      'diskWriteMbPerSec': diskWriteMbPerSec,
      'exportProgress': exportProgress,
    };
  }

  factory ExportPerformance.fromJson(Map<String, dynamic> json) {
    return ExportPerformance(
      cpuUsage: (json['cpuUsage'] as num).toDouble(),
      memoryUsageMb: (json['memoryUsageMb'] as num).toDouble(),
      gpuUsage: (json['gpuUsage'] as num).toDouble(),
      diskWriteMbPerSec: (json['diskWriteMbPerSec'] as num).toDouble(),
      exportProgress: (json['exportProgress'] as num).toDouble(),
    );
  }

  @override
  List<Object?> get props => [cpuUsage, memoryUsageMb, gpuUsage, diskWriteMbPerSec, exportProgress];
}

class ExportError extends Equatable {
  final String code;
  final String message;
  final DateTime occurredAt;
  final String? stackTrace;

  const ExportError({
    required this.code,
    required this.message,
    required this.occurredAt,
    this.stackTrace,
  });

  ExportError copyWith({
    String? code,
    String? message,
    DateTime? occurredAt,
    String? stackTrace,
  }) {
    return ExportError(
      code: code ?? this.code,
      message: message ?? this.message,
      occurredAt: occurredAt ?? this.occurredAt,
      stackTrace: stackTrace ?? this.stackTrace,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      'occurredAt': occurredAt.toIso8601String(),
      'stackTrace': stackTrace,
    };
  }

  factory ExportError.fromJson(Map<String, dynamic> json) {
    return ExportError(
      code: json['code'] as String,
      message: json['message'] as String,
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      stackTrace: json['stackTrace'] as String?,
    );
  }

  @override
  List<Object?> get props => [code, message, occurredAt, stackTrace];
}

class ExportSession extends Equatable {
  final String sessionId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final ExportMetrics metrics;
  final ExportPerformance performance;
  final List<ExportError> errors;
  final bool completed;

  const ExportSession({
    required this.sessionId,
    required this.startedAt,
    this.endedAt,
    required this.metrics,
    required this.performance,
    this.errors = const [],
    this.completed = false,
  });

  ExportSession copyWith({
    String? sessionId,
    DateTime? startedAt,
    DateTime? endedAt,
    ExportMetrics? metrics,
    ExportPerformance? performance,
    List<ExportError>? errors,
    bool? completed,
  }) {
    return ExportSession(
      sessionId: sessionId ?? this.sessionId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      metrics: metrics ?? this.metrics,
      performance: performance ?? this.performance,
      errors: errors ?? this.errors,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'metrics': metrics.toJson(),
      'performance': performance.toJson(),
      'errors': errors.map((error) => error.toJson()).toList(),
      'completed': completed,
    };
  }

  factory ExportSession.fromJson(Map<String, dynamic> json) {
    return ExportSession(
      sessionId: json['sessionId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] == null ? null : DateTime.parse(json['endedAt'] as String),
      metrics: ExportMetrics.fromJson(json['metrics'] as Map<String, dynamic>),
      performance: ExportPerformance.fromJson(json['performance'] as Map<String, dynamic>),
      errors: (json['errors'] as List<dynamic>)
          .map((errorJson) => ExportError.fromJson(errorJson as Map<String, dynamic>))
          .toList(),
      completed: json['completed'] as bool,
    );
  }

  @override
  List<Object?> get props => [sessionId, startedAt, endedAt, metrics, performance, errors, completed];
}
