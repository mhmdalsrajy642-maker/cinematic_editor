import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../../core/models/timeline_models.dart';
import 'export_service.dart';
import 'ffmpeg_command_builder.dart';

enum ExportJobStatus { queued, running, completed, failed, cancelled }

class ExportJob {
  final String id;
  final TimelineState timelineState;
  final ExportProfile profile;
  final bool hasSubscription;
  ExportJobStatus status;
  double progress;
  String? outputPath;
  String? errorMessage;
  final Completer<ExportResult> result;

  ExportJob({
    required this.timelineState,
    required this.profile,
    required this.hasSubscription,
  })  : id = const Uuid().v4(),
        status = ExportJobStatus.queued,
        progress = 0.0,
        result = Completer<ExportResult>();
}

class ExportQueueService {
  final ExportService _exportService;
  final List<ExportJob> _queue = [];
  ExportJob? _activeJob;
  final StreamController<ExportJob> _updates = StreamController.broadcast();
  bool _isProcessing = false;

  ExportQueueService({required ExportService exportService})
      : _exportService = exportService;

  Stream<ExportJob> get updates => _updates.stream;

  Future<ExportJob> enqueueExport(
    TimelineState timelineState,
    ExportProfile profile,
    bool hasSubscription,
  ) async {
    final job = ExportJob(
      timelineState: timelineState,
      profile: profile,
      hasSubscription: hasSubscription,
    );
    _queue.add(job);
    _updates.add(job);
    _processQueue();
    return job;
  }

  Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;
    _isProcessing = true;

    while (_queue.isNotEmpty) {
      final job = _queue.removeAt(0);
      _activeJob = job;
      job.status = ExportJobStatus.running;
      _updates.add(job);

      final result = await _exportService.exportTimeline(
        job.timelineState,
        job.profile,
        hasSubscription: job.hasSubscription,
        onProgress: (progress) {
          job.progress = progress;
          _updates.add(job);
        },
      );

      job.outputPath = result.outputPath;
      job.progress = result.progress;
      if (result.cancelled) {
        job.status = ExportJobStatus.cancelled;
        job.errorMessage = result.errorMessage;
      } else if (result.success) {
        job.status = ExportJobStatus.completed;
      } else {
        job.status = ExportJobStatus.failed;
        job.errorMessage = result.errorMessage;
      }

      job.result.complete(result);
      _updates.add(job);
      _activeJob = null;
    }

    _isProcessing = false;
  }

  Future<bool> cancelJob(String jobId) async {
    if (_activeJob?.id == jobId) {
      await _exportService.cancelExport();
      _activeJob?.status = ExportJobStatus.cancelled;
      _activeJob?.errorMessage = 'Export cancelled by user';
      _activeJob?.progress = 0.0;
      _activeJob?.result.complete(ExportResult(
        success: false,
        outputPath: _activeJob?.outputPath ?? '',
        progress: 0.0,
        cancelled: true,
        errorMessage: 'Cancelled',
      ));
      _updates.add(_activeJob!);
      _activeJob = null;
      return true;
    }

    final index = _queue.indexWhere((item) => item.id == jobId);
    if (index >= 0) {
      _queue.removeAt(index);
      return true;
    }
    return false;
  }

  Future<void> cancelAll() async {
    if (_activeJob != null) {
      await _exportService.cancelExport();
      _activeJob?.status = ExportJobStatus.cancelled;
      _activeJob?.errorMessage = 'Cancelled';
      _activeJob?.progress = 0.0;
      _activeJob?.result.complete(ExportResult(
        success: false,
        outputPath: _activeJob?.outputPath ?? '',
        progress: 0.0,
        cancelled: true,
        errorMessage: 'Cancelled',
      ));
      _updates.add(_activeJob!);
      _activeJob = null;
    }
    _queue.clear();
  }

  Future<List<ExportJob>> pendingJobs() async {
    return [..._queue];
  }
}
