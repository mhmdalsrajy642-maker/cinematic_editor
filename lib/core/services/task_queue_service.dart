import 'dart:async';
import 'dart:collection';

/// Represents the current status of a queued task.
enum TaskStatus {
  queued,
  running,
  completed,
  failed,
  canceled,
}

/// A single queued background task.
class TaskQueueItem<T> {
  final String id;
  final String description;
  final DateTime createdAt;
  final Completer<T> _completer = Completer<T>();
  DateTime? startedAt;
  DateTime? completedAt;
  TaskStatus status;
  T? result;
  Object? error;
  StackTrace? stackTrace;

  TaskQueueItem({
    required this.id,
    required this.description,
    this.status = TaskStatus.queued,
    this.createdAt = const DateTime.fromMillisecondsSinceEpoch(0),
  }) : createdAt = DateTime.now();

  bool get isActive => status == TaskStatus.queued || status == TaskStatus.running;

  Future<T> get future => _completer.future;

  void complete(T value) {
    if (!_completer.isCompleted) {
      _completer.complete(value);
    }
  }

  void completeError(Object error, StackTrace stackTrace) {
    if (!_completer.isCompleted) {
      _completer.completeError(error, stackTrace);
    }
  }
}

class TaskCanceledException implements Exception {
  final String message;

  TaskCanceledException([this.message = 'Task canceled']);

  @override
  String toString() => 'TaskCanceledException: $message';
}

/// A lightweight queue service for managing background tasks.
class TaskQueueService {
  final Duration _pollInterval;
  final Map<String, TaskQueueItem> _tasks = {};
  final Map<String, Future<dynamic> Function()> _taskActions = {};
  final Queue<String> _pendingQueue = Queue<String>();
  bool _isProcessing = false;

  TaskQueueService({Duration pollInterval = const Duration(milliseconds: 200)})
      : _pollInterval = pollInterval;

  /// Enqueues a new task and returns the task item.
  TaskQueueItem<T> enqueue<T>(
    String id,
    String description,
    Future<T> Function() task,
  ) {
    if (_tasks.containsKey(id)) {
      throw ArgumentError('Task with id $id already exists.');
    }

    final item = TaskQueueItem<T>(
      id: id,
      description: description,
      status: TaskStatus.queued,
    );

    _tasks[id] = item;
    _taskActions[id] = task;
    _pendingQueue.addLast(id);
    if (!_isProcessing) {
      _processQueue();
    }
    return item;
  }

  /// Cancels a queued or running task.
  bool cancel(String id) {
    final item = _tasks[id];
    if (item == null) {
      return false;
    }

    if (item.status == TaskStatus.completed || item.status == TaskStatus.failed) {
      return false;
    }

    final wasQueued = item.status == TaskStatus.queued;
    if (wasQueued) {
      _pendingQueue.remove(id);
    }

    item.status = TaskStatus.canceled;
    item.completedAt = DateTime.now();

    if (wasQueued) {
      item.completeError(
        TaskCanceledException('Task $id was canceled before execution.'),
        StackTrace.current,
      );
    }

    return true;
  }

  /// Retries a failed or canceled task by recreating it with a new task closure.
  TaskQueueItem<T>? retry<T>(
    String id,
    Future<T> Function() task,
  ) {
    final existing = _tasks[id];
    if (existing == null ||
        (existing.status != TaskStatus.failed && existing.status != TaskStatus.canceled)) {
      return null;
    }

    final item = TaskQueueItem<T>(
      id: id,
      description: existing.description,
      status: TaskStatus.queued,
    );

    _tasks[id] = item;
    _taskActions[id] = task;
    _pendingQueue.addLast(id);
    if (!_isProcessing) {
      _processQueue();
    }
    return item;
  }

  /// Clears completed and failed tasks from the queue.
  void clear({bool keepRunning = true}) {
    final completedAndFailed = _tasks.entries.where((entry) {
      final status = entry.value.status;
      return status == TaskStatus.completed || status == TaskStatus.failed || status == TaskStatus.canceled;
    }).map((entry) => entry.key).toList();

    for (final id in completedAndFailed) {
      _tasks.remove(id);
    }

    if (!keepRunning) {
      for (final entry in _tasks.values.where((item) => item.status == TaskStatus.running)) {
        entry.status = TaskStatus.canceled;
        entry.completedAt = DateTime.now();
      }
      _pendingQueue.clear();
    }
  }

  /// Gets a snapshot of all current tasks.
  List<TaskQueueItem> get tasks => List.unmodifiable(_tasks.values);

  /// Gets all queued task items.
  List<TaskQueueItem> get queuedTasks =>
      _tasks.values.where((item) => item.status == TaskStatus.queued).toList();

  /// Gets all running task items.
  List<TaskQueueItem> get runningTasks =>
      _tasks.values.where((item) => item.status == TaskStatus.running).toList();

  /// Gets all completed task items.
  List<TaskQueueItem> get completedTasks =>
      _tasks.values.where((item) => item.status == TaskStatus.completed).toList();

  /// Gets all failed task items.
  List<TaskQueueItem> get failedTasks =>
      _tasks.values.where((item) => item.status == TaskStatus.failed).toList();

  void _processQueue() {
    if (_isProcessing) {
      return;
    }

    _isProcessing = true;
    Future<void>.delayed(_pollInterval, () async {
      while (_pendingQueue.isNotEmpty) {
        final id = _pendingQueue.removeFirst();
        final item = _tasks[id];
        if (item == null || item.status != TaskStatus.queued) {
          continue;
        }

        final task = _taskActions[id];
        if (task == null) {
          item.status = TaskStatus.failed;
          item.error = StateError('Missing task action for id $id');
          item.completedAt = DateTime.now();
          continue;
        }

        item.status = TaskStatus.running;
        item.startedAt = DateTime.now();

        try {
          final result = await task();
          if (item.status == TaskStatus.canceled) {
            item.error = TaskCanceledException('Task $id was canceled during execution.');
            item.stackTrace = StackTrace.current;
            item.completedAt = DateTime.now();
            item.completeError(item.error!, item.stackTrace!);
          } else {
            item.result = result;
            item.status = TaskStatus.completed;
            item.completedAt = DateTime.now();
            item.complete(result);
          }
        } catch (error, stackTrace) {
          if (item.status == TaskStatus.canceled) {
            item.error = TaskCanceledException('Task $id was canceled during execution.');
            item.stackTrace = StackTrace.current;
            item.status = TaskStatus.canceled;
            item.completedAt = DateTime.now();
            item.completeError(item.error!, item.stackTrace!);
          } else {
            item.error = error;
            item.stackTrace = stackTrace;
            item.status = TaskStatus.failed;
            item.completedAt = DateTime.now();
            item.completeError(error, stackTrace);
          }
        } finally {
          _taskActions.remove(id);
        }
      }
      _isProcessing = false;
    });
  }
}
