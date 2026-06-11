// lib/features/ai_commands/services/inference_pipeline_service.dart
// Orchestration layer connecting command parsing, model selection,
// backend selection, and inference execution into a unified pipeline.
// Returns strongly typed results. No UI or EditorCubit dependencies.

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../../core/models/timeline_models.dart';
import 'ai_command_parser_service.dart';
import 'local_ai_engine.dart';
import 'background_removal_service.dart';

// ====================================================
// Pipeline Status
// ====================================================

/// Lifecycle status of an inference request
enum AIInferenceStatus {
  idle,
  parsingCommand,
  selectingModel,
  selectingBackend,
  loadingModel,
  runningInference,
  postProcessing,
  completed,
  failed,
  cancelled,
}

/// Whether the result requires inference or was resolved without it
enum AIResultKind {
  /// Pure data manipulation — no ML model needed (e.g. color grade presets)
  dataOnly,
  /// Inference was executed — result contains model output
  inferred,
  /// Inference was required but no backend was available
  pendingInference,
}

// ====================================================
// Strongly Typed Action Types
// ====================================================

/// Categorization of all AI action types the pipeline handles
enum AIActionType {
  applyColorGrade,
  removeBackground,
  generateCaptions,
  applyMotionTracking,
  reduceNoise,
  addMusic,
  addTextCaption,
  stabilize,
  speedRamp,
  unknown,
}

/// Maps raw parser action type strings to typed enum
AIActionType _resolveActionType(String rawType) {
  switch (rawType) {
    case 'apply_color_grade':
      return AIActionType.applyColorGrade;
    case 'remove_background':
      return AIActionType.removeBackground;
    case 'generate_captions':
      return AIActionType.generateCaptions;
    case 'apply_motion_tracking':
      return AIActionType.applyMotionTracking;
    case 'reduce_noise':
      return AIActionType.reduceNoise;
    case 'add_music':
    case 'add_audio':
      return AIActionType.addMusic;
    case 'add_text_caption':
      return AIActionType.addTextCaption;
    case 'stabilize':
      return AIActionType.stabilize;
    case 'speed_ramp':
      return AIActionType.speedRamp;
    default:
      return AIActionType.unknown;
  }
}

// ====================================================
// Model Selection
// ====================================================

/// Which ML model the pipeline selected for a given action
enum AIModelSelection {
  none,               // No model needed (data-only action)
  selfSegmentation,   // TFLite self-segmentation for background removal
  deepLabV3,          // DeepLabV3 for general segmentation
  mobileNetV3,        // MobileNetV3 for classification
  imageToText,        // Image-to-text for caption generation
  motionTracking,     // Optical flow / motion tracking model
  whisperTiny,        // Whisper tiny for speech-to-text captions
}

/// Resolves which model an action type requires
AIModelSelection _resolveModelForAction(AIActionType actionType) {
  switch (actionType) {
    case AIActionType.removeBackground:
      return AIModelSelection.selfSegmentation;
    case AIActionType.generateCaptions:
      return AIModelSelection.whisperTiny;
    case AIActionType.applyMotionTracking:
      return AIModelSelection.motionTracking;
    case AIActionType.applyColorGrade:
    case AIActionType.addMusic:
    case AIActionType.addTextCaption:
    case AIActionType.reduceNoise:
      return AIModelSelection.none;
    case AIActionType.stabilize:
      return AIModelSelection.motionTracking;
    case AIActionType.speedRamp:
      return AIModelSelection.none;
    case AIActionType.unknown:
      return AIModelSelection.none;
  }
}

/// Whether a model requires on-device inference
bool _requiresInference(AIModelSelection model) => model != AIModelSelection.none;

// ====================================================
// Request Model
// ====================================================

/// Strongly typed inference request produced from a parsed action
class AIInferenceRequest {
  final String rawCommand;
  final AIActionType actionType;
  final AIModelSelection modelSelection;
  final String? targetClipId;
  final Map<String, dynamic> parameters;
  final TimelineState timelineState;

  const AIInferenceRequest({
    required this.rawCommand,
    required this.actionType,
    required this.modelSelection,
    this.targetClipId,
    required this.parameters,
    required this.timelineState,
  });

  bool get needsInference => _requiresInference(modelSelection);

  @override
  String toString() =>
      'AIInferenceRequest(action: $actionType, model: $modelSelection, '
      'clip: $targetClipId, needsInference: $needsInference)';
}

// ====================================================
// Result Model
// ====================================================

/// Strongly typed inference result for a single action
class AIInferenceResult {
  final AIActionType actionType;
  final AIResultKind resultKind;
  final AIInferenceStatus status;
  final AIModelSelection modelUsed;
  final SegmentationBackend? backendUsed;
  final Duration inferenceTime;
  final String? errorMessage;

  // Data-only results (no inference)
  final VideoEffect? effect;
  final List<TextLayer>? textLayers;
  final AudioClip? audioClip;

  // Inference results
  final SegmentationResult? segmentationResult;
  final ClipSegmentationResult? clipSegmentationResult;

  const AIInferenceResult({
    required this.actionType,
    required this.resultKind,
    required this.status,
    this.modelUsed = AIModelSelection.none,
    this.backendUsed,
    required this.inferenceTime,
    this.errorMessage,
    this.effect,
    this.textLayers,
    this.audioClip,
    this.segmentationResult,
    this.clipSegmentationResult,
  });

  bool get isSuccess => status == AIInferenceStatus.completed;
  bool get needsInference => resultKind == AIResultKind.pendingInference;

  factory AIInferenceResult.dataOnly({
    required AIActionType actionType,
    required VideoEffect? effect,
    List<TextLayer>? textLayers,
    AudioClip? audioClip,
  }) {
    return AIInferenceResult(
      actionType: actionType,
      resultKind: AIResultKind.dataOnly,
      status: AIInferenceStatus.completed,
      inferenceTime: Duration.zero,
      effect: effect,
      textLayers: textLayers,
      audioClip: audioClip,
    );
  }

  factory AIInferenceResult.inferred({
    required AIActionType actionType,
    required AIModelSelection modelUsed,
    required SegmentationBackend backendUsed,
    required Duration inferenceTime,
    SegmentationResult? segmentationResult,
    ClipSegmentationResult? clipSegmentationResult,
    VideoEffect? effect,
  }) {
    return AIInferenceResult(
      actionType: actionType,
      resultKind: AIResultKind.inferred,
      status: AIInferenceStatus.completed,
      modelUsed: modelUsed,
      backendUsed: backendUsed,
      inferenceTime: inferenceTime,
      segmentationResult: segmentationResult,
      clipSegmentationResult: clipSegmentationResult,
      effect: effect,
    );
  }

  factory AIInferenceResult.pendingInference({
    required AIActionType actionType,
    required AIModelSelection modelSelection,
    required VideoEffect? effect,
  }) {
    return AIInferenceResult(
      actionType: actionType,
      resultKind: AIResultKind.pendingInference,
      status: AIInferenceStatus.completed,
      modelUsed: modelSelection,
      inferenceTime: Duration.zero,
      effect: effect,
    );
  }

  factory AIInferenceResult.failed({
    required AIActionType actionType,
    required String errorMessage,
    AIModelSelection modelUsed = AIModelSelection.none,
    Duration inferenceTime = Duration.zero,
  }) {
    return AIInferenceResult(
      actionType: actionType,
      resultKind: AIResultKind.dataOnly,
      status: AIInferenceStatus.failed,
      modelUsed: modelUsed,
      inferenceTime: inferenceTime,
      errorMessage: errorMessage,
    );
  }
}

// ====================================================
// Progress Reporting
// ====================================================

/// Progress update emitted during pipeline execution
class AIInferenceProgress {
  final AIInferenceStatus status;
  final AIActionType actionType;
  final int currentAction;
  final int totalActions;
  final String? detail;

  const AIInferenceProgress({
    required this.status,
    required this.actionType,
    required this.currentAction,
    required this.totalActions,
    this.detail,
  });

  double get progress =>
      totalActions > 0 ? currentAction / totalActions : 0.0;
}

typedef AIProgressCallback = void Function(AIInferenceProgress progress);

// ====================================================
// Pipeline Step: Parsed Action -> AIInferenceRequest
// ====================================================

/// Converts a raw parsed action map into a strongly typed request
AIInferenceRequest _buildRequest({
  required Map<String, dynamic> parsedAction,
  required String rawCommand,
  required TimelineState timelineState,
}) {
  final rawType = parsedAction['type'] as String? ?? 'unknown';
  final actionType = _resolveActionType(rawType);
  final modelSelection = _resolveModelForAction(actionType);
  final targetClipId = parsedAction['clipId'] as String? ??
      parsedAction['target'] as String?;
  final parameters = parsedAction['parameters'] as Map<String, dynamic>? ?? {};

  return AIInferenceRequest(
    rawCommand: rawCommand,
    actionType: actionType,
    modelSelection: modelSelection,
    targetClipId: targetClipId,
    parameters: parameters,
    timelineState: timelineState,
  );
}

// ====================================================
// Inference Pipeline Service
// ====================================================

/// Orchestrates the full AI inference pipeline:
///   User Command -> Parsed Intent -> Model Selection ->
///   Backend Selection -> Inference Execution -> Structured AI Result
class InferencePipelineService {
  final AiCommandParserService _parserService;
  final LocalAiEngine _aiEngine;
  final BackgroundRemovalService _backgroundRemovalService;
  bool _isInitialized = false;

  InferencePipelineService({
    required AiCommandParserService parserService,
    required LocalAiEngine aiEngine,
    required BackgroundRemovalService backgroundRemovalService,
  })  : _parserService = parserService,
        _aiEngine = aiEngine,
        _backgroundRemovalService = backgroundRemovalService;

  bool get isInitialized => _isInitialized;

  // ====================================================
  // Lifecycle
  // ====================================================

  /// Initialize all sub-services
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _aiEngine.initialize();
    await _backgroundRemovalService.initialize();
    _isInitialized = true;
    debugPrint('InferencePipelineService initialized');
  }

  /// Shutdown all sub-services
  Future<void> shutdown() async {
    await _backgroundRemovalService.shutdown();
    await _aiEngine.shutdown();
    _isInitialized = false;
    debugPrint('InferencePipelineService shut down');
  }

  // ====================================================
  // Full Pipeline: Command -> Results
  // ====================================================

  /// Execute the full pipeline from a natural language command
  /// to a list of strongly typed results.
  Future<List<AIInferenceResult>> executeCommand({
    required String command,
    required TimelineState timelineState,
    AIProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final results = <AIInferenceResult>[];

    // Step 1: Parse command
    onProgress?.call(const AIInferenceProgress(
      status: AIInferenceStatus.parsingCommand,
      actionType: AIActionType.unknown,
      currentAction: 0,
      totalActions: 1,
      detail: 'Parsing command',
    ));

    final parsedActions = await _parserService.parseCommand(
      command: command,
      timelineState: timelineState,
    );

    final totalActions = parsedActions.length;

    // Step 2-6: Process each parsed action through the pipeline
    for (int i = 0; i < parsedActions.length; i++) {
      final parsedAction = parsedActions[i];

      // Build strongly typed request
      final request = _buildRequest(
        parsedAction: parsedAction,
        rawCommand: command,
        timelineState: timelineState,
      );

      // Execute single action
      final result = await _executeAction(
        request: request,
        actionIndex: i,
        totalActions: totalActions,
        onProgress: onProgress,
      );

      results.add(result);
    }

    stopwatch.stop();
    debugPrint(
      'InferencePipelineService: processed ${results.length} actions '
      'in ${stopwatch.elapsed.inMilliseconds}ms',
    );

    return results;
  }

  // ====================================================
  // Single Action Pipeline
  // ====================================================

  /// Process a single typed request through the pipeline
  Future<AIInferenceResult> executeRequest({
    required AIInferenceRequest request,
    AIProgressCallback? onProgress,
  }) async {
    return _executeAction(
      request: request,
      actionIndex: 0,
      totalActions: 1,
      onProgress: onProgress,
    );
  }

  Future<AIInferenceResult> _executeAction({
    required AIInferenceRequest request,
    required int actionIndex,
    required int totalActions,
    AIProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    // Step 2: Model selection
    onProgress?.call(AIInferenceProgress(
      status: AIInferenceStatus.selectingModel,
      actionType: request.actionType,
      currentAction: actionIndex,
      totalActions: totalActions,
      detail: 'Selected model: ${request.modelSelection.name}',
    ));

    // Step 3: Backend selection
    onProgress?.call(AIInferenceProgress(
      status: AIInferenceStatus.selectingBackend,
      actionType: request.actionType,
      currentAction: actionIndex,
      totalActions: totalActions,
      detail: 'Backend: ${_backgroundRemovalService.activeBackendType?.name ?? "none"}',
    ));

    // Step 4-6: Execute based on whether inference is needed
    if (!request.needsInference) {
      // Data-only path — no ML model required
      stopwatch.stop();
      return _resolveDataOnlyResult(request, stopwatch.elapsed);
    }

    // Inference path — delegate to the appropriate service
    final inferenceResult = await _runInferenceAction(
      request: request,
      actionIndex: actionIndex,
      totalActions: totalActions,
      onProgress: onProgress,
    );

    stopwatch.stop();
    return inferenceResult;
  }

  // ====================================================
  // Data-Only Resolution (No Inference)
  // ====================================================

  AIInferenceResult _resolveDataOnlyResult(
    AIInferenceRequest request,
    Duration elapsed,
  ) {
    switch (request.actionType) {
      case AIActionType.applyColorGrade:
        return AIInferenceResult.dataOnly(
          actionType: request.actionType,
          effect: VideoEffect.create(
            type: EffectType.colorGrade,
            parameters: request.parameters,
          ),
        );

      case AIActionType.addTextCaption:
        final text = request.parameters['text'] as String? ??
            request.rawCommand;
        final startTime = (request.parameters['startTime'] as num?)
                ?.toDouble() ??
            0.0;
        final duration = (request.parameters['duration'] as num?)
                ?.toDouble() ??
            3.0;
        return AIInferenceResult.dataOnly(
          actionType: request.actionType,
          textLayers: [
            TextLayer.create(
              text: text,
              startTime: startTime,
              duration: duration,
            ),
          ],
        );

      case AIActionType.addMusic:
        // Music requires an audio file URL/path from the parameters
        // or an external source — pipeline returns data-only placeholder
        return AIInferenceResult.dataOnly(
          actionType: request.actionType,
          audioClip: null,
        );

      case AIActionType.reduceNoise:
        return AIInferenceResult.dataOnly(
          actionType: request.actionType,
          effect: VideoEffect.create(
            type: EffectType.colorGrade, // Noise reduction uses audio, not video effect
            parameters: {'type': 'noise_reduction', ...request.parameters},
          ),
        );

      case AIActionType.speedRamp:
        return AIInferenceResult.dataOnly(
          actionType: request.actionType,
          effect: VideoEffect.create(
            type: EffectType.speedRamp,
            parameters: request.parameters,
          ),
        );

      default:
        return AIInferenceResult.dataOnly(
          actionType: request.actionType,
          effect: null,
        );
    }
  }

  // ====================================================
  // Inference Execution
  // ====================================================

  Future<AIInferenceResult> _runInferenceAction({
    required AIInferenceRequest request,
    required int actionIndex,
    required int totalActions,
    AIProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    // Step 4: Load model if needed
    onProgress?.call(AIInferenceProgress(
      status: AIInferenceStatus.loadingModel,
      actionType: request.actionType,
      currentAction: actionIndex,
      totalActions: totalActions,
      detail: 'Loading model: ${request.modelSelection.name}',
    ));

    final modelLoaded = await _ensureModelLoaded(request.modelSelection);
    if (!modelLoaded) {
      // Model not available — return pending result with metadata
      stopwatch.stop();
      return AIInferenceResult.pendingInference(
        actionType: request.actionType,
        modelSelection: request.modelSelection,
        effect: _buildPendingEffect(request),
      );
    }

    // Step 5: Run inference via the appropriate service
    onProgress?.call(AIInferenceProgress(
      status: AIInferenceStatus.runningInference,
      actionType: request.actionType,
      currentAction: actionIndex,
      totalActions: totalActions,
      detail: 'Running ${request.modelSelection.name} inference',
    ));

    AIInferenceResult result;

    switch (request.actionType) {
      case AIActionType.removeBackground:
        result = await _executeBackgroundRemoval(
          request: request,
          actionIndex: actionIndex,
          totalActions: totalActions,
          onProgress: onProgress,
        );

      case AIActionType.generateCaptions:
        result = await _executeCaptionGeneration(request: request);

      case AIActionType.applyMotionTracking:
        result = await _executeMotionTracking(request: request);

      case AIActionType.stabilize:
        result = await _executeStabilization(request: request);

      default:
        stopwatch.stop();
        result = AIInferenceResult.failed(
          actionType: request.actionType,
          errorMessage: 'No inference handler for ${request.actionType}',
          inferenceTime: stopwatch.elapsed,
        );
    }

    stopwatch.stop();
    return result;
  }

  // ====================================================
  // Inference Handlers
  // ====================================================

  /// Background removal via BackgroundRemovalService
  Future<AIInferenceResult> _executeBackgroundRemoval({
    required AIInferenceRequest request,
    required int actionIndex,
    required int totalActions,
    AIProgressCallback? onProgress,
  }) async {
    final clipId = request.targetClipId;
    if (clipId == null) {
      return AIInferenceResult.failed(
        actionType: request.actionType,
        errorMessage: 'No clip ID specified for background removal',
      );
    }

    // Find the clip in the timeline
    final clip = request.timelineState.videoClips
        .where((c) => c.id == clipId)
        .firstOrNull;
    if (clip == null) {
      return AIInferenceResult.failed(
        actionType: request.actionType,
        errorMessage: 'Clip not found: $clipId',
      );
    }

    // Build config from request parameters
    final config = BackgroundRemovalConfig(
      preferredBackend: _resolveBackend(request.parameters),
      edgeSoftness: (request.parameters['edge_softness'] as num?)
              ?.toDouble() ??
          0.3,
      minimumConfidence: (request.parameters['minimum_confidence'] as num?)
              ?.toDouble() ??
          0.5,
    );

    // Process the clip
    final clipResult = await _backgroundRemovalService.processClip(
      clip: clip,
      config: config,
      onProgress: (processed, total, elapsed) {
        onProgress?.call(AIInferenceProgress(
          status: AIInferenceStatus.runningInference,
          actionType: request.actionType,
          currentAction: actionIndex,
          totalActions: totalActions,
          detail: 'Frame $processed/$total (${elapsed.inMilliseconds}ms)',
        ));
      },
    );

    if (!clipResult.success) {
      return AIInferenceResult.failed(
        actionType: request.actionType,
        errorMessage: clipResult.errorMessage ?? 'Background removal failed',
      );
    }

    return AIInferenceResult.inferred(
      actionType: request.actionType,
      modelUsed: request.modelSelection,
      backendUsed: _backgroundRemovalService.activeBackendType,
      inferenceTime: clipResult.totalProcessingTime,
      clipSegmentationResult: clipResult,
      effect: clipResult.backgroundRemovalEffect,
    );
  }

  /// Caption generation — architecture placeholder
  Future<AIInferenceResult> _executeCaptionGeneration({
    required AIInferenceRequest request,
  }) async {
    // Caption generation requires:
    // 1. Audio extraction from video (FFmpeg)
    // 2. Whisper tiny model inference
    // 3. Timestamp alignment
    // 4. TextLayer generation
    // All steps are architecture stubs pending model availability.

    return AIInferenceResult.pendingInference(
      actionType: request.actionType,
      modelSelection: AIModelSelection.whisperTiny,
      effect: null,
    );
  }

  /// Motion tracking — architecture placeholder
  Future<AIInferenceResult> _executeMotionTracking({
    required AIInferenceRequest request,
  }) async {
    final clipId = request.targetClipId;
    if (clipId == null) {
      return AIInferenceResult.failed(
        actionType: request.actionType,
        errorMessage: 'No clip ID specified for motion tracking',
      );
    }

    // Motion tracking requires:
    // 1. Frame extraction
    // 2. Optical flow / feature point detection model
    // 3. Keyframe data generation
    // Architecture stub pending model availability.

    return AIInferenceResult.pendingInference(
      actionType: request.actionType,
      modelSelection: AIModelSelection.motionTracking,
      effect: VideoEffect.create(
        type: EffectType.motionTracking,
        parameters: request.parameters,
      ),
    );
  }

  /// Stabilization — architecture placeholder
  Future<AIInferenceResult> _executeStabilization({
    required AIInferenceRequest request,
  }) async {
    // Stabilization uses the same motion analysis as motion tracking
    // but applies inverse transforms instead of tracking data.
    return AIInferenceResult.pendingInference(
      actionType: request.actionType,
      modelSelection: AIModelSelection.motionTracking,
      effect: VideoEffect.create(
        type: EffectType.stabilization,
        parameters: request.parameters,
      ),
    );
  }

  // ====================================================
  // Model Loading
  // ====================================================

  /// Ensure the required model is loaded into LocalAiEngine
  Future<bool> _ensureModelLoaded(AIModelSelection model) async {
    if (!_aiEngine.isInitialized) return false;

    final modelDef = _modelDefinitionForSelection(model);
    if (modelDef == null) return false;

    if (_aiEngine.isModelLoaded(modelDef.name)) return true;

    try {
      await _aiEngine.loadModel(modelDef: modelDef);
      return true;
    } catch (e) {
      debugPrint('InferencePipelineService: model load failed: $e');
      return false;
    }
  }

  /// Map model selection to TFLiteModelDefinition
  TFLiteModelDefinition? _modelDefinitionForSelection(AIModelSelection model) {
    switch (model) {
      case AIModelSelection.selfSegmentation:
        return PredefinedModels.selfSegmentation;
      case AIModelSelection.deepLabV3:
        return PredefinedModels.deeplabv3Lite;
      case AIModelSelection.mobileNetV3:
        return PredefinedModels.mobilenetv3;
      case AIModelSelection.imageToText:
        return PredefinedModels.imageToText;
      case AIModelSelection.motionTracking:
        // No model definition exists yet for motion tracking
        return null;
      case AIModelSelection.whisperTiny:
        // No model definition exists yet for Whisper
        return null;
      case AIModelSelection.none:
        return null;
    }
  }

  // ====================================================
  // Helpers
  // ====================================================

  /// Resolve preferred backend from action parameters
  SegmentationBackend _resolveBackend(Map<String, dynamic> parameters) {
    final modelHint = parameters['model'] as String?;
    switch (modelHint) {
      case 'mediapipe_selfie':
        return SegmentationBackend.mediaPipeSelfie;
      case 'deeplabv3':
        return SegmentationBackend.tfliteDeepLabV3;
      default:
        return SegmentationBackend.tfliteSelfSegmentation;
    }
  }

  /// Build a placeholder effect for actions pending inference
  VideoEffect? _buildPendingEffect(AIInferenceRequest request) {
    final effectType = _effectTypeForAction(request.actionType);
    if (effectType == null) return null;

    return VideoEffect.create(
      type: effectType,
      parameters: {
        ...request.parameters,
        'pending_inference': true,
        'required_model': request.modelSelection.name,
      },
    );
  }

  /// Map action type to EffectType
  EffectType? _effectTypeForAction(AIActionType actionType) {
    switch (actionType) {
      case AIActionType.removeBackground:
        return EffectType.backgroundRemoval;
      case AIActionType.applyMotionTracking:
        return EffectType.motionTracking;
      case AIActionType.stabilize:
        return EffectType.stabilization;
      case AIActionType.speedRamp:
        return EffectType.speedRamp;
      case AIActionType.applyColorGrade:
        return EffectType.colorGrade;
      default:
        return null;
    }
  }

  /// Get pipeline status summary for diagnostics
  Map<String, dynamic> get status {
    return {
      'is_initialized': _isInitialized,
      'ai_engine_initialized': _aiEngine.isInitialized,
      'bg_removal_initialized': _backgroundRemovalService.isInitialized,
      'bg_removal_backend': _backgroundRemovalService.activeBackendType?.name,
      'loaded_models': _aiEngine.loadedModels,
    };
  }
}
