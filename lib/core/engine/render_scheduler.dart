import 'dart:async';

import 'frame_compositor.dart';

/// A cancellable token for scheduled render work.
class RenderScheduleToken {
  final String id;
  final Completer<void> _cancelCompleter = Completer<void>();

  RenderScheduleToken(this.id);

  bool get isCancelled => _cancelCompleter.isCompleted;

  Future<void> cancel() async {
    if (!isCancelled) {
      _cancelCompleter.complete();
    }
  }

  Future<void> get cancelled => _cancelCompleter.future;
}

class _RenderJob {
  final RenderScheduleToken token;
  final Future<RenderFrame> Function() task;
  final Completer<RenderFrame> completer;

  _RenderJob({
    required this.token,
    required this.task,
    required this.completer,
  });
}

/// Scheduler for preview render tasks with cancellation support.
class RenderScheduler {
  final Map<String, _RenderJob> _pendingJobs = {};
  bool _isProcessing = false;

  Future<RenderFrame> scheduleRender(
    Future<RenderFrame> Function() task,
  ) async {
    final token = RenderScheduleToken(DateTime.now().microsecondsSinceEpoch.toString());
    final completer = Completer<RenderFrame>();
    final job = _RenderJob(token: token, task: task, completer: completer);
    _pendingJobs[token.id] = job;

    _processQueue();
    return completer.future;
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    while (_pendingJobs.isNotEmpty) {
      final job = _pendingJobs.values.first;
      _pendingJobs.remove(job.token.id);
      if (job.token.isCancelled) {
        job.completer.completeError(Exception('Render cancelled'));
        continue;
      }
      try {
        final frame = await job.task();
        if (job.token.isCancelled) {
          job.completer.completeError(Exception('Render cancelled'));
        } else {
          job.completer.complete(frame);
        }
      } catch (error) {
        if (!job.completer.isCompleted) {
          job.completer.completeError(error);
        }
      }
    }

    _isProcessing = false;
  }

  Future<bool> cancel(String requestId) async {
    final job = _pendingJobs.remove(requestId);
    if (job == null) return false;
    await job.token.cancel();
    if (!job.completer.isCompleted) {
      job.completer.completeError(Exception('Render cancelled'));
    }
    return true;
  }

  Future<void> cancelAll() async {
    final jobs = _pendingJobs.values.toList();
    _pendingJobs.clear();
    for (final job in jobs) {
      if (!job.token.isCancelled) {
        await job.token.cancel();
      }
      if (!job.completer.isCompleted) {
        job.completer.completeError(Exception('Render cancelled'));
      }
    }
  }
}
