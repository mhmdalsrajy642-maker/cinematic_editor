// docs/native_architecture.md
# Native Architecture and Integration

## System Overview

The native acceleration layer is designed as an isolated performance component that integrates with the existing Dart/Flutter codebase.

```
┌─────────────────────────────────────────────────────────────┐
│                    Cinematic Editor App                      │
│                    (Dart/Flutter)                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              BLoC Layer                              │   │
│  │  (EditorBloc, TimelineBloc, EffectsBloc)            │   │
│  └──────────────────────┬────────────────────────────┬─┘   │
│                         │                            │      │
│  ┌──────────────────────↓──────┐ ┌──────────────────↓──┐   │
│  │   TimelineState Model        │ │  FFmpegService    │   │
│  │  (Clips, Layers, Effects)    │ │  (Video ops)      │   │
│  └──────────────────────┬──────┘ └──────────────────┬──┘   │
│                         │                            │      │
│  ┌──────────────────────↓────────────────────────────↓──┐   │
│  │        NativeBridge (lib/core/engine/native_bridge) │   │
│  │  (Type-safe FFI wrapper for Dart)                   │   │
│  └──────────────────────┬────────────────────────────┬──┘   │
│                         │                            │      │
└─────────────────────────┼────────────────────────────┼──────┘
                          │                            │
                    FFI Bindings          FFI Bindings │
                          │                            │
┌─────────────────────────↓────────────────────────────↓──────┐
│            Native Layer (C++, extern "C")                    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Header: cinematic_bridge.h                        │    │
│  │  - Render acceleration functions                   │    │
│  │  - FFmpeg bridge functions                         │    │
│  │  - Timeline acceleration                          │    │
│  │  - Error handling                                  │    │
│  └────────────────────────────────────────────────────┘    │
│                         │                                   │
│  ┌──────────────────────↓──────────────┐                   │
│  │ Implementation                       │                   │
│  │  ├─ engine.cc (core engine)          │                   │
│  │  └─ ffmpeg_bridge.cc (video ops)     │                   │
│  └──────────────────────────────────────┘                   │
│                         │                                   │
│  ┌──────────────────────↓──────────────────────┐            │
│  │ Optional: External Libraries (Future)        │            │
│  │  ├─ FFmpeg (libavformat, libavcodec)         │            │
│  │  ├─ Vulkan/Metal (GPU acceleration)          │            │
│  │  └─ TensorFlow Lite (AI effects)             │            │
│  └──────────────────────────────────────────────┘            │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Layer Separation

### NOT Exposed (Dart/Flutter Side)
- ❌ UI Widgets
- ❌ BLoC patterns
- ❌ State management
- ❌ Cubits
- ❌ Material design
- ❌ User input handling

### IS Exposed (Native Side)
- ✅ Render acceleration hooks
- ✅ FFmpeg operations
- ✅ Timeline composition
- ✅ Memory management
- ✅ Error codes
- ✅ Logging callbacks

### Interface Layer (native_bridge.dart)
- Dart FFI bindings
- Type conversion (Dart ↔ C)
- Result wrapper classes
- Resource management
- Platform detection

## Call Flow Examples

### Example 1: Rendering a Frame with GPU Acceleration

```
Dart/Flutter:
1. User moves clip on timeline
2. EditorBloc emits state change
3. UI rebuilds with new frame data
4. Preview widget calls NativeBridge.applyRenderEffect()

NativeBridge (Dart):
5. Validate parameters
6. Convert to native types
7. Call C function via FFI
8. Handle result

Native C++:
9. Receive effect request in render_apply_effect()
10. Validate parameters
11. [Placeholder] Copy buffer or [Future] Apply GPU effect
12. Return result code

NativeBridge (Dart):
13. Check result
14. Wrap in NativeBridgeResult
15. Return to caller

EditorBloc:
16. Update state with processed frame
17. UI updates
```

### Example 2: Getting Video Metadata

```
Dart/Flutter (FFmpegService):
1. User adds video clip
2. FFmpegService.getVideoMetadata(filePath)
3. Calls NativeBridge.getVideoMetadata()

NativeBridge (Dart):
4. Wrap path in native pointer
5. Call ffmpeg_get_metadata()

Native C++:
6. Parse file path
7. [Placeholder] Return dummy metadata
8. [Future] Actually call FFmpeg to extract metadata
9. Return result

NativeBridge (Dart):
10. Convert result to VideoMetadata object
11. Return to FFmpegService

FFmpegService (Dart):
12. Use metadata (width, height, duration) to create clip
13. Update TimelineState
14. Notify BLoC
```

### Example 3: Timeline Composition

```
EditorBloc (Preview rendering):
1. Timeline has 3 clips at same timestamp
2. Need to composite them
3. Calls NativeBridge.createTimelineContext()
4. Registers each clip via registerTimelineClip()
5. Calls compositeAtTime() for current timestamp

NativeBridge:
6. FFI calls to native layer
7. Returns composite frame data

EditorBloc:
8. Receives composite frame
9. Updates preview
10. UI displays composite
```

## Memory Management Strategy

### Memory Ownership

```
Dart Heap:
- TimelineState (clips, layers, metadata)
- UI state and widgets
- User input events

Native Heap (allocated by FFI):
- Video decoder contexts
- Frame buffers during processing
- Timeline context state
- Audio encoder buffers

Shared Responsibility:
- Input buffers: Dart allocates, passes to native
- Output buffers: Native allocates, passes to Dart
- Contexts: Native allocates and manages via handles
```

### Buffer Lifecycle

```
1. Dart creates frame buffer (List<int>)
   ↓
2. Frame displayed in preview
   ↓
3. User applies effect
   ↓
4. Dart converts to native pointer
   ↓
5. Native processes frame
   ↓
6. Result returned to Dart
   ↓
7. Dart updates UI
   ↓
8. Garbage collection eventually frees original buffer
```

## Error Handling Flow

```
Native C++:
1. Function detects error (invalid parameter)
2. Returns error code (-6 for ERR_INVALID_PARAMETER)
3. Sets g_last_error state

NativeBridge (Dart):
4. Receives error code
5. Calls get_error_message(error_code)
6. Gets human-readable error
7. Wraps in NativeBridgeResult(success: false, errorMessage: ...)

EditorBloc / Caller:
8. Checks result.success
9. If false, displays error to user or logs
10. Takes appropriate action (retry, fallback, cancel)
```

## Integration Points with Existing Code

### 1. FFmpegService Integration (Future)

**Current:** Uses `ffmpeg_kit_flutter` plugin
**Future:** Could use native bridge

```dart
// OLD (current)
class FFmpegService {
  Future<VideoMetadata> getMetadata(String path) async {
    // Uses ffmpeg_kit_flutter plugin
  }
}

// NEW (using native bridge)
class FFmpegService {
  Future<VideoMetadata> getMetadata(String path) async {
    final result = NativeBridge.getVideoMetadata(path);
    if (result.success) {
      return result.data!;
    }
    throw Exception(result.errorMessage);
  }
}
```

### 2. TimelineEditorBloc Integration (Future)

**Current:** Purely Dart/Flutter state management
**Future:** Could offload heavy ops to native

```dart
class TimelineEditorBloc extends Bloc<TimelineEvent, TimelineState> {
  Future<void> _onPreviewRequested(
    TimelinePreviewRequested event,
    Emitter<TimelineState> emit,
  ) async {
    // Create timeline context for composition
    final result = NativeBridge.createTimelineContext(
      maxClips: event.clips.length,
      cacheSizeMb: 512,
    );
    
    if (result.success) {
      // Register clips
      for (final clip in event.clips) {
        NativeBridge.registerTimelineClip(
          contextHandle: result.data!,
          clipId: clip.id,
          filePath: clip.path,
          startMs: clip.startMs,
          durationMs: clip.durationMs,
        );
      }
      
      // Composite at current time
      final composite = NativeBridge.compositeAtTime(...);
      
      // Update UI with composite frame
      emit(state.copyWith(previewFrame: composite));
    }
  }
}
```

### 3. EffectsPanel Integration (Future)

**Current:** Effects are theoretical
**Future:** Could use GPU acceleration

```dart
class EffectsPanel extends StatelessWidget {
  void _applyBlur(double intensity) {
    final result = NativeBridge.applyRenderEffect(
      contextHandle: _renderContext,
      effectType: RenderEffectType.blur,
      intensity: intensity,
      inputFrame: _currentFrame,
    );
    
    if (result.success) {
      setState(() => _currentFrame = result.data);
    }
  }
}
```

## Platform-Specific Considerations

### Android

- FFI through NDK
- Compiled as `.so` (shared object)
- Loaded via `DynamicLibrary.open('libcinematic_bridge.so')`
- GPU acceleration via Vulkan or native Android graphics

### iOS

- FFI through native code
- Compiled as `.a` (static library)
- Linked into app binary
- GPU acceleration via Metal

### macOS

- FFI through native code
- Compiled as `.dylib` (shared object)
- GPU acceleration via Metal or Vulkan

### Linux

- FFI through glibc
- Compiled as `.so` (shared object)
- GPU acceleration via Vulkan

### Windows

- FFI through Windows DLL interface
- Compiled as `.dll` (dynamic library)
- GPU acceleration via Direct3D 12

## Performance Targets

### Current (Placeholder)

- ✓ FFI overhead: < 1ms per call
- ✓ Memory usage: < 10MB overhead
- ✓ No actual video processing (passthrough)

### Phase 2 (After Full Implementation)

- ⏳ Frame decode: < 50ms (1080p60)
- ⏳ Frame composite: < 30ms (2 clips)
- ⏳ Effect application: < 20ms per effect
- ⏳ GPU utilization: 30-60% for real-time ops

## Testing Strategy

### Unit Tests

Location: `native/test/` (to be created)

```cpp
// Test render context creation
TEST(EngineTest, CreateRenderContext) {
  int64_t handle = render_create_context(1920, 1080, 30);
  EXPECT_GT(handle, 0);
  
  int32_t result = render_release_context(handle);
  EXPECT_EQ(result, 0);
}
```

### Integration Tests

Location: `lib/core/engine/native_bridge_test.dart` (to be created)

```dart
test('Can initialize bridge', () async {
  final result = await NativeBridge.initialize();
  expect(result.success, true);
  
  final shutdown = await NativeBridge.shutdown();
  expect(shutdown.success, true);
});
```

### Performance Tests

Location: `integration_test/native_performance_test.dart` (to be created)

```dart
void main() {
  testWidgets('Render effect performance', (WidgetTester tester) async {
    final stopwatch = Stopwatch()..start();
    
    for (int i = 0; i < 100; i++) {
      NativeBridge.applyRenderEffect(...);
    }
    
    stopwatch.stop();
    expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // < 50ms per frame
  });
}
```

## Security Considerations

### Memory Safety

- ✓ Buffer bounds checking in wrapper
- ✓ Null pointer validation
- ✓ Size validation before memcpy
- ⏳ Fuzz testing (future)

### Input Validation

- ✓ File path validation (native function)
- ✓ Handle validation (range check)
- ✓ Parameter bounds checking
- ⏳ Sandboxing (future)

### GPU Security

- ⏳ Shader validation (future)
- ⏳ Resource limits (future)
- ⏳ Denial-of-service protection (future)

## Future Enhancements

### Phase 2: Real FFmpeg Integration

- Implement actual FFmpeg calls
- Add hardware acceleration (VA-API, NVENC, VideoToolbox)
- Support codec selection
- Add streaming decode

### Phase 3: GPU Effects

- Implement GPU effects library
- Add real-time preview
- Parallel effect processing
- Memory pooling

### Phase 4: AI Acceleration

- TensorFlow Lite integration
- AI-based effects (style transfer, upscaling)
- Real-time inference
- Model caching

### Phase 5: Advanced Features

- Timeline GPU composition
- Concurrent encode/decode
- Streaming export
- Live preview optimization

## Troubleshooting Guide

### Issue: "libcinematic_bridge.so not found"

**Cause:** Binary not compiled or not in library path
**Solution:** 
1. Build with cmake
2. Ensure binary is in correct platform directory
3. Check Flutter build output

### Issue: "Invalid handle passed"

**Cause:** Using released handle or invalid handle value
**Solution:**
1. Don't release contexts twice
2. Use correct handle returned from creation
3. Verify handle is still valid before use

### Issue: "Segmentation fault in native code"

**Cause:** Buffer overflow or null pointer dereference
**Solution:**
1. Check buffer sizes in wrapper
2. Add validation in native code
3. Use AddressSanitizer for debugging
4. Check for null pointers

### Issue: "Performance is slow"

**Cause:** Running placeholder implementations or processing on wrong thread
**Solution:**
1. Profile with platform tools (perf, Instruments)
2. Verify GPU acceleration is enabled
3. Check thread affinity
4. Optimize hot paths

---

**Document Version:** 1.0.0  
**Last Updated:** 2026-06-10  
**Status:** Active Design Phase
