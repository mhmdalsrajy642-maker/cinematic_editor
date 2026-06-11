// native/README.md
# Native Acceleration Layer

This directory contains the C++ native code for the Cinematic Editor's acceleration layer.

## Structure

```
native/
├── CMakeLists.txt              # Build configuration
├── cpp/
│   ├── include/
│   │   └── cinematic_bridge.h  # Main API header (C extern)
│   ├── engine/
│   │   └── engine.cc           # Core engine implementation
│   └── ffmpeg_bridge/
│       └── ffmpeg_bridge.cc    # FFmpeg operations
└── README.md                   # This file
```

## Architecture

### Header: `cinematic_bridge.h`

- Defines all C function signatures exposed via FFI
- Marked with `extern "C"` for C linkage
- No C++ language features (templates, classes, exceptions)
- All functions take simple C types (int, float, pointers)

### Implementation: `engine.cc`

- Core engine lifecycle (init/shutdown)
- Render acceleration hooks
- Timeline acceleration stubs
- Error handling and logging
- Thread-safe state management

### Implementation: `ffmpeg_bridge.cc`

- FFmpeg wrapper functions
- Video decoder context management
- Audio encoder context management
- Metadata extraction
- Placeholder implementations (ready for full FFmpeg)

## Building

### Quick Build (Linux/macOS)

```bash
mkdir native/build
cd native/build
cmake -DCMAKE_BUILD_TYPE=Release ..
cmake --build . --config Release
```

### Building for Android (via Flutter)

The Android build is handled by Flutter's native build system:

```bash
flutter build apk --release
```

Flutter will:
1. Invoke CMake for the native layer
2. Build with Android NDK
3. Link into the APK

### Building for iOS (via Flutter)

```bash
flutter build ios --release
```

### Building for macOS

```bash
cd native
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" ..
cmake --build . --config Release
```

## Key Concepts

### 1. No C++ Features in API

All exported functions use C conventions:
- No classes or virtual methods
- No exceptions (use error codes)
- No STL containers in signatures
- No templates

**Why:** Ensures ABI compatibility across platforms and compilers.

### 2. Handle-based Resources

Context objects (render, decoder, timeline) are opaque handles:

```cpp
int64_t handle = render_create_context(width, height, fps);
// Use handle
render_process_frame(handle, ...);
// Release
render_release_context(handle);
```

**Why:** Allows internal C++ implementation while maintaining C API.

### 3. Placeholder Implementations

Current implementations are placeholders that:
- Validate parameters
- Return success/error codes
- Are ready for real implementations

They don't actually:
- Use GPU resources
- Call FFmpeg
- Process video frames

**How to extend:**
1. Replace placeholder bodies with actual code
2. Add necessary #include for libraries
3. Update CMakeLists.txt for dependencies
4. Test on target platform

### 4. Error Codes

All functions return error codes:
- 0 = Success
- Negative = Error
- Handle functions return handle > 0 or 0 on error

## Performance Considerations

### Current Status: Placeholders

The implementation is structurally complete but functionally stubbed:
- ✓ API design finalized
- ✓ FFI bindings ready
- ✓ Memory layout defined
- ⏳ Heavy lifting (GPU, FFmpeg) pending

### When Implementing Real Code

1. **GPU Acceleration**
   - Consider: Vulkan, Metal, Direct3D 12
   - Keep platform-agnostic header
   - Use #ifdef for platform-specific code

2. **FFmpeg Integration**
   - Link against libavformat, libavcodec, libavutil
   - Use hardware acceleration (VA-API, NVENC, VideoToolbox)
   - Implement frame caching for timeline

3. **Memory Management**
   - Pre-allocate buffers for hot paths
   - Use object pools for contexts
   - Avoid allocations in frame processing

4. **Threading**
   - Keep FFI calls single-threaded
   - Use worker threads internally
   - Protect shared state with locks

## Dependencies

### Required
- C++17 compiler
- CMake 3.20+

### Optional (for real implementations)
- FFmpeg 4.4+ (libavformat, libavcodec, libavutil)
- Vulkan SDK (for GPU acceleration)
- NVIDIA CUDA (for GPU video decoding)
- Metal SDK (for iOS/macOS GPU acceleration)

### Current Status
- ✓ Header-only implementation
- ✓ No external dependencies
- ⏳ Will add dependencies when full implementation begins

## Compilation Issues

### "Cannot find FFmpeg"

This is expected - FFmpeg integration is not yet implemented. To add it:

1. Install FFmpeg development libraries:
   ```bash
   # Ubuntu/Debian
   sudo apt-get install libavformat-dev libavcodec-dev libavutil-dev
   
   # macOS
   brew install ffmpeg
   ```

2. Uncomment FFmpeg section in CMakeLists.txt

3. Update includes in .cc files

### Platform-specific issues

**Linux:**
```bash
# Install all dev libraries
sudo apt-get install build-essential cmake
```

**macOS:**
```bash
# Install Xcode command line tools
xcode-select --install
```

**Windows:**
```cmd
# Install Visual Studio 2019+ with C++ tools
# Install CMake 3.20+
```

**Android (NDK):**
- Handled by Flutter
- Uses `ndk-build` or CMake
- No manual compilation needed

## Debugging

### Enable Debug Symbols

```bash
cmake -DCMAKE_BUILD_TYPE=Debug ..
```

### Enable Logging

In Dart:
```dart
NativeBridge.setLogCallback((level, message, userData) {
  print('[$level] $message');
});
```

### Performance Profiling

```bash
# Linux with perf
perf record -g ./app
perf report

# macOS with Instruments
xcrun xctrace record --template 'System Trace' ./app
```

## Testing

### Unit Tests (Future)

```bash
cd native/build
cmake --target test
```

### Integration Tests (From Dart)

See `lib/core/engine/native_bridge.dart` for test examples.

## Documentation

- **API Contract**: See `docs/native_bridge_contract.md`
- **Dart FFI**: See `lib/core/engine/native_bridge.dart`
- **C Header**: See `native/cpp/include/cinematic_bridge.h`

## Contributing

When extending the native layer:

1. Keep header in C (no C++ features)
2. Update CMakeLists.txt for new files
3. Add documentation to contract
4. Test on multiple platforms
5. Benchmark hot paths

## Future Work

- [ ] Full FFmpeg integration
- [ ] GPU acceleration (Vulkan/Metal)
- [ ] Timeline caching optimization
- [ ] Streaming decode
- [ ] Real-time effects library
- [ ] TensorFlow Lite integration

## Support

For issues or questions:
- Check `docs/native_bridge_contract.md` for API docs
- Review examples in `lib/core/engine/native_bridge.dart`
- Check CMake output for build errors
