import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../subscription/services/device_security_service.dart';
import '../../../core/models/timeline_models.dart';
import '../domain/export_queue_service.dart';
import '../domain/ffmpeg_command_builder.dart';

part 'export_state.dart';

class ExportCubit extends Cubit<ExportState> {
  final ExportQueueService _queueService;
  final DeviceSecurityService _securityService;
  StreamSubscription<ExportJob>? _jobSubscription;

  ExportCubit({
    required ExportQueueService queueService,
    required DeviceSecurityService securityService,
  })  : _queueService = queueService,
        _securityService = securityService,
        super(const ExportState.initial());

  Future<void> startExport({
    required TimelineState timelineState,
    required ExportProfile profile,
    required bool hasSubscription,
  }) async {
    if (state.status == ExportStatus.exporting) return;
    emit(state.copyWith(status: ExportStatus.checkingPermission));

    final permission = await _securityService.checkExportPermission(
      resolution: profile.resolutionName,
      hasSubscription: hasSubscription,
    );
    if (!permission.isAllowed) {
      emit(state.copyWith(
        status: ExportStatus.permissionDenied,
        errorMessage: permission.denialReason,
        permission: permission,
      ));
      return;
    }

    emit(state.copyWith(status: ExportStatus.queued, permission: permission));

    final job = await _queueService.enqueueExport(
      timelineState,
      profile,
      hasSubscription,
    );

    _jobSubscription?.cancel();
    _jobSubscription = _queueService.updates.listen((updatedJob) {
      if (updatedJob.id != job.id) return;
      emit(state.copyWith(
        status: _statusFromJob(updatedJob.status),
        progress: updatedJob.progress,
        outputPath: updatedJob.outputPath,
        errorMessage: updatedJob.errorMessage,
      ));
    });

    emit(state.copyWith(status: ExportStatus.exporting, progress: 0.0));

    final result = await job.result.future;
    if (result.success) {
      emit(state.copyWith(
        status: ExportStatus.completed,
        progress: 1.0,
        outputPath: result.outputPath,
      ));
    } else if (result.cancelled) {
      emit(state.copyWith(
        status: ExportStatus.cancelled,
        errorMessage: result.errorMessage,
      ));
    } else {
      emit(state.copyWith(
        status: ExportStatus.failed,
        errorMessage: result.errorMessage,
      ));
    }
  }

  Future<void> cancelExport() async {
    if (state.status != ExportStatus.exporting) return;
    await _queueService.cancelAll();
    emit(state.copyWith(status: ExportStatus.cancelled));
  }

  ExportStatus _statusFromJob(ExportJobStatus jobStatus) {
    switch (jobStatus) {
      case ExportJobStatus.queued:
        return ExportStatus.queued;
      case ExportJobStatus.running:
        return ExportStatus.exporting;
      case ExportJobStatus.completed:
        return ExportStatus.completed;
      case ExportJobStatus.failed:
        return ExportStatus.failed;
      case ExportJobStatus.cancelled:
        return ExportStatus.cancelled;
    }
  }

  @override
  Future<void> close() async {
    await _jobSubscription?.cancel();
    return super.close();
  }
}
