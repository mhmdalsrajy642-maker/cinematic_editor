# AI ⇄ EditorCubit Integration

This document describes the integration layer between `AICubit` and `EditorCubit`.

## Goal

Route AI inference results produced by `AICubit` into editor timeline mutations while preserving existing undo/redo behavior.

## Integration Flow

1. `AiCommandsPanel` sends the user command text to `AICubit.executeCommand(...)`.
2. `AICubit` executes the command through `InferencePipelineService`.
3. When `AICubit` emits `AICompleted`, the panel listener receives the completed state.
4. The panel converts each `AIInferenceResult` into a compatible `Map<String, dynamic>` action.
5. The panel calls `EditorCubit.applyAIActions(actions)`.
6. `EditorCubit` applies actions against the current `TimelineState` and pushes the resulting timeline into the undo stack.

## Action Translation

- `applyColorGrade` → `apply_color_grade`
- `removeBackground` → `remove_background`
- `addMusic` → `add_music`
- `addTextCaption` → `add_text_caption`
- `generateCaptions` → `generate_captions`
- `applyMotionTracking` → `apply_motion_tracking`
- `stabilize` → `stabilize`
- `speedRamp` → `speed_ramp`

## Notes

- The panel preserves styling and local command history.
- No UI redesign was introduced.
- Undo/redo remains intact because the editor makes a single pushState after applying all AI actions.
- The integration layer exists in `lib/features/editor/presentation/widgets/panels/ai_commands_panel.dart`.
