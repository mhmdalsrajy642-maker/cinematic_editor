# Model Download Workflow

## Overview

This document describes the model readiness workflow implemented in the AI inference pipeline.
The workflow ensures that a requested model is available locally before inference begins.
If the model is missing, the system downloads it, reports progress, loads it into the engine, and continues inference.

## Modified Files

- `lib/features/ai_commands/services/model_download_service.dart`
- `lib/features/ai_commands/services/inference_pipeline_service.dart`
- `lib/features/ai_commands/presentation/cubit/ai_cubit.dart`
- `lib/features/ai_commands/services/local_ai_engine.dart`
- `lib/main.dart`

## Workflow Sequence

1. `AICubit.executeCommand` receives a user command.
2. `InferencePipelineService.executeCommand` parses the command and builds action requests.
3. For each inference action, `_runInferenceAction` is invoked.
4. `_prepareModelForInference` is called to ensure the model is available.
   - The method resolves the model ID from the action's `AIModelSelection`.
   - It calls `ModelDownloadService.ensureModelAvailable`.
   - Progress is emitted for:
     - cache checking
     - metadata resolution
     - downloading
     - checksum verification
     - writing to disk
     - loading into engine
5. `ModelDownloadService.downloadModel` checks local cache and skips download if the model is already available.
6. If download is required, the service performs retries and reports `ModelDownloadProgress` updates.
7. After download and local verification, the model is loaded into `LocalAiEngine`.
8. The inference action continues once model readiness is confirmed.

## State Transitions

- `AIProcessing` → `AIModelDownloading` when the pipeline enters `AIInferenceStatus.downloadingModel` or `AIInferenceStatus.loadingModel`.
- `AIModelDownloading` continues until the model is available.
- After model readiness, the pipeline transitions back into inference execution and eventually to `AICompleted` or `AIError`.

## Download Sequence

1. Check local cache for requested model.
2. If cached and valid, optionally load into engine.
3. If missing or invalid, fetch model metadata.
4. Download model bytes from the resolved URL.
5. Report progress during download.
6. Verify downloaded checksum.
7. Write model file to disk atomically.
8. Persist cache manifest.
9. Load the model into the AI engine.
10. Continue inference.

## Notes

- The `AICubit` was left unchanged except for initializing the pipeline service before execution.
- The current `LocalAiEngine` now supports loading models from both asset and file paths.
- `ModelDownloadService` stores models under the application support directory in `ai_models`.
- The download URL resolution is still a placeholder and will need production configuration.
