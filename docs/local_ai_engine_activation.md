# LocalAiEngine Activation

## Overview

This document describes how `InferencePipelineService` now activates the on-device `LocalAiEngine` for production inference and returns structured `AIInferenceResult` objects.

## Modified Files

- `lib/features/ai_commands/services/inference_pipeline_service.dart`
- `lib/features/ai_commands/services/local_ai_engine.dart`
- `lib/main.dart`
- `lib/features/ai_commands/presentation/cubit/ai_cubit.dart`

## Production Inference Execution Path

1. `AICubit.executeCommand` receives a command and ensures the inference pipeline is initialized.
2. `InferencePipelineService.executeCommand` parses the command into typed `AIInferenceRequest` objects.
3. For each inference request, `_executeAction` determines if inference is needed.
4. `_runInferenceAction` calls `_prepareModelForInference` to:
   - resolve model availability from `AIModelSelection`
   - download missing models via `ModelDownloadService`
   - load the model into `LocalAiEngine`
5. For background removal requests, `_executeBackgroundRemoval` is called.
6. `BackgroundRemovalService` delegates to `TFLiteSegmentationBackend`.
7. `TFLiteSegmentationBackend.segmentFrame` constructs typed model input and calls `LocalAiEngine.runInference`.
8. `LocalAiEngine.runInference` executes the loaded TFLite interpreter and returns a typed `TFLiteInferenceResult`.
9. The pipeline converts the engine output into a structured `AIInferenceResult.inferred`.

## Safe Failure Handling

- `_prepareModelForInference` returns `false` if the model cannot be loaded or downloaded.
- `_executeBackgroundRemoval` catches inference failures and returns `AIInferenceResult.failed`.
- `AICubit` emits `AIError` when the pipeline throws or returns failed results.

## Notes

- `LocalAiEngine` now supports loading models from both asset and file paths.
- The typed request model is represented by `AIInferenceRequest` and the corresponding typed output is `AIInferenceResult`.
- The current production path is fully wired through the background removal service into the engine.
