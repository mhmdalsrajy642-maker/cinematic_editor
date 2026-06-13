import 'dart:async';

import 'caption_provider.dart';

/// Defines the payload for an auto caption request.
class CaptionRequest {
  final String requestId;
  final String audioSource;
  final String languageCode;
  final bool includeTimestamps;
  final Map<String, dynamic>? metadata;

  const CaptionRequest({
    required this.requestId,
    required this.audioSource,
    this.languageCode = 'en-US',
    this.includeTimestamps = true,
    this.metadata,
  });
}

/// Represents a single caption segment in a transcript.
class CaptionSegment {
  final double startTime;
  final double endTime;
  final String text;
  final double confidence;

  const CaptionSegment({
    required this.startTime,
    required this.endTime,
    required this.text,
    this.confidence = 0.0,
  });
}

/// Result object returned by auto caption generation.
class CaptionResult {
  final bool success;
  final CaptionStatus status;
  final String requestId;
  final String? transcript;
  final List<CaptionSegment>? segments;
  final String? message;
  final Object? error;

  const CaptionResult({
    required this.success,
    required this.status,
    required this.requestId,
    this.transcript,
    this.segments,
    this.message,
    this.error,
  });

  factory CaptionResult.success({
    required String requestId,
    String? transcript,
    List<CaptionSegment>? segments,
    String? message,
  }) {
    return CaptionResult(
      success: true,
      status: CaptionStatus.completed,
      requestId: requestId,
      transcript: transcript,
      segments: segments,
      message: message,
    );
  }

  factory CaptionResult.failure({
    required String requestId,
    required String message,
    CaptionStatus status = CaptionStatus.failed,
    Object? error,
  }) {
    return CaptionResult(
      success: false,
      status: status,
      requestId: requestId,
      message: message,
      error: error,
    );
  }
}

/// Status lifecycle for auto caption generation.
enum CaptionStatus {
  idle,
  validating,
  generating,
  completed,
  failed,
  canceled,
}

/// Service responsible for auto caption generation orchestration.
class AutoCaptionService {
  final CaptionProvider _provider;
  final Map<String, bool> _cancellationTokens = {};

  AutoCaptionService({CaptionProvider? provider})
      : _provider = provider ?? const LocalCaptionProvider();

  /// Initialize provider dependencies.
  Future<void> initialize() async {
    await _provider.initialize();
  }

  /// Shutdown provider dependencies.
  Future<void> shutdown() async {
    await _provider.shutdown();
  }

  /// Starts caption generation for the provided request.
  Future<CaptionResult> generateCaptions(CaptionRequest request) async {
    _cancellationTokens[request.requestId] = false;

    final validation = await validateCaptions(request);
    if (!validation.success) {
      return validation;
    }

    if (_isCanceled(request.requestId)) {
      return CaptionResult.failure(
        requestId: request.requestId,
        message: 'Caption generation canceled before start',
        status: CaptionStatus.canceled,
      );
    }

    final providerResult = await _provider.generate(request);
    if (_isCanceled(request.requestId)) {
      return CaptionResult.failure(
        requestId: request.requestId,
        message: 'Caption generation was canceled',
        status: CaptionStatus.canceled,
      );
    }

    return providerResult;
  }

  /// Cancels an in-progress or queued caption generation request.
  Future<bool> cancelGeneration(String requestId) async {
    if (!_cancellationTokens.containsKey(requestId)) {
      return false;
    }

    _cancellationTokens[requestId] = true;
    return true;
  }

  /// Validates that the caption request is well formed.
  Future<CaptionResult> validateCaptions(CaptionRequest request) async {
    if (request.audioSource.isEmpty) {
      return CaptionResult.failure(
        requestId: request.requestId,
        message: 'Audio source cannot be empty',
        status: CaptionStatus.failed,
      );
    }

    if (request.requestId.isEmpty) {
      return CaptionResult.failure(
        requestId: request.requestId,
        message: 'Request ID is required',
        status: CaptionStatus.failed,
      );
    }

    return CaptionResult(
      success: true,
      status: CaptionStatus.validating,
      requestId: request.requestId,
      message: 'Validation passed',
    );
  }

  bool _isCanceled(String requestId) {
    return _cancellationTokens[requestId] ?? false;
  }

  List<CaptionSegment> _createPlaceholderSegments(bool includeTimestamps) {
    if (!includeTimestamps) {
      return const [
        CaptionSegment(startTime: 0.0, endTime: 0.0, text: 'Generated captions are not available.', confidence: 0.0),
      ];
    }

    return const [
      CaptionSegment(startTime: 0.0, endTime: 2.0, text: 'This is a placeholder caption.', confidence: 0.85),
      CaptionSegment(startTime: 2.0, endTime: 4.5, text: 'The real speech-to-text engine is not implemented.', confidence: 0.82),
      CaptionSegment(startTime: 4.5, endTime: 7.0, text: 'Use this service as an architectural stub.', confidence: 0.76),
    ];
  }
}
