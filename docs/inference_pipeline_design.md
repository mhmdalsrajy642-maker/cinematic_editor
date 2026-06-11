# Inference Pipeline Design

**Repository:** cinematic_editor
**Date:** 2026-06-11
**Status:** Architecture — implementation pending model availability

---

## Pipeline Flow

```
User Command
    |
    v
AiCommandParserService.parseCommand()
    |-- Server API (/ai/parse-command)
    |-- Local fallback (Arabic keyword detection)
    |
    v
List<Map<String, dynamic>> parsed actions
    |
    v
_buildRequest()  ─── Strongly typed AIInferenceRequest
    |-- _resolveActionType()     → AIActionType enum
    |-- _resolveModelForAction() → AIModelSelection enum
    |
    v
Action classification
    |
    ├── Data-only actions (no ML model needed)
    |       ├── apply_color_grade
    |       ├── add_text_caption
    |       ├── add_music
    |       ├── reduce_noise
    |       └── speed_ramp
    |       |
    |       v
    |   _resolveDataOnlyResult()
    |       → AIInferenceResult.dataOnly
    |           (VideoEffect, TextLayer, or AudioClip)
    |
    └── Inference-required actions
            ├── remove_background  → selfSegmentation
            ├── generate_captions  → whisperTiny
            ├── apply_motion_tracking → motionTracking
            └── stabilize          → motionTracking
            |
            v
        _ensureModelLoaded()
            |── Model exists in PredefinedModels? → load via LocalAiEngine
            └── No model definition? → return pendingInference
            |
            v
        Backend Selection (per action type)
            |── remove_background → BackgroundRemovalService
            |       |── MediaPipe Selfie (preferred, GPU)
            |       |── TFLite Self-Segmentation (fallback, CPU)
            |       └── Server API (last resort)
            |
            |── generate_captions → CaptionGenerationService (TBD)
            |── apply_motion_tracking → MotionTrackingService (TBD)
            └── stabilize → StabilizationService (TBD)
            |
            v
        Inference Execution
            |
            v
        Post-processing
            |── Segmentation mask → alpha mask → VideoEffect
            |── Caption tokens → timestamped TextLayers
            |── Motion vectors → keyframe data → VideoEffect
            |
            v
        AIInferenceResult
            |── .inferred     — full result with model output
            |── .pendingInference — no backend available, effect metadata only
            └── .failed       — error with message
```

---

## Type System

### AIInferenceRequest

| Field | Type | Description |
|---|---|---|
| rawCommand | `String` | Original user command text |
| actionType | `AIActionType` | Typed enum of the action |
| modelSelection | `AIModelSelection` | Which ML model is needed |
| targetClipId | `String?` | Clip to apply the action to |
| parameters | `Map<String, dynamic>` | Action-specific parameters |
| timelineState | `TimelineState` | Current timeline context |
| needsInference | `bool` | Whether ML inference is required |

### AIInferenceResult

| Field | Type | Description |
|---|---|---|
| actionType | `AIActionType` | Which action was executed |
| resultKind | `AIResultKind` | dataOnly / inferred / pendingInference |
| status | `AIInferenceStatus` | Pipeline step that completed |
| modelUsed | `AIModelSelection` | Which model ran (or was attempted) |
| backendUsed | `SegmentationBackend?` | Which backend ran |
| inferenceTime | `Duration` | Wall time for inference |
| errorMessage | `String?` | Error if failed |
| effect | `VideoEffect?` | Resulting video effect |
| textLayers | `List<TextLayer>?` | Generated captions |
| audioClip | `AudioClip?` | Generated audio |
| segmentationResult | `SegmentationResult?` | Per-frame mask data |
| clipSegmentationResult | `ClipSegmentationResult?` | Full clip processing result |

### AIInferenceStatus

Tracks where in the pipeline each request is:

`idle` → `parsingCommand` → `selectingModel` → `selectingBackend` → `loadingModel` → `runningInference` → `postProcessing` → `completed` / `failed` / `cancelled`

### AIResultKind

- **dataOnly** — No ML model was needed; result contains directly computed data
- **inferred** — ML inference ran successfully; result contains model output
- **pendingInference** — ML inference was required but no backend/model was available; result contains effect metadata only

---

## Service Dependencies

```
InferencePipelineService
    ├── AiCommandParserService   (command → parsed actions)
    ├── LocalAiEngine            (model loading, TFLite inference)
    └── BackgroundRemovalService (segmentation orchestration)
         ├── TFLiteSegmentationBackend
         │    └── LocalAiEngine
         ├── MediaPipeSegmentationBackend  (architecture stub)
         └── ServerApiSegmentationBackend  (architecture stub)
```

### Dependency Injection

```dart
// In service locator setup (GetIt or manual)
final aiEngine = LocalAiEngine();
final parserService = AiCommandParserService();
final bgRemovalService = BackgroundRemovalService.withDefaults(engine: aiEngine);
final pipelineService = InferencePipelineService(
  parserService: parserService,
  aiEngine: aiEngine,
  backgroundRemovalService: bgRemovalService,
);
```

---

## Action Type → Model → Backend Mapping

| Action Type | Model | Backend | Status |
|---|---|---|---|
| apply_color_grade | none | none (data-only) | Working |
| remove_background | selfSegmentation | TFLite / MediaPipe / Server | Architecture only |
| generate_captions | whisperTiny | TBD (TFLite / Server) | Architecture stub |
| apply_motion_tracking | motionTracking | TBD | Architecture stub |
| reduce_noise | none | none (data-only) | Working |
| add_music | none | none (data-only) | Working |
| add_text_caption | none | none (data-only) | Working |
| stabilize | motionTracking | TBD | Architecture stub |
| speed_ramp | none | none (data-only) | Working |

---

## EditorCubit Integration Point

The pipeline does NOT modify EditorCubit. Integration is designed as:

```dart
// Future AICubit pattern (not yet implemented):
final results = await pipelineService.executeCommand(
  command: userCommand,
  timelineState: state.timelineState,
);

// Convert AIInferenceResults to EditorCubit-compatible action maps
final actions = results
    .where((r) => r.isSuccess && r.effect != null)
    .map((r) => _resultToActionMap(r))
    .toList();

// Apply via existing EditorCubit method
context.read<EditorCubit>().applyAIActions(actions);
```

The `AIInferenceResult.effect` field is already a `VideoEffect` compatible with
`EditorCubit.applyEffectToClip()`. For results with `textLayers` or `audioClip`,
the caller maps them to the existing `add_text_caption` and `add_music` action formats.

---

## Progress Reporting

`AIProgressCallback` receives `AIInferenceProgress` at each pipeline step:

```dart
void onProgress(AIInferenceProgress progress) {
  // progress.status   — current pipeline step
  // progress.actionType — which action is being processed
  // progress.currentAction / totalActions — multi-action progress
  // progress.detail    — human-readable step description
}
```

For background removal specifically, frame-level progress is reported through
`SegmentationProgressCallback` which propagates up as `AIInferenceProgress`
with updated detail text showing frame count.

---

## Blocking Gaps

| Gap | Impact | Resolution |
|---|---|---|
| No .tflite model files | All inference actions return `pendingInference` | Model download service + asset pipeline |
| No frame extraction pipeline | Background removal cannot process clips | FFmpeg frame decoder service |
| No Whisper model | Caption generation returns `pendingInference` | Add model definition + audio extraction |
| No motion tracking model | Motion tracking / stabilization return `pendingInference` | Add optical flow model |
| MediaPipe not in pubspec | MediaPipe backend always reports unavailable | Add `google_mediapipe` dependency |
