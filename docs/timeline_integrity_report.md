# Timeline Integrity Report

## Summary
This report audits timeline model compatibility across AI command handling, text/caption generation, motion/stabilization effects, preview rendering, and export pipeline integration.

The timeline models in `lib/core/models/timeline_models.dart` provide a coherent structure for `VideoClip`, `AudioClip`, `TextLayer`, and `TimelineState`, but several practical gaps remain between the data model and the downstream AI/export/rendering implementation.

## Timeline Model Coverage

### Core timeline fields
- `VideoClip` includes: `id`, `originalPath`, `proxyPath`, `startTime`, `endTime`, `clipStartOffset`, `clipEndOffset`, `trackIndex`, `volume`, `speed`, `effects`, `transform`, `thumbnailPath`, `isMuted`, `clipType`.
- `AudioClip` includes: `id`, `filePath`, `startTime`, `endTime`, `audioOffset`, `volume`, `fadeInDuration`, `fadeOutDuration`, `trackIndex`, `isMuted`, `audioType`.
- `TextLayer` includes: `id`, `text`, `startTime`, `endTime`, `style`, `transform`, `animation`, `isSubtitle`.
- `TimelineState` includes: `projectId`, `videoClips`, `audioClips`, `textLayers`, `totalDuration`, `videoTrackCount`, `audioTrackCount`, `settings`.

### Serialization
- Timeline models implement `toJson` / `fromJson` for persistence.
- `TextLayer.fromJson` supports a legacy fallback when `style` is missing by reading `styleColor`, `styleFontSize`, and `styleFontWeight`.
- `TimelineState.fromJson` gracefully defaults missing `totalDuration`, `videoTrackCount`, `audioTrackCount`, and `settings`.

## Compatibility Findings

### 1. Export pipeline ignores many AI effect types
- `lib/features/export/domain/ffmpeg_command_builder.dart` only translates these effect types:
  - `brightness`
  - `contrast`
  - `saturation`
  - `temperature`

- AI-driven timeline effects such as:
  - `EffectType.backgroundRemoval`
  - `EffectType.motionTracking`
  - `EffectType.stabilization`
  - `EffectType.speedRamp`
  - `EffectType.chromakey` / `EffectType.lumaKey` / `EffectType.glitch`
  are not implemented in `_buildEffectFilter`.

Impact:
- Exported video may omit important timeline effects produced by AI actions or editor workflows.
- Motion tracking, stabilization, and background removal metadata can be stored in the timeline without ever being applied during export.

### 2. `AudioClip.audioOffset` is not used during export
- `AudioClip` stores `audioOffset`, but `FFmpegCommandBuilder._buildAudioFilters()` only applies `startTime`, `volume`, and fades.
- This means an audio clip whose source should begin partway through the file will likely render from the file start instead of the intended offset.

Impact:
- Audio clips may be desynchronized from intended timeline source offsets.
- `audioOffset` support appears incomplete in the export layer.

### 3. Manual `totalDuration` can drift from clip data
- `TimelineState` stores `totalDuration` separately from its `calculatedDuration` getter.
- Editor actions like `addVideoClip`, `addAudioClip`, and specific timeline mutations recalc `totalDuration`, but AI action flows such as `EditorCubit.applyAIActions()` do not update it after adding text layers, audio clips, or video effects.

Impact:
- `TimelineState.totalDuration` can become stale and inconsistent with actual clip endpoints.
- Since `RenderGraph` and UI code may rely on `timelineState.totalDuration`, playback and export coordination can diverge.

### 4. Text layer ordering and subtitle semantics are weakly defined
- `TextLayer` has no explicit `trackIndex` or z-order field.
- `RenderGraph` derives layer order from `textLayer.transform.y.round()` and uses `style.color == 0` as a visibility sentinel.

Impact:
- Render order for text overlays is implicitly tied to Y position, which is not an explicit ordering mechanism.
- This can produce unpredictable text stacking and subtitle layering during preview.

### 5. Export text rendering is limited and loses animation semantics
- `FFmpegCommandBuilder._buildTextFilters()` converts each `TextLayer` to a static `drawtext` filter using `text.transform.x`, `text.transform.y`, `style.fontSize`, `style.color`, and `transform.opacity`.
- `TextLayer.animation` and `isSubtitle` are not mapped to export filters.

Impact:
- Animated text behavior defined in the timeline model is not preserved in export.
- Subtitle semantics are captured in the model but not treated differently during export.

### 6. `VideoTransform` semantics are partially used
- `VideoTransform` records `x`, `y`, `scaleX`, `scaleY`, `rotation`, and `opacity`.
- `FFmpegCommandBuilder` only uses `x`, `y`, and `opacity`.

Impact:
- scale and rotation transformations are not applied in export, reducing fidelity between timeline preview and final output.

### 7. JSON compatibility risks for older/incomplete timeline payloads
- `VideoClip.fromJson()` expects `effects` and `transform` to exist and will throw if `effects` is missing or not a list.
- `TextLayer.fromJson()` expects `transform` and `animation` to exist.
- `TimelineState.fromJson()` handles some missing top-level values, but nested objects remain strict.

Impact:
- Older snapshots or partial timeline payloads may fail to deserialize cleanly if nested fields are absent.
- Backward compatibility is only partially protected.

### 8. AI command parser uses limited timeline context
- `AiCommandParserService._buildTimelineContext()` sends only summary fields:
  - `total_duration`
  - `video_clips_count`
  - `audio_clips_count`
  - `video_clip_ids`
  - `has_audio`
  - `resolution`

Impact:
- AI parsing is robust to timeline state changes, but it cannot leverage detailed clip geometry, durations, track indices, or effect metadata when interpreting commands.
- This is acceptable for high-level command parsing but means some AI commands may lack fine-grained timeline awareness.

## Cross-Module Observations

### AI -> Timeline Integration
- `InferencePipelineService` uses `TimelineState` to find target clips by ID for background removal and motion tracking.
- Caption generation creates `TextLayer` instances using `TextLayer.create()` and attaches them as data-only results.
- Motion tracking and stabilization currently return `AIInferenceResult.pendingInference` with `VideoEffect` metadata, not fully realized timeline updates.

### Editor timeline updates
- `EditorCubit.applyAIActions()` applies many AI action types directly to `TimelineState`.
- It does not recalculate `totalDuration` after generative actions that add clips or layers.

### Export pipeline alignment
- `FFmpegCommandBuilder` reads `VideoClip` and `AudioClip` fields correctly for basic media composition.
- Its effect mapping is limited to a small subset of timeline metadata, leaving advanced AI effects unexported.
- Text layer export uses standard `drawtext` but omits animation and subtitle-specific handling.

## Recommendations

1. Reconcile `TIMELINE_STATE.totalDuration` by introducing a centralized duration recalculation step after any timeline mutation, including AI action application.
2. Extend `FFmpegCommandBuilder` to honor timeline effect types beyond color grade, especially:
   - `backgroundRemoval`
   - `motionTracking`
   - `stabilization`
   - `speedRamp`
3. Use `AudioClip.audioOffset` when generating audio export filters.
4. Add explicit text layer ordering or z-index metadata to `TextLayer` instead of deriving order from `transform.y`.
5. Map `TextLayer.animation` and `isSubtitle` to export or preview semantics if the feature is intended to survive rendering.
6. Harden JSON deserialization for `VideoClip` and `TextLayer` to tolerate missing legacy fields.
7. Consider enriching AI timeline context with clip duration/track and active effect flags if command parsing needs finer detail.

## Risky Files
- `lib/core/models/timeline_models.dart`
- `lib/features/export/domain/ffmpeg_command_builder.dart`
- `lib/features/ai_commands/services/inference_pipeline_service.dart`
- `lib/features/ai_commands/services/ai_command_parser_service.dart`
- `lib/features/editor/presentation/cubit/editor_cubit.dart`
- `lib/core/engine/render_graph.dart`

## Conclusion
The repository’s timeline model is structurally complete for basic video, audio, and text layer workflows. However, export and preview layers do not fully implement the model’s richer AI-driven effect and transform semantics. Key integrity gaps include stale timeline duration metadata, unhandled audio offsets, incomplete effect export coverage, and weak text-layer ordering semantics.

Addressing these gaps will improve timeline fidelity across AI generation, preview rendering, and final export.
