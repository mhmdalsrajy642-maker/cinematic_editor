import 'dart:async';
import 'dart:io';

import '../engine/native_bridge.dart';
import 'task_queue_service.dart';

/// The request payload for proxy generation.
class ProxyGenerationRequest {
  final String requestId;
  final String sourcePath;
  final String targetPath;
  final int width;
  final int bitrateKbps;
  final bool keepAudio;
  final Map<String, dynamic>? metadata;

  const ProxyGenerationRequest({
    required this.requestId,
    required this.sourcePath,
    required this.targetPath,
    this.width = 360,
    this.bitrateKbps = 800,
    this.keepAudio = true,
    this.metadata,
  });
}

/// The result of a proxy generation operation.
class ProxyGenerationResult {
  final bool success;
  final ProxyGenerationStatus status;
  final String requestId;
  final String? proxyPath;
  final String? message;
  final VideoMetadata? sourceMetadata;
  final NativeEngineError? error;

  const ProxyGenerationResult({
    required this.success,
    required this.status,
    required this.requestId,
    this.proxyPath,
    this.message,
    this.sourceMetadata,
    this.error,
  });

  factory ProxyGenerationResult.success({
    required String requestId,
    String? proxyPath,
    String? message,
    VideoMetadata? sourceMetadata,
  }) {
    return ProxyGenerationResult(
      success: true,
      status: ProxyGenerationStatus.completed,
      requestId: requestId,
      proxyPath: proxyPath,
      message: message,
      sourceMetadata: sourceMetadata,
    );
  }

  factory ProxyGenerationResult.failure({
    required String requestId,
    required String message,
    NativeEngineError? error,
    ProxyGenerationStatus status = ProxyGenerationStatus.failed,
  }) {
    return ProxyGenerationResult(
      success: false,
      status: status,
      requestId: requestId,
      message: message,
      error: error,
    );
  }
}

/// Status lifecycle for proxy generation.
enum ProxyGenerationStatus {
  idle,
  validating,
  generating,
  completed,
  failed,
  canceled,
}

/// Service responsible for proxy generation orchestration.
///
/// This architecture uses the existing native bridge and FFmpeg abstraction
/// interfaces, but does not execute actual FFmpeg commands.
class ProxyGenerationService {
  final TaskQueueService _taskQueueService;
  final Map<String, bool> _cancellationTokens = {};

  ProxyGenerationService({TaskQueueService? taskQueueService})
      : _taskQueueService = taskQueueService ?? TaskQueueService();

  /// Generates a proxy video for the provided request.
  Future<ProxyGenerationResult> generateProxy(
    ProxyGenerationRequest request,
  ) {
    _cancellationTokens[request.requestId] = false;

    final taskItem = _taskQueueService.enqueue<ProxyGenerationResult>(
      request.requestId,
      'Generate proxy for ${request.sourcePath}',
      () => _executeProxyGeneration(request),
    );

    return taskItem.future;
  }

  Future<ProxyGenerationResult> _executeProxyGeneration(
    ProxyGenerationRequest request,
  ) async {
    final engineInit = NativeBridge.initializeEngine();
    if (!engineInit.success) {
      return ProxyGenerationResult.failure(
        requestId: request.requestId,
        message: engineInit.errorMessage ?? 'Failed to initialize native engine',
        status: ProxyGenerationStatus.failed,
      );
    }

    final validation = await validateProxy(request.sourcePath);
    if (!validation.success) {
      NativeBridge.shutdownEngine();
      return ProxyGenerationResult.failure(
        requestId: request.requestId,
        message: validation.message ?? 'Source validation failed',
        error: validation.error,
        status: ProxyGenerationStatus.failed,
      );
    }

    if (_isCanceled(request.requestId)) {
      NativeBridge.shutdownEngine();
      return ProxyGenerationResult.failure(
        requestId: request.requestId,
        message: 'Proxy generation canceled before start',
        status: ProxyGenerationStatus.canceled,
      );
    }

    final sourceMetadata = validation.sourceMetadata;
    final exportResult = NativeBridge.exportProject(
      request.sourcePath,
      request.targetPath,
      0,
    );

    if (!exportResult.success) {
      NativeBridge.shutdownEngine();
      return ProxyGenerationResult.failure(
        requestId: request.requestId,
        message: exportResult.errorMessage ?? 'Proxy generation failed',
        error: exportResult.errorMessage != null
            ? NativeEngineError(code: exportResult.errorCode, message: exportResult.errorMessage!)
            : null,
        status: ProxyGenerationStatus.failed,
      );
    }

    if (_isCanceled(request.requestId)) {
      NativeBridge.shutdownEngine();
      return ProxyGenerationResult.failure(
        requestId: request.requestId,
        message: 'Proxy generation canceled',
        status: ProxyGenerationStatus.canceled,
      );
    }

    final proxyFile = File(request.targetPath);
    if (!proxyFile.existsSync()) {
      await proxyFile.create(recursive: true);
    }

    NativeBridge.shutdownEngine();
    return ProxyGenerationResult.success(
      requestId: request.requestId,
      proxyPath: request.targetPath,
      message: 'Proxy generation completed',
      sourceMetadata: sourceMetadata,
    );
  }

  /// Cancels a pending proxy generation request.
  Future<bool> cancelGeneration(String requestId) async {
    if (!_cancellationTokens.containsKey(requestId)) {
      return false;
    }

    _cancellationTokens[requestId] = true;
    return true;
  }

  /// Deletes the generated proxy file from disk.
  Future<bool> deleteProxy(String proxyPath) async {
    if (proxyPath.isEmpty) {
      return false;
    }

    try {
      final file = File(proxyPath);
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Validates a proxy source path using the native FFmpeg metadata bridge.
  Future<ProxyGenerationResult> validateProxy(String sourcePath) async {
    if (sourcePath.isEmpty) {
      return ProxyGenerationResult.failure(
        requestId: 'validation',
        message: 'Source path is empty',
        status: ProxyGenerationStatus.failed,
      );
    }

    final metadataResult = NativeBridge.getVideoMetadata(sourcePath);
    if (!metadataResult.success || metadataResult.data == null) {
      return ProxyGenerationResult.failure(
        requestId: 'validation',
        message: metadataResult.errorMessage ?? 'Unable to validate source',
        error: metadataResult.data == null
            ? NativeEngineError(code: -1, message: metadataResult.errorMessage ?? 'Unknown error')
            : null,
        status: ProxyGenerationStatus.failed,
      );
    }

    return ProxyGenerationResult(
      success: true,
      status: ProxyGenerationStatus.validating,
      requestId: 'validation',
      proxyPath: sourcePath,
      sourceMetadata: metadataResult.data,
      message: 'Source validated successfully',
    );
  }

  bool _isCanceled(String requestId) {
    return _cancellationTokens[requestId] ?? false;
  }
}
