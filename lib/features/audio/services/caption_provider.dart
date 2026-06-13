import 'dart:async';

import 'auto_caption_service.dart';

/// Abstract caption provider interface.
abstract class CaptionProvider {
  /// Initializes the caption provider.
  Future<void> initialize();

  /// Shuts down the caption provider.
  Future<void> shutdown();

  /// Generates captions for the provided request.
  Future<CaptionResult> generate(CaptionRequest request);
}

/// Local caption provider stub.
class LocalCaptionProvider implements CaptionProvider {
  const LocalCaptionProvider();

  @override
  Future<void> initialize() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<void> shutdown() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<CaptionResult> generate(CaptionRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return CaptionResult.success(
      requestId: request.requestId,
      transcript: 'This is a placeholder caption generated locally.',
      segments: const [
        CaptionSegment(
          startTime: 0.0,
          endTime: 3.0,
          text: 'This is a placeholder caption generated locally.',
          confidence: 0.85,
        ),
      ],
      message: 'Local caption provider returned stub captions.',
    );
  }
}

/// Remote caption provider stub.
class RemoteCaptionProvider implements CaptionProvider {
  const RemoteCaptionProvider();

  @override
  Future<void> initialize() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> shutdown() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<CaptionResult> generate(CaptionRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return CaptionResult.success(
      requestId: request.requestId,
      transcript: 'This is a placeholder caption generated remotely.',
      segments: const [
        CaptionSegment(
          startTime: 0.0,
          endTime: 3.0,
          text: 'This is a placeholder caption generated remotely.',
          confidence: 0.83,
        ),
      ],
      message: 'Remote caption provider returned stub captions.',
    );
  }
}
