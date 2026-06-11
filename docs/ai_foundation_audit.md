# AI Foundation Audit

**Repository:** cinematic_editor
**Date:** 2026-06-11
**Scope:** All AI-related architecture, services, models, and integration points

---

## 1. Current AI Implementation

### AiCommandParserService
- **Path:** `lib/features/ai_commands/services/ai_command_parser_service.dart`
- Parses natural-language commands (Arabic) into structured `List<Map<String, dynamic>>` actions
- Server API fallback via Dio at `/ai/parse-command` endpoint with timeline context
- Local keyword-based fallback supports: color grades (cinematic/night/warm/BW), background removal, captions, noise reduction, motion tracking, text, music
- `_detectColorGradeParameters()` returns preset parameters for four styles
- `_buildTimelineContext()` serializes timeline summary for the API

### LocalAiEngine
- **Path:** `lib/features/ai_commands/services/local_ai_engine.dart`
- Singleton TFLite inference engine scaffold
- `TFLiteModelDefinition` class with: modelPath, name, inputShape, outputShape, inputType, outputType, quantized, numThreads
- `TFLiteInferenceResult` class with: success, output, errorMessage, inferenceTime
- `AiEngineBackend` abstract interface with `TFLiteBackend` implementation
- Predefined model definitions (no model files on disk):
  - DeepLabV3 Lite — 257x257 segmentation, float32
  - MobileNetV3 — 224x224 classification, float32
  - Self-Segmentation — 256x256 portrait segmentation, float32
  - Image-to-Text — 224x224 caption generation, float32
- GPU acceleration placeholder (`enableGpuAcceleration()`)
- MediaPipe backend is a TODO comment (lines 413–416), not implemented

### AiCommandsPanel
- **Path:** `lib/features/editor/presentation/widgets/panels/ai_commands_panel.dart`
- UI with text input, mic button (placeholder), example commands, command history
- Calls `_parserService.parseCommand()` then `context.read<EditorCubit>().applyAIActions(actions)`

### EditorCubit.applyAIActions()
- **Path:** `lib/features/editor/presentation/cubit/editor_cubit.dart`
- Processes parsed AI actions and mutates timeline state
- Supported action types:
  - `apply_color_grade` — sets color parameters on VideoClip
  - `remove_background` — adds `EffectType.backgroundRemoval` to VideoClip.effects
  - `add_music` / `add_audio` — adds AudioClip to timeline
  - `generate_captions` — adds TextLayer to timeline
  - `apply_motion_tracking` — adds `EffectType.motionTracking` to VideoClip.effects
  - `add_text_caption` — adds TextLayer with styled text
- **Critical gap:** All actions are data-model mutations only. No inference is invoked at any point.

### EffectType Enum (AI-Related Entries)
- **Path:** `lib/core/models/timeline_models.dart`
- `backgroundRemoval`, `motionTracking`, `stabilization`, `speedRamp`, `chromaKey`, `lumaKey`
- These enum values exist but have no processing backends that consume them

---

## 2. Missing AI Infrastructure

### No On-Device Model Files
- `assets/models/*.tflite` referenced in `LocalAiEngine` do not exist
- No asset pipeline for downloading, verifying, or caching model files
- No model versioning or update mechanism

### No MediaPipe Integration
- `google_mediapipe: ^0.10.14` declared in PROJECT_SOURCE_MASTER.txt blueprint but absent from current `pubspec.yaml`
- `LocalAiEngine` has a TODO placeholder for a MediaPipe backend
- Background removal blueprint relies on MediaPipe Selfie Segmentation — this path is entirely unstarted

### No Inference Pipeline
- No code path connects `AiCommandParserService` output to `LocalAiEngine.runInference()` to effect application
- Parser returns actions -> EditorCubit applies data mutations -> No inference step exists between parse and apply
- The `AiEngineBackend` interface is defined but never called by any production code

### No AI-Specific State Management
- AI logic is embedded in EditorCubit (~400 lines, already oversized)
- No dedicated AICubit/Bloc as recommended in `implementation_gap_plan.md`
- No AI state model (loading, error, inference progress, model readiness)

### No GPU Delegate
- `enableGpuAcceleration()` is a no-op placeholder
- No GPU delegate initialization for TFLite (no `GpuDelegateV2` or `GlDelegate` setup)
- No device capability detection for GPU availability

### No Model Download Service
- No mechanism to fetch models from remote storage on first use
- No disk space checking, no progress reporting, no retry logic
- No lazy-loading or on-demand model acquisition strategy

### No Asset Pipeline for ML Models
- `pubspec.yaml` has no `assets/models/` section
- No build-step or Gradle configuration for bundling models
- No `.tflite` files in the project tree at all

---

## 3. Required Services

| Service | Responsibility | Priority |
|---|---|---|
| **AICubit** | Separate state management for AI operations (loading, results, errors). Extract from EditorCubit. | High |
| **ModelDownloadService** | Download, cache, verify, and version .tflite model files from remote storage. | High |
| **InferencePipelineService** | Orchestrate: parse command -> select model -> run inference -> post-process -> return structured result. | High |
| **BackgroundRemovalService** | Run segmentation model (MediaPipe or TFLite Self-Segmentation), produce alpha mask, apply to VideoClip frames. | High |
| **CaptionGenerationService** | Run audio-to-text (Whisper tiny or similar), align timestamps, produce TextLayer list. | Medium |
| **MotionTrackingService** | Track feature points across frames, produce keyframe data for EffectType.motionTracking. | Medium |
| **StyleTransferService** | Apply artistic style to video frames via neural style transfer model. | Low |
| **StabilizationService** | Compute motion vectors, produce frame transforms for EffectType.stabilization. | Low |
| **GPUDelegateService** | Detect device GPU capability, configure TFLite GPU delegate, fall back to CPU. | Medium |
| **AIResultCacheService** | Cache inference results keyed by input hash to avoid redundant processing. | Low |

---

## 4. Required Models

| Model | Format | Purpose | Source | Estimated Size |
|---|---|---|---|---|
| Self-Segmentation (portrait) | .tflite | Background removal | MediaPipe / TFLite Model Zoo | ~3 MB |
| DeepLabV3 Lite | .tflite | General semantic segmentation | TFLite Model Zoo | ~2 MB |
| Whisper Tiny | .tflite or .onnx | Caption generation from audio | OpenAI / HuggingFace | ~40 MB |
| Style Transfer | .tflite | Artistic style application | Magenta / TFLite Model Zoo | ~3 MB |
| Motion Tracking (RAFT-Lite or similar) | .tflite | Optical flow for motion tracking | Custom / Research models | ~10 MB |
| MobileNetV3 | .tflite | Scene classification (already defined) | TFLite Model Zoo | ~5 MB |

**Total estimated model payload: ~63 MB** (significant for APK size; requires on-demand download strategy)

---

## 5. Integration Points

### EditorCubit.applyAIActions() — Primary Integration Surface
- **Path:** `lib/features/editor/presentation/cubit/editor_cubit.dart`
- Currently receives `List<Map<String, dynamic>>` from parser and mutates state directly
- Must be refactored to delegate to an AICubit that runs inference before applying results
- Risk: tight coupling — changes here affect all AI command flows

### LocalAiEngine.runInference() — Inference Entry Point
- **Path:** `lib/features/ai_commands/services/local_ai_engine.dart`
- `TFLiteBackend.runInference(modelName, input)` is defined but never called from production code
- Must be wired into InferencePipelineService as the execution layer

### AiEngineBackend Interface — Abstraction Layer
- **Path:** `lib/features/ai_commands/services/local_ai_engine.dart`
- Abstract interface for swappable backends (TFLite, MediaPipe, remote API)
- Enables future server-side inference without client changes

### NativeBridge — GPU Acceleration Surface
- **Path:** `lib/core/engine/native_bridge.dart`
- FFI bridge to C++ with render acceleration and FFmpeg operations
- Future integration point for GPU-accelerated inference or frame-level processing
- Could expose TensorFlow Lite C API directly via FFI for better performance than tflite_flutter

### EffectType Enum — Data Contract
- **Path:** `lib/core/models/timeline_models.dart`
- `backgroundRemoval`, `motionTracking`, `stabilization`, `speedRamp`, `chromaKey`, `lumaKey`
- These are the effect types that AI services must produce results compatible with
- VideoClip.effects list is the container where AI results are stored

### AiCommandsPanel — User Interaction
- **Path:** `lib/features/editor/presentation/widgets/panels/ai_commands_panel.dart`
- UI entry point; must be updated to show inference progress, errors, model download states
- Currently calls parser then EditorCubit directly — must route through AICubit

### GetIt Service Locator — DI Container
- Currently only 1 service registered
- Must register AICubit, ModelDownloadService, InferencePipelineService, and all AI services

---

## 6. Risks

### Critical

1. **No tested inference path.** The entire AI pipeline from command to result has never been executed. TFLite model loading, inference, and result parsing are unverified. Any implementation may reveal fundamental issues with the `tflite_flutter` plugin on target platforms.

2. **tflite_flutter plugin maintenance.** The `tflite_flutter` package is community-maintained and has historically had long gaps between updates. Platform compatibility (especially iOS ARM64, Android x86_64) is not guaranteed. A plugin breakage would block all on-device inference.

3. **Missing model files with no download pipeline.** Without models, no AI feature works. Without a download service, models cannot be acquired at runtime. This is a blocking dependency for every AI feature.

### High

4. **MediaPipe Flutter support is immature.** The `google_mediapipe` Flutter plugin has limited platform support and unstable APIs. Background removal — the most prominent AI feature — depends on this. Fallback to TFLite segmentation is possible but lower quality.

5. **EditorCubit coupling.** AI logic in EditorCubit creates a monolith. Extracting it requires careful refactoring to avoid regressions in the existing editor state machine. The cubit is already ~400 lines with too many responsibilities.

6. **APK size impact.** Bundling all ML models adds ~63 MB. On-demand downloading requires storage permission handling, network error recovery, and user experience design (progress indicators, retry flows).

7. **GPU delegate device fragmentation.** TFLite GPU delegate availability varies by device, Android version, and GPU vendor (Adreno, Mali, PowerVR). Fallback to CPU is mandatory but inference speed may be unacceptable for video processing tasks.

### Medium

8. **GPL licensing conflict.** FFmpeg Kit uses GPL, which restricts distribution. If AI inference is combined with FFmpeg processing in the same pipeline, licensing complexity increases.

9. **Arabic NLP limitations.** The local fallback parser uses simple keyword matching for Arabic commands. This will fail on paraphrased or dialectal input. The server API is the intended solution but requires backend infrastructure that does not exist.

10. **No inference result validation.** `applyAIActions()` applies whatever the parser returns with no validation. Malformed or partial inference results could corrupt timeline state. The undo system uses temp JSON files, not Drift, so recovery from AI-induced corruption is fragile.

11. **Frame-level processing missing.** Video effects like background removal and motion tracking require per-frame inference. There is no frame extraction pipeline, no batch inference scheduler, and no mechanism to write processed frames back to the video. The current architecture only stores effect metadata — not processed video data.

### Low

12. **Model accuracy on mobile hardware.** Quantized models (necessary for mobile performance) may produce lower-quality results than their float32 counterparts. Background removal edges may be rough; captions may have higher word error rate.

13. **Concurrent inference conflicts.** Multiple AI commands running simultaneously could exhaust GPU/CPU resources. No queuing, cancellation, or resource management exists.

14. **No A/B testing infrastructure.** No mechanism to compare model versions or inference backends in production. Once a model is chosen, swapping it requires an app update or a model download service with versioning.
