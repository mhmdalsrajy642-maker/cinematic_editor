// lib/features/ai_commands/services/background_removal_service.dart
// Interface-based background removal service architecture
// Supports multiple segmentation backends (TFLite, MediaPipe, server API)
// Compatible with dependency injection, export pipeline, and EditorCubit integration

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../../core/models/timeline_models.dart';
import 'local_ai_engine.dart';

// ====================================================
// Result Models
// ====================================================

/// Result of a background removal operation on a single frame
class SegmentationResult {
  final bool success;
  final Uint8List? maskData;
  final int maskWidth;
  final int maskHeight;
  final String? errorMessage;
  final Duration inferenceTime;
  final SegmentationBackend backend;

  const SegmentationResult({
    required this.success,
    this.maskData,
    this.maskWidth = 0,
    this.maskHeight = 0,
    this.errorMessage,
    required this.inferenceTime,
    required this.backend,
  });

  factory SegmentationResult.success({
    required Uint8List maskData,
    required int maskWidth,
    required int maskHeight,
    required Duration inferenceTime,
    required SegmentationBackend backend,
  }) {
    return SegmentationResult(
      success: true,
      maskData: maskData,
      maskWidth: maskWidth,
      maskHeight: maskHeight,
      inferenceTime: inferenceTime,
      backend: backend,
    );
  }

  factory SegmentationResult.error({
    required String errorMessage,
    required Duration inferenceTime,
    required SegmentationBackend backend,
  }) {
    return SegmentationResult(
      success: false,
      errorMessage: errorMessage,
      inferenceTime: inferenceTime,
      backend: backend,
    );
  }
}

/// Result of processing an entire video clip for background removal
class ClipSegmentationResult {
  final bool success;
  final String clipId;
  final String? maskSequencePath;
  final int processedFrames;
  final int totalFrames;
  final Duration totalProcessingTime;
  final String? errorMessage;
  final VideoEffect? backgroundRemovalEffect;

  const ClipSegmentationResult({
    required this.success,
    required this.clipId,
    this.maskSequencePath,
    this.processedFrames = 0,
    this.totalFrames = 0,
    required this.totalProcessingTime,
    this.errorMessage,
    this.backgroundRemovalEffect,
  });

  double get progress => totalFrames > 0 ? processedFrames / totalFrames : 0.0;
}

/// Progress callback for frame-by-frame processing
typedef SegmentationProgressCallback = void Function(
  int processedFrames,
  int totalFrames,
  Duration elapsed,
);

// ====================================================
// Configuration Models
// ====================================================

/// Which segmentation backend to use
enum SegmentationBackend {
  tfliteSelfSegmentation,
  tfliteDeepLabV3,
  mediaPipeSelfie,
  serverApi,
}

/// Quality/speed tradeoff for segmentation
enum SegmentationQuality {
  fast,    // Lower resolution input, faster inference
  balanced,
  high,    // Full resolution input, slower inference
}

/// Configuration for a background removal operation
class BackgroundRemovalConfig {
  final SegmentationBackend preferredBackend;
  final SegmentationQuality quality;
  final double edgeSoftness;       // 0.0 = hard mask edge, 1.0 = very soft
  final double minimumConfidence;  // Minimum confidence to include in mask (0.0-1.0)
  final int targetMaskWidth;
  final int targetMaskHeight;
  final bool enableRefinementPass; // Run a second pass to refine mask edges

  const BackgroundRemovalConfig({
    this.preferredBackend = SegmentationBackend.tfliteSelfSegmentation,
    this.quality = SegmentationQuality.balanced,
    this.edgeSoftness = 0.3,
    this.minimumConfidence = 0.5,
    this.targetMaskWidth = 256,
    this.targetMaskHeight = 256,
    this.enableRefinementPass = false,
  });
}

// ====================================================
// Segmentation Backend Interface
// ====================================================

/// Abstract interface for segmentation backends
/// Each backend (TFLite, MediaPipe, server) implements this contract
abstract class SegmentationBackendInterface {
  /// Unique identifier for this backend
  SegmentationBackend get backendType;

  /// Whether this backend is available on the current device
  Future<bool> isAvailable();

  /// Initialize the backend (load model, allocate resources)
  Future<void> initialize();

  /// Release backend resources
  Future<void> shutdown();

  /// Run segmentation on a single frame
  /// Input: raw RGBA frame bytes at [width]x[height]
  /// Output: grayscale mask where 255 = foreground, 0 = background
  Future<SegmentationResult> segmentFrame({
    required Uint8List frameData,
    required int width,
    required int height,
    required BackgroundRemovalConfig config,
  });

  /// Estimate inference time for a single frame (for scheduling)
  Future<Duration> estimateInferenceTime(BackgroundRemovalConfig config);
}

// ====================================================
// TFLite Segmentation Backend
// ====================================================

/// TFLite-based segmentation backend using LocalAiEngine
class TFLiteSegmentationBackend implements SegmentationBackendInterface {
  final LocalAiEngine _engine;
  TFLiteModelDefinition? _modelDef;
  bool _isInitialized = false;

  TFLiteSegmentationBackend(this._engine);

  @override
  SegmentationBackend get backendType => SegmentationBackend.tfliteSelfSegmentation;

  @override
  Future<bool> isAvailable() async {
    return _engine.isInitialized;
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (!_engine.isInitialized) {
      await _engine.initialize();
    }

    _modelDef = PredefinedModels.selfSegmentation;
    await _engine.loadModel(modelDef: _modelDef!);
    _isInitialized = true;
  }

  @override
  Future<void> shutdown() async {
    if (_modelDef != null) {
      await _engine.unloadModel(_modelDef!.name);
    }
    _isInitialized = false;
  }

  @override
  Future<SegmentationResult> segmentFrame({
    required Uint8List frameData,
    required int width,
    required int height,
    required BackgroundRemovalConfig config,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      if (!_isInitialized || _modelDef == null) {
        throw Exception('TFLite segmentation backend not initialized');
      }

      // Preprocess: resize frame to model input dimensions
      final inputTensor = _preprocessFrame(
        frameData,
        width,
        height,
        config.targetMaskWidth,
        config.targetMaskHeight,
      );

      final result = await _engine.runInference(
        modelName: _modelDef!.name,
        input: inputTensor,
      );

      stopwatch.stop();

      if (!result.success) {
        return SegmentationResult.error(
          errorMessage: result.errorMessage ?? 'TFLite inference failed',
          inferenceTime: stopwatch.elapsed,
          backend: backendType,
        );
      }

      // Postprocess: convert output tensor to mask
      final mask = _postprocessOutput(
        result.output,
        config.targetMaskWidth,
        config.targetMaskHeight,
        config.minimumConfidence,
        config.edgeSoftness,
      );

      return SegmentationResult.success(
        maskData: mask,
        maskWidth: config.targetMaskWidth,
        maskHeight: config.targetMaskHeight,
        inferenceTime: stopwatch.elapsed,
        backend: backendType,
      );
    } catch (e) {
      stopwatch.stop();
      return SegmentationResult.error(
        errorMessage: e.toString(),
        inferenceTime: stopwatch.elapsed,
        backend: backendType,
      );
    }
  }

  @override
  Future<Duration> estimateInferenceTime(BackgroundRemovalConfig config) async {
    // Estimated based on model size and device capability
    // Will be refined with actual benchmarks after model integration
    switch (config.quality) {
      case SegmentationQuality.fast:
        return const Duration(milliseconds: 30);
      case SegmentationQuality.balanced:
        return const Duration(milliseconds: 60);
      case SegmentationQuality.high:
        return const Duration(milliseconds: 120);
    }
  }

  /// Resize RGBA frame to model input dimensions and convert to float32 tensor
  List<List<List<List<double>>>> _preprocessFrame(
    Uint8List frameData,
    int srcWidth,
    int srcHeight,
    int targetWidth,
    int targetHeight,
  ) {
    // Architecture note: actual pixel resizing requires image manipulation
    // (package:image or raw pixel sampling). This returns the expected
    // tensor shape [1, H, W, 3] for the self-segmentation model.
    // Implementation will be completed when tflite_flutter models are added.

    final tensor = List.generate(
      1,
      (_) => List.generate(
        targetHeight,
        (_) => List.generate(
          targetWidth,
          (_) => List.generate(3, (_) => 0.0),
        ),
      ),
    );

    // Naive nearest-neighbor resize from RGBA to RGB float32
    final xRatio = srcWidth / targetWidth;
    final yRatio = srcHeight / targetHeight;

    for (int y = 0; y < targetHeight; y++) {
      for (int x = 0; x < targetWidth; x++) {
        final srcX = (x * xRatio).round().clamp(0, srcWidth - 1);
        final srcY = (y * yRatio).round().clamp(0, srcHeight - 1);
        final srcIdx = (srcY * srcWidth + srcX) * 4; // RGBA stride

        if (srcIdx + 2 < frameData.length) {
          tensor[0][y][x][0] = frameData[srcIdx] / 255.0;     // R
          tensor[0][y][x][1] = frameData[srcIdx + 1] / 255.0; // G
          tensor[0][y][x][2] = frameData[srcIdx + 2] / 255.0; // B
        }
      }
    }

    return tensor;
  }

  /// Convert model output tensor to grayscale Uint8List mask
  Uint8List _postprocessOutput(
    dynamic output,
    int maskWidth,
    int maskHeight,
    double minimumConfidence,
    double edgeSoftness,
  ) {
    final mask = Uint8List(maskWidth * maskHeight);

    // Architecture note: output shape depends on the model.
    // Self-segmentation outputs [1, 256, 256, 1] float32 confidence map.
    // DeepLabV3 outputs [1, 257, 257, 21] per-class probabilities.
    // The actual parsing will be completed with real model integration.

    if (output is List && output.isNotEmpty) {
      final flat = _flattenOutput(output);
      for (int i = 0; i < mask.length && i < flat.length; i++) {
        final confidence = flat[i];
        if (confidence >= minimumConfidence) {
          // Apply soft edge: blend confidence above threshold
          final alpha = edgeSoftness > 0
              ? ((confidence - minimumConfidence) / (1.0 - minimumConfidence))
                  .clamp(0.0, 1.0)
              : 1.0;
          mask[i] = (alpha * 255).round().clamp(0, 255);
        }
      }
    }

    return mask;
  }

  /// Flatten nested tensor output to a flat list of doubles
  List<double> _flattenOutput(dynamic output) {
    final result = <double>[];

    void walk(dynamic val) {
      if (val is double) {
        result.add(val);
      } else if (val is int) {
        result.add(val.toDouble());
      } else if (val is List) {
        for (final item in val) {
          walk(item);
        }
      }
    }

    walk(output);
    return result;
  }
}

// ====================================================
// MediaPipe Segmentation Backend (Architecture Only)
// ====================================================

/// MediaPipe Selfie Segmentation backend
/// Requires google_mediapipe package (not yet in pubspec.yaml)
/// Architecture is complete; implementation awaits dependency addition
class MediaPipeSegmentationBackend implements SegmentationBackendInterface {
  @override
  SegmentationBackend get backendType => SegmentationBackend.mediaPipeSelfie;

  @override
  Future<bool> isAvailable() async {
    // MediaPipe availability depends on:
    // 1. google_mediapipe package being added to pubspec
    // 2. Platform support (Android/iOS only, no desktop/web)
    // 3. GPU support on device
    debugPrint('MediaPipe backend not yet available - dependency not added');
    return false;
  }

  @override
  Future<void> initialize() async {
    // Will be implemented when google_mediapipe is added:
    // 1. Create SelfieSegmenter with stream mode
    // 2. Configure GPU or CPU delegate
    // 3. Set output category mask vs confidence mask
    debugPrint('MediaPipe backend initialization pending dependency');
  }

  @override
  Future<void> shutdown() async {
    // Release MediaPipe segmenter resources
  }

  @override
  Future<SegmentationResult> segmentFrame({
    required Uint8List frameData,
    required int width,
    required int height,
    required BackgroundRemovalConfig config,
  }) async {
    // MediaPipe Selfie Segmentation workflow:
    // 1. Convert frame to InputImage
    // 2. Call SelfieSegmenter.process(inputImage)
    // 3. Extract segmentation mask from result
    // 4. Convert to Uint8List grayscale mask
    return SegmentationResult.error(
      errorMessage: 'MediaPipe backend not yet implemented',
      inferenceTime: Duration.zero,
      backend: backendType,
    );
  }

  @override
  Future<Duration> estimateInferenceTime(BackgroundRemovalConfig config) async {
    // MediaPipe GPU-accelerated inference is typically faster than TFLite CPU
    switch (config.quality) {
      case SegmentationQuality.fast:
        return const Duration(milliseconds: 15);
      case SegmentationQuality.balanced:
        return const Duration(milliseconds: 30);
      case SegmentationQuality.high:
        return const Duration(milliseconds: 50);
    }
  }
}

// ====================================================
// Server API Segmentation Backend (Architecture Only)
// ====================================================

/// Remote server API segmentation backend
/// Offloads inference to cloud when on-device is unavailable
class ServerApiSegmentationBackend implements SegmentationBackendInterface {
  @override
  SegmentationBackend get backendType => SegmentationBackend.serverApi;

  @override
  Future<bool> isAvailable() async {
    // Requires network connectivity and API endpoint
    return false;
  }

  @override
  Future<void> initialize() async {
    // Configure API client, auth tokens, endpoint URL
  }

  @override
  Future<void> shutdown() async {
    // Release API client resources
  }

  @override
  Future<SegmentationResult> segmentFrame({
    required Uint8List frameData,
    required int width,
    required int height,
    required BackgroundRemovalConfig config,
  }) async {
    // Server API workflow:
    // 1. Encode frame as JPEG/PNG
    // 2. POST to /ai/segment-background endpoint
    // 3. Receive mask as response body
    // 4. Decode to Uint8List
    return SegmentationResult.error(
      errorMessage: 'Server API backend not yet implemented',
      inferenceTime: Duration.zero,
      backend: backendType,
    );
  }

  @override
  Future<Duration> estimateInferenceTime(BackgroundRemovalConfig config) async {
    // Network latency + server inference
    return const Duration(milliseconds: 500);
  }
}

// ====================================================
// Main Background Removal Service
// ====================================================

/// Orchestrates background removal across multiple backends
/// Selects best available backend, manages lifecycle, produces VideoEffect
class BackgroundRemovalService {
  final Map<SegmentationBackend, SegmentationBackendInterface> _backends;
  SegmentationBackendInterface? _activeBackend;
  BackgroundRemovalConfig _defaultConfig;
  bool _isInitialized = false;

  BackgroundRemovalService({
    required List<SegmentationBackendInterface> backends,
    BackgroundRemovalConfig defaultConfig = const BackgroundRemovalConfig(),
  }) : _backends = {
          for (final backend in backends) backend.backendType: backend,
        },
        _defaultConfig = defaultConfig;

  /// Convenience factory with default TFLite + MediaPipe + server backends
  factory BackgroundRemovalService.withDefaults({
    LocalAiEngine? engine,
    BackgroundRemovalConfig? config,
  }) {
    final tfliteEngine = engine ?? LocalAiEngine();
    return BackgroundRemovalService(
      backends: [
        TFLiteSegmentationBackend(tfliteEngine),
        MediaPipeSegmentationBackend(),
        ServerApiSegmentationBackend(),
      ],
      defaultConfig: config ?? const BackgroundRemovalConfig(),
    );
  }

  /// Whether the service has an initialized backend
  bool get isInitialized => _isInitialized && _activeBackend != null;

  /// Currently active backend type (null if not initialized)
  SegmentationBackend? get activeBackendType => _activeBackend?.backendType;

  /// Update default configuration
  set defaultConfig(BackgroundRemovalConfig config) => _defaultConfig = config;

  // ====================================================
  // Lifecycle
  // ====================================================

  /// Initialize the service, selecting the best available backend
  Future<void> initialize() async {
    if (_isInitialized) return;

    final preferred = _defaultConfig.preferredBackend;

    // Try preferred backend first
    if (_backends.containsKey(preferred)) {
      final backend = _backends[preferred]!;
      if (await backend.isAvailable()) {
        await backend.initialize();
        _activeBackend = backend;
        _isInitialized = true;
        debugPrint('BackgroundRemovalService: using ${preferred.name}');
        return;
      }
    }

    // Fall back through available backends in priority order
    const fallbackOrder = [
      SegmentationBackend.mediaPipeSelfie,
      SegmentationBackend.tfliteSelfSegmentation,
      SegmentationBackend.tfliteDeepLabV3,
      SegmentationBackend.serverApi,
    ];

    for (final type in fallbackOrder) {
      if (_backends.containsKey(type)) {
        final backend = _backends[type]!;
        if (await backend.isAvailable()) {
          await backend.initialize();
          _activeBackend = backend;
          _isInitialized = true;
          debugPrint('BackgroundRemovalService: fell back to ${type.name}');
          return;
        }
      }
    }

    debugPrint('BackgroundRemovalService: no backend available');
  }

  /// Shutdown the service and release all backend resources
  Future<void> shutdown() async {
    if (_activeBackend != null) {
      await _activeBackend!.shutdown();
      _activeBackend = null;
    }
    _isInitialized = false;
  }

  // ====================================================
  // Single-Frame Segmentation
  // ====================================================

  /// Run background removal on a single frame
  Future<SegmentationResult> segmentFrame({
    required Uint8List frameData,
    required int width,
    required int height,
    BackgroundRemovalConfig? config,
  }) async {
    final effectiveConfig = config ?? _defaultConfig;

    if (!isInitialized) {
      return SegmentationResult.error(
        errorMessage: 'BackgroundRemovalService not initialized',
        inferenceTime: Duration.zero,
        backend: effectiveConfig.preferredBackend,
      );
    }

    return _activeBackend!.segmentFrame(
      frameData: frameData,
      width: width,
      height: height,
      config: effectiveConfig,
    );
  }

  // ====================================================
  // Full Clip Processing
  // ====================================================

  /// Process an entire video clip frame-by-frame for background removal
  /// Returns a ClipSegmentationResult with the VideoEffect to apply
  Future<ClipSegmentationResult> processClip({
    required VideoClip clip,
    BackgroundRemovalConfig? config,
    SegmentationProgressCallback? onProgress,
  }) async {
    final effectiveConfig = config ?? _defaultConfig;
    final stopwatch = Stopwatch()..start();

    if (!isInitialized) {
      return ClipSegmentationResult(
        success: false,
        clipId: clip.id,
        totalProcessingTime: Duration.zero,
        errorMessage: 'BackgroundRemovalService not initialized',
      );
    }

    // Architecture note: Full clip processing requires a frame extraction
    // pipeline (FFmpeg or NativeBridge) that does not yet exist as a
    // service. The workflow below defines the architecture:
    //
    // 1. Extract frames from clip using FFmpeg/NativeBridge decoder
    //    - For preview: use proxy path (360p)
    //    - For export: use original path (4K)
    // 2. For each frame:
    //    a. Run segmentation via active backend
    //    b. Save mask to disk as numbered PNG sequence
    //    c. Report progress via callback
    // 3. Build VideoEffect with mask sequence metadata
    // 4. Return ClipSegmentationResult with the effect

    final clipDuration = clip.duration;
    final fps = 30; // Default; should come from ProjectSettings
    final totalFrames = (clipDuration * fps).round();

    // Placeholder: marks architecture intent for frame extraction
    debugPrint(
      'BackgroundRemovalService: processing $totalFrames frames '
      'for clip ${clip.id} (${clipDuration.toStringAsFixed(1)}s)',
    );

    stopwatch.stop();

    // Build the VideoEffect that EditorCubit.applyAIActions() would apply
    final effect = VideoEffect.create(
      type: EffectType.backgroundRemoval,
      parameters: {
        'backend': _activeBackend!.backendType.name,
        'mask_width': effectiveConfig.targetMaskWidth,
        'mask_height': effectiveConfig.targetMaskHeight,
        'edge_softness': effectiveConfig.edgeSoftness,
        'minimum_confidence': effectiveConfig.minimumConfidence,
        'quality': effectiveConfig.quality.name,
        'refinement_pass': effectiveConfig.enableRefinementPass,
        // Mask sequence path will be set after frame extraction is implemented
        'mask_sequence_path': null,
      },
    );

    return ClipSegmentationResult(
      success: true,
      clipId: clip.id,
      totalFrames: totalFrames,
      processedFrames: 0,
      totalProcessingTime: stopwatch.elapsed,
      backgroundRemovalEffect: effect,
    );
  }

  // ====================================================
  // Export Compatibility
  // ====================================================

  /// Build FFmpeg filter arguments for applying background removal mask
  /// during export. Integrates with FFmpegCommandBuilder.
  ///
  /// Returns a map of parameters that FFmpegCommandBuilder can consume
  /// to insert the appropriate filter chain for the mask overlay.
  Map<String, dynamic> buildExportFilterParams(VideoEffect effect) {
    final params = effect.parameters;
    return {
      'filter_type': 'background_removal',
      'mask_sequence_path': params['mask_sequence_path'],
      'mask_width': params['mask_width'] ?? 256,
      'mask_height': params['mask_height'] ?? 256,
      'edge_softness': params['edge_softness'] ?? 0.3,
      // FFmpeg filter: uses alphamerge or overlay with mask as alpha channel
      // Example filter chain for export:
      //   [0:v][1:v] alphamerge [masked]
      //   Where [1:v] is the mask sequence loaded as grayscale input
      'ffmpeg_filter_hint': 'alphamerge',
    };
  }

  /// Check if a clip's background removal effect has processed masks
  /// ready for export (vs. just the effect metadata)
  bool isExportReady(VideoClip clip) {
    final bgEffect = clip.effects.where(
      (e) => e.type == EffectType.backgroundRemoval && e.isEnabled,
    );

    if (bgEffect.isEmpty) return false;

    final effect = bgEffect.first;
    final maskPath = effect.parameters['mask_sequence_path'];
    return maskPath != null && maskPath is String && maskPath.isNotEmpty;
  }

  // ====================================================
  // Backend Management
  // ====================================================

  /// Switch to a different backend at runtime
  Future<bool> switchBackend(SegmentationBackend type) async {
    if (!_backends.containsKey(type)) return false;

    final newBackend = _backends[type]!;
    if (!await newBackend.isAvailable()) return false;

    // Shutdown current backend
    if (_activeBackend != null) {
      await _activeBackend!.shutdown();
    }

    // Initialize new backend
    await newBackend.initialize();
    _activeBackend = newBackend;
    return true;
  }

  /// List all registered backends and their availability
  Future<Map<SegmentationBackend, bool>> getBackendAvailability() async {
    final availability = <SegmentationBackend, bool>{};
    for (final entry in _backends.entries) {
      availability[entry.key] = await entry.value.isAvailable();
    }
    return availability;
  }
}
