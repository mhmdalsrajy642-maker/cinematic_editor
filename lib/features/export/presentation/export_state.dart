part of 'export_cubit.dart';

enum ExportStatus {
  idle,
  checkingPermission,
  permissionDenied,
  queued,
  exporting,
  completed,
  failed,
  cancelled,
}

class ExportState extends Equatable {
  final ExportStatus status;
  final double progress;
  final String? outputPath;
  final String? errorMessage;
  final ExportPermission? permission;

  const ExportState({
    required this.status,
    required this.progress,
    this.outputPath,
    this.errorMessage,
    this.permission,
  });

  const ExportState.initial()
      : status = ExportStatus.idle,
        progress = 0.0,
        outputPath = null,
        errorMessage = null,
        permission = null;

  ExportState copyWith({
    ExportStatus? status,
    double? progress,
    String? outputPath,
    String? errorMessage,
    ExportPermission? permission,
  }) {
    return ExportState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      outputPath: outputPath ?? this.outputPath,
      errorMessage: errorMessage ?? this.errorMessage,
      permission: permission ?? this.permission,
    );
  }

  @override
  List<Object?> get props => [status, progress, outputPath, errorMessage, permission];
}
