// docs/native_bridge_contract.md
# Native Bridge API Contract

## Overview

The Native Bridge provides a Dart-to-C++ FFI interface for performance-critical operations in the Cinematic Editor. It is designed to handle:

1. **Render acceleration** - GPU-accelerated frame processing
2. **FFmpeg heavy operations** - Video decoding, encoding, and metadata extraction
3. **Timeline acceleration** - Multi-clip composition and caching
4. **Memory management** - Efficient buffer handling for large video data

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                  Dart Layer                           │
│  (UI, BLoCs, TimelineState, FFmpeg operations)       │
└──────────────────────┬───────────────────────────────┘
                       │
                       ↓
┌──────────────────────────────────────────────────────┐
│            lib/core/engine/native_bridge.dart         │
│         (Type-safe FFI wrapper for Dart)             │
└──────────────────────┬───────────────────────────────┘
                       │
                       ↓ FFI Bindings
┌──────────────────────────────────────────────────────┐
│         native/cpp/include/cinematic_bridge.h         │
│           (C function signatures - extern "C")        │
└──────────────────────┬───────────────────────────────┘
                       │
                       ↓ Implementation
┌──────────────────────────────────────────────────────┐
│     native/cpp/engine/ + ffmpeg_bridge/               │
│      (C++ implementations, placeholder stubs)         │
└──────────────────────────────────────────────────────┘
```

## Initialization and Lifecycle

### 1. Initialize the Bridge

**Dart:**
```dart
import 'package:cinematic_editor/core/engine/native_bridge.dart';

// Must be called once during app startup
final result = await NativeBridge.initialize();
if (!result.success) {
  print('Failed to initialize: ${result.errorMessage}');
}
```

**C++ (Backend):**
```cpp
// engine_init() is called
// - Initializes FFmpeg subsystem
// - Sets up GPU acceleration resources
// - Prepares memory pools
// Returns: 0 on success, error code otherwise
```

### 2. Use the Bridge

The bridge provides type-safe wrapper functions in Dart that call C++ implementations.

### 3. Shutdown the Bridge

**Dart:**
```dart
final result = await NativeBridge.shutdown();
if (!result.success) {
  print('Failed to shutdown: ${result.errorMessage}');
}
```

**C++ (Backend):**
```cpp
// engine_shutdown() is called
// - Closes FFmpeg resources
// - Releases GPU memory
// - Flushes pending operations
```

## Core API Sections

### Render Acceleration

Used for GPU-accelerated frame processing and real-time effects.

#### Create Render Context

**Purpose:** Initialize GPU resources for frame processing

**Dart:**
```dart
final result = NativeBridge.createRenderContext(
  width: 1920,
  height: 1080,
  fps: 30,
);

if (result.success) {
  final contextHandle = result.data!;
  // Use handle for subsequent operations
}
```

**C++:**
```cpp
int64_t handle = render_create_context(width, height, fps);
// Returns: Handle > 0 on success, 0 on failure
// This allocates GPU memory and prepares acceleration resources
```

**Parameters:**
- `width` (int32): Frame width in pixels (must be > 0)
- `height` (int32): Frame height in pixels (must be > 0)
- `fps` (int32): Frames per second (must be > 0)

**Returns:**
- Success: Context handle (int64, > 0)
- Failure: 0

**Error Codes:**
- `ERR_NOT_INITIALIZED` (-2): Engine not initialized
- `ERR_INVALID_PARAMETER` (-6): Invalid width/height/fps
- `ERR_RENDER_ERROR` (-8): GPU allocation failed

#### Apply Render Effect

**Purpose:** Apply GPU-accelerated effects to a frame

**Dart:**
```dart
final result = NativeBridge.applyRenderEffect(
  contextHandle: myContextHandle,
  effectType: RenderEffectType.blur,
  intensity: 0.5,
  inputFrame: frameBufferData,  // List<int> RGBA data
);

if (result.success) {
  print('Effect applied');
}
```

**C++:**
```cpp
int32_t result = render_apply_effect(
    handle, effect_id, intensity,
    input_buffer, input_size,
    output_buffer, output_size
);
// Returns: 0 on success, error code otherwise
```

**Effect Types:**
- `blur` (0)
- `brightness` (1)
- `contrast` (2)
- `saturation` (3)
- `hueShift` (4)
- `colorGrade` (5)

**Parameters:**
- `intensity` (float): Effect strength 0.0 to 1.0
- `inputFrame` (List<int>): RGBA8888 frame data
- Output written to native memory (see Memory Management)

### FFmpeg Operations

Heavy-duty video and audio processing operations.

#### Get Video Metadata

**Purpose:** Extract metadata without full decoding

**Dart:**
```dart
final result = NativeBridge.getVideoMetadata('/path/to/video.mp4');

if (result.success) {
  final metadata = result.data!;
  print('Resolution: ${metadata.width}x${metadata.height}');
  print('Duration: ${metadata.durationMs}ms');
  print('FPS: ${metadata.fps}');
}
```

**C++:**
```cpp
int32_t result = ffmpeg_get_metadata(
    file_path,
    &width, &height,
    &duration_ms, &fps
);
// Returns: 0 on success, error code otherwise
// Fast operation - doesn't decode frames
```

**Returns:**
- Success: `VideoMetadata` object
- Failure: null

#### Create Video Decoder

**Purpose:** Prepare for heavy frame decoding operations

**Dart:**
```dart
final result = NativeBridge.createVideoDecoder(
  '/path/to/video.mp4',
  hwaccel: HardwareAcceleration.auto,  // or .forced or .disabled
);

if (result.success) {
  final decoderHandle = result.data!;
  // Use for decoding frames
}
```

**C++:**
```cpp
int64_t handle = ffmpeg_create_decoder(file_path, hwaccel);
// Returns: Handle > 0 on success, 0 on failure
// Hwaccel: 0=disabled, 1=auto, 2=forced
```

**Parameters:**
- `filePath` (String): Full path to video file
- `hwaccel` (HardwareAcceleration): GPU acceleration mode

**Returns:**
- Success: Decoder handle (int64, > 0)
- Failure: 0

**Hardware Acceleration Modes:**
- `disabled` (0): Use software decoding
- `auto` (1): Use GPU if available, fallback to software
- `forced` (2): Fail if GPU not available

#### Release Video Decoder

**Purpose:** Free decoder resources

**Dart:**
```dart
final result = NativeBridge.releaseVideoDecoder(decoderHandle);
```

**C++:**
```cpp
int32_t result = ffmpeg_release_decoder(handle);
// Returns: 0 on success, error code otherwise
```

### Timeline Acceleration

Multi-clip composition and caching for timeline playback.

#### Create Timeline Context

**Purpose:** Prepare timeline processing with clip caching

**Dart:**
```dart
final result = NativeBridge.createTimelineContext(
  maxClips: 20,        // Maximum clips to manage
  cacheSizeMb: 512,    // Cache size in MB
);

if (result.success) {
  final timelineHandle = result.data!;
}
```

**C++:**
```cpp
int64_t handle = timeline_create_context(max_clips, cache_size_mb);
// Returns: Handle > 0 on success, 0 on failure
// Allocates internal clip registry and frame cache
```

**Parameters:**
- `maxClips` (int32): Maximum clips to cache (recommended: 10-50)
- `cacheSizeMb` (int32): Cache size in MB (recommended: 256-1024)

#### Register Timeline Clip

**Purpose:** Register a video file with the timeline context

**Dart:**
```dart
final result = NativeBridge.registerTimelineClip(
  contextHandle: timelineHandle,
  clipId: 1,                        // Unique clip ID
  filePath: '/path/to/clip1.mp4',
  startMs: 0,                       // Start time in timeline
  durationMs: 5000,                 // Clip duration
);
```

**C++:**
```cpp
int32_t result = timeline_register_clip(
    handle, clip_id, file_path,
    start_ms, duration_ms
);
// Returns: 0 on success, error code otherwise
```

**Parameters:**
- `clipId` (int32): Unique identifier for this clip (reuse after unregister)
- `filePath` (String): Full path to video file
- `startMs` (int64): Clip start time in timeline (milliseconds)
- `durationMs` (int64): Clip duration (milliseconds)

## Error Handling

All native functions return either:
- **Success value** (handle, data, etc.)
- **0 or -1** on failure

### Get Error Message

**Dart:**
```dart
final errorMsg = NativeBridge.getErrorMessage(errorCode);
```

**C++:**
```cpp
const char* msg = get_error_message(error_code);
// Returns: Human-readable error message
```

### Clear Error State

**Dart:** (Called automatically in wrappers)

**C++:**
```cpp
void clear_error(void);
// Clears thread-local error state
```

## Memory Management

### Buffer Allocation Strategy

1. **Input buffers**: Allocated by Dart (on Dart heap)
2. **Processing**: Transferred to native memory for processing
3. **Output buffers**: Allocated by native code (native heap)
4. **Return**: Results copied back to Dart memory

### Example: Processing a Frame

```dart
// 1. Load frame data in Dart
List<int> frameData = await loadFrameData(); // RGBA8888

// 2. Call native function
final result = NativeBridge.applyRenderEffect(
  contextHandle: handle,
  effectType: RenderEffectType.blur,
  intensity: 0.5,
  inputFrame: frameData,  // Dart heap
);

// 3. Native code:
//    - Receives frameData pointer
//    - Allocates output buffer on native heap
//    - Processes frame (blur)
//    - Returns processed data

// 4. Result data is copied back to Dart heap
if (result.success) {
  // Result is available in Dart memory
}
```

### Best Practices

1. **Reuse contexts**: Create context once, reuse many times
2. **Batch operations**: Process multiple frames with same context
3. **Release early**: Call release functions as soon as done
4. **Avoid copies**: Pass large buffers by reference when possible

## Logging and Debugging

### Set Log Callback (C++)

Used internally by the bridge to log operations.

**C++:**
```cpp
void log_callback(int32_t level, const char* message, void* user_data) {
    // level: 0=DEBUG, 1=INFO, 2=WARNING, 3=ERROR
    printf("[%d] %s\n", level, message);
}

set_log_callback(log_callback, nullptr);
```

### Get Performance Statistics

**Dart:**
```dart
// Get current performance stats from native layer
// (Returns JSON string)
```

**C++:**
```cpp
char stats[4096];
int64_t size = get_performance_stats(stats, sizeof(stats));
// Returns: Actual bytes written, -1 on error
```

## Thread Safety

### Important Notes

1. **Not thread-safe**: Most functions should be called from single thread
2. **FFI calls**: Can block Dart isolate
3. **Callbacks**: Executed on native thread
4. **State management**: Keep contexts on single thread

### Recommended Usage

```dart
// Use with proper threading model
class NativeEngineManager {
  late int _renderContext;
  late int _timelineContext;
  
  // Initialize on app start (main thread)
  Future<void> init() async {
    await NativeBridge.initialize();
    // ... create contexts
  }
  
  // Use contexts in consistent thread
  void processFrame(List<int> frameData) {
    // Called from same thread consistently
    final result = NativeBridge.applyRenderEffect(...);
  }
  
  // Cleanup on app exit
  Future<void> dispose() async {
    // ... release contexts
    await NativeBridge.shutdown();
  }
}
```

## Error Codes Reference

| Code | Name | Meaning |
|------|------|---------|
| 0 | `ERR_SUCCESS` | Operation successful |
| 1 | `ERR_ALREADY_INITIALIZED` | Engine already initialized |
| 2 | `ERR_NOT_INITIALIZED` | Engine not initialized |
| 3 | `ERR_INVALID_HANDLE` | Invalid handle provided |
| 4 | `ERR_MEMORY_ALLOCATION` | Memory allocation failed |
| 5 | `ERR_FILE_NOT_FOUND` | File not found |
| 6 | `ERR_INVALID_PARAMETER` | Invalid parameter |
| 7 | `ERR_FFMPEG_ERROR` | FFmpeg operation failed |
| 8 | `ERR_RENDER_ERROR` | Render operation failed |
| 99 | `ERR_UNKNOWN` | Unknown error |

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Android | Planned | ARM64 support required |
| iOS | Planned | Build as framework |
| macOS | Planned | Universal binary |
| Linux | Placeholder | Desktop testing |
| Windows | Placeholder | Desktop testing |

## Building the Native Library

### Requirements

- CMake 3.20+
- C++17 compiler
- FFmpeg 4.4+ development libraries
- (Optional) CUDA/OptiX for GPU acceleration

### Build Steps

```bash
# Create build directory
mkdir native/build
cd native/build

# Configure for your platform
cmake -DCMAKE_BUILD_TYPE=Release ..

# Build
cmake --build . --config Release

# Output: libcinematic_bridge.so (Linux)
#         libcinematic_bridge.dylib (macOS)
#         cinematic_bridge.dll (Windows)
#         libcinematic_bridge.a (iOS)
```

## Integration with Existing Code

### NOT integrated:
- UI widgets
- BLoC patterns
- State management
- Cubits

### IS integrated:
- FFI type signatures
- Memory management
- Error handling
- Platform detection

### Integration Points for Future

1. **In TimelineEditorBloc**: Call `NativeBridge.renderFrame()` for GPU processing
2. **In FFmpegService**: Use decoders from `NativeBridge` instead of plugin
3. **In EffectsPanel**: Use `RenderEffectType` enum for native effects

## Deprecated/Removed APIs

None yet - this is v1.0.0 of the contract.

## Future Enhancements

1. **Async processing**: Non-blocking frame processing
2. **Streaming decode**: Decode while encoding (for exports)
3. **GPU effects**: Comprehensive GPU-based effect library
4. **AI acceleration**: TensorFlow Lite integration for effects
5. **Color grading**: Advanced color grading pipeline

## Support and Troubleshooting

### Common Issues

**"Bridge not initialized"**
- Solution: Call `await NativeBridge.initialize()` first

**"Failed to load dynamic library"**
- Solution: Ensure binary is compiled for target platform

**"Invalid handle"**
- Solution: Don't reuse released handles

**"Segmentation fault"**
- Solution: Check buffer sizes and memory bounds

---

**Version:** 1.0.0  
**Last Updated:** 2026-06-10  
**Maintenance:** Active development
