// lib/core/engine/native_bridge.dart
// Dart FFI bridge to native C++ acceleration layer
// This file provides type-safe access to native functionality

import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';

// ====================================================
// FFI Bindings Definition
// ====================================================

/// Main FFI interface to native bridge
class _CinematicBridgeFFI {
  final DynamicLibrary _lib;

  // Version functions
  late final Pointer<Utf8> Function() _getVersion;
  late final Pointer<Utf8> Function() _getBuildTimestamp;

  // Engine lifecycle
  late final int Function() _engineInit;
  late final int Function() _engineShutdown;
  late final int Function() _engineIsInitialized;

  // Render acceleration
  late final int Function(int, int, int) _renderCreateContext;
  late final int Function(int) _renderReleaseContext;
  late final int Function(int, Pointer<Uint8>, int, Pointer<Uint8>, int)
      _renderProcessFrame;
  late final int Function(int, int, double, Pointer<Uint8>, int,
      Pointer<Uint8>, int) _renderApplyEffect;

  // FFmpeg bridge
  late final int Function() _ffmpegInit;
  late final int Function() _ffmpegShutdown;
  late final Pointer<Utf8> Function() _ffmpegGetVersion;
  late final int Function(Pointer<Utf8>, int) _ffmpegCreateDecoder;
  late final int Function(int) _ffmpegReleaseDecoder;
  late final int Function(int, int, Pointer<Uint8>, int) _ffmpegDecodeFrame;
  late final int Function(Pointer<Utf8>, Pointer<Int32>, Pointer<Int32>,
      Pointer<Int64>, Pointer<Float>) _ffmpegGetMetadata;
  late final int Function(Pointer<Utf8>, int, int, int)
      _ffmpegCreateAudioEncoder;
  late final int Function(int) _ffmpegReleaseAudioEncoder;
  late final int Function(int, Pointer<Float>, int) _ffmpegEncodeAudio;

  // Timeline acceleration
  late final int Function(int, int) _timelineCreateContext;
  late final int Function(int) _timelineReleaseContext;
  late final int Function(int, int, Pointer<Utf8>, int, int)
      _timelineRegisterClip;
  late final int Function(int, int) _timelineUnregisterClip;
  late final int Function(int, int, Pointer<Int32>, int, Pointer<Uint8>, int)
      _timelineCompositeAtTime;

  // Error handling
  late final Pointer<Utf8> Function(int) _getErrorMessage;
  late final void Function() _clearError;

  // Logging and debugging
  late final int Function(Pointer<NativeFunction<_LogCallbackNative>>,
      Pointer<Void>) _setLogCallback;
  late final int Function(Pointer<Utf8>, int) _getPerformanceStats;

  _CinematicBridgeFFI(this._lib) {
    _initializeBindings();
  }

  void _initializeBindings() {
    // Version functions
    _getVersion = _lib
        .lookup<NativeFunction<Pointer<Utf8> Function()>>(
            'get_bridge_version')
        .asFunction();
    _getBuildTimestamp = _lib
        .lookup<NativeFunction<Pointer<Utf8> Function()>>(
            'get_build_timestamp')
        .asFunction();

    // Engine lifecycle
    _engineInit = _lib
        .lookup<NativeFunction<Int32 Function()>>('engine_init')
        .asFunction();
    _engineShutdown = _lib
        .lookup<NativeFunction<Int32 Function()>>('engine_shutdown')
        .asFunction();
    _engineIsInitialized = _lib
        .lookup<NativeFunction<Int32 Function()>>('engine_is_initialized')
        .asFunction();

    // Render acceleration
    _renderCreateContext = _lib
        .lookup<NativeFunction<Int64 Function(Int32, Int32, Int32)>>(
            'render_create_context')
        .asFunction();
    _renderReleaseContext = _lib
        .lookup<NativeFunction<Int32 Function(Int64)>>(
            'render_release_context')
        .asFunction();
    _renderProcessFrame = _lib
        .lookup<
            NativeFunction<
                Int64 Function(Int64, Pointer<Uint8>, Int64, Pointer<Uint8>,
                    Int64)>>('render_process_frame')
        .asFunction();
    _renderApplyEffect = _lib
        .lookup<
            NativeFunction<
                Int32 Function(Int64, Int32, Float, Pointer<Uint8>, Int64,
                    Pointer<Uint8>, Int64)>>('render_apply_effect')
        .asFunction();

    // FFmpeg bridge
    _ffmpegInit = _lib
        .lookup<NativeFunction<Int32 Function()>>('ffmpeg_init')
        .asFunction();
    _ffmpegShutdown = _lib
        .lookup<NativeFunction<Int32 Function()>>('ffmpeg_shutdown')
        .asFunction();
    _ffmpegGetVersion = _lib
        .lookup<NativeFunction<Pointer<Utf8> Function()>>(
            'ffmpeg_get_version')
        .asFunction();
    _ffmpegCreateDecoder = _lib
        .lookup<NativeFunction<Int64 Function(Pointer<Utf8>, Int32)>>(
            'ffmpeg_create_decoder')
        .asFunction();
    _ffmpegReleaseDecoder = _lib
        .lookup<NativeFunction<Int32 Function(Int64)>>(
            'ffmpeg_release_decoder')
        .asFunction();
    _ffmpegDecodeFrame = _lib
        .lookup<
            NativeFunction<
                Int64 Function(Int64, Int64, Pointer<Uint8>,
                    Int64)>>('ffmpeg_decode_frame')
        .asFunction();
    _ffmpegGetMetadata = _lib
        .lookup<
            NativeFunction<
                Int32 Function(Pointer<Utf8>, Pointer<Int32>, Pointer<Int32>,
                    Pointer<Int64>, Pointer<Float>)>>('ffmpeg_get_metadata')
        .asFunction();
    _ffmpegCreateAudioEncoder = _lib
        .lookup<NativeFunction<Int64 Function(Pointer<Utf8>, Int32, Int32, Int32)>>(
            'ffmpeg_create_audio_encoder')
        .asFunction();
    _ffmpegReleaseAudioEncoder = _lib
        .lookup<NativeFunction<Int32 Function(Int64)>>(
            'ffmpeg_release_audio_encoder')
        .asFunction();
    _ffmpegEncodeAudio = _lib
        .lookup<NativeFunction<Int32 Function(Int64, Pointer<Float>, Int64)>>(
            'ffmpeg_encode_audio')
        .asFunction();

    // Timeline acceleration
    _timelineCreateContext = _lib
        .lookup<NativeFunction<Int64 Function(Int32, Int32)>>(
            'timeline_create_context')
        .asFunction();
    _timelineReleaseContext = _lib
        .lookup<NativeFunction<Int32 Function(Int64)>>(
            'timeline_release_context')
        .asFunction();
    _timelineRegisterClip = _lib
        .lookup<
            NativeFunction<
                Int32 Function(Int64, Int32, Pointer<Utf8>, Int64,
                    Int64)>>('timeline_register_clip')
        .asFunction();
    _timelineUnregisterClip = _lib
        .lookup<NativeFunction<Int32 Function(Int64, Int32)>>(
            'timeline_unregister_clip')
        .asFunction();
    _timelineCompositeAtTime = _lib
        .lookup<
            NativeFunction<
                Int64 Function(Int64, Int64, Pointer<Int32>, Int32,
                    Pointer<Uint8>, Int64)>>('timeline_composite_at_time')
        .asFunction();

    // Error handling
    _getErrorMessage = _lib
        .lookup<NativeFunction<Pointer<Utf8> Function(Int32)>>(
            'get_error_message')
        .asFunction();
    _clearError = _lib
        .lookup<NativeFunction<Void Function()>>('clear_error')
        .asFunction();

    // Logging and debugging
    _setLogCallback = _lib
        .lookup<
            NativeFunction<
                Int32 Function(Pointer<NativeFunction<_LogCallbackNative>>,
                    Pointer<Void>)>>('set_log_callback')
        .asFunction();
    _getPerformanceStats = _lib
        .lookup<NativeFunction<Int64 Function(Pointer<Utf8>, Int64)>>(
            'get_performance_stats')
        .asFunction();
  }
}

// ====================================================
// Native Function Signatures
// ====================================================

typedef _LogCallbackNative = Void Function(
  Int32 level,
  Pointer<Utf8> message,
  Pointer<Void> userData,
);

typedef _LogCallback = void Function(
  int level,
  String message,
  Pointer<Void> userData,
);

// ====================================================
// Dart Wrapper Classes and Functions
// ====================================================

/// Enumeration of effect types for render acceleration
enum RenderEffectType {
  blur(0),
  brightness(1),
  contrast(2),
  saturation(3),
  hueShift(4),
  colorGrade(5),
  ;

  final int code;
  const RenderEffectType(this.code);
}

/// Hardware acceleration modes for video decoding
enum HardwareAcceleration {
  disabled(0),
  auto(1),
  forced(2),
  ;

  final int code;
  const HardwareAcceleration(this.code);
}

/// Result wrapper for native operations
class NativeBridgeResult<T> {
  final bool success;
  final T? data;
  final String? errorMessage;
  final int errorCode;

  const NativeBridgeResult({
    required this.success,
    this.data,
    this.errorMessage,
    required this.errorCode,
  });

  factory NativeBridgeResult.success(T data) {
    return NativeBridgeResult(
      success: true,
      data: data,
      errorCode: 0,
    );
  }

  factory NativeBridgeResult.error({
    required String message,
    required int errorCode,
  }) {
    return NativeBridgeResult(
      success: false,
      errorMessage: message,
      errorCode: errorCode,
    );
  }
}

/// Main interface to native bridge
class NativeBridge {
  static NativeBridge? _instance;
  static _CinematicBridgeFFI? _ffi;

  /// Get singleton instance of NativeBridge
  static NativeBridge get instance {
    _instance ??= NativeBridge._();
    return _instance!;
  }

  NativeBridge._();

  /// Initialize the native bridge
  /// Must be called once before using any other methods
  static Future<NativeBridgeResult<bool>> initialize() async {
    try {
      // Load native library based on platform
      late DynamicLibrary lib;
      if (Platform.isAndroid) {
        lib = DynamicLibrary.open('libcinematic_bridge.so');
      } else if (Platform.isIOS || Platform.isMacOS) {
        lib = DynamicLibrary.process();
      } else if (Platform.isLinux) {
        lib = DynamicLibrary.open('libcinematic_bridge.so');
      } else if (Platform.isWindows) {
        lib = DynamicLibrary.open('cinematic_bridge.dll');
      } else {
        return NativeBridgeResult.error(
          message: 'Unsupported platform',
          errorCode: -1,
        );
      }

      _ffi = _CinematicBridgeFFI(lib);

      // Initialize engine
      final result = _ffi!._engineInit();
      if (result != 0) {
        final errorMsg = _ffi!._getErrorMessage(result);
        return NativeBridgeResult.error(
          message: errorMsg.toDartString(),
          errorCode: result,
        );
      }

      debugPrint('✓ Native bridge initialized');
      return NativeBridgeResult.success(true);
    } catch (e) {
      debugPrint('✗ Failed to initialize native bridge: $e');
      return NativeBridgeResult.error(
        message: e.toString(),
        errorCode: -1,
      );
    }
  }

  /// Shutdown the native bridge
  static Future<NativeBridgeResult<bool>> shutdown() async {
    if (_ffi == null) {
      return NativeBridgeResult.error(
        message: 'Bridge not initialized',
        errorCode: -1,
      );
    }

    try {
      final result = _ffi!._engineShutdown();
      if (result != 0) {
        final errorMsg = _ffi!._getErrorMessage(result);
        return NativeBridgeResult.error(
          message: errorMsg.toDartString(),
          errorCode: result,
        );
      }

      debugPrint('✓ Native bridge shut down');
      return NativeBridgeResult.success(true);
    } catch (e) {
      debugPrint('✗ Failed to shut down native bridge: $e');
      return NativeBridgeResult.error(
        message: e.toString(),
        errorCode: -1,
      );
    }
  }

  /// Check if bridge is initialized
  static bool get isInitialized => _ffi != null && (_ffi!._engineIsInitialized() != 0);

  /// Get version information
  static String? get version {
    if (_ffi == null) return null;
    return _ffi!._getVersion().toDartString();
  }

  /// Get build timestamp
  static String? get buildTimestamp {
    if (_ffi == null) return null;
    return _ffi!._getBuildTimestamp().toDartString();
  }

  // ====================================================
  // Render Acceleration APIs
  // ====================================================

  /// Create render acceleration context
  static NativeBridgeResult<int> createRenderContext({
    required int width,
    required int height,
    required int fps,
  }) {
    if (_ffi == null) {
      return NativeBridgeResult.error(
        message: 'Bridge not initialized',
        errorCode: -1,
      );
    }

    try {
      final handle = _ffi!._renderCreateContext(width, height, fps);
      if (handle <= 0) {
        return NativeBridgeResult.error(
          message: 'Failed to create render context',
          errorCode: -1,
        );
      }

      return NativeBridgeResult.success(handle as int);
    } catch (e) {
      return NativeBridgeResult.error(
        message: e.toString(),
        errorCode: -1,
      );
    }
  }

  /// Release render acceleration context
  static NativeBridgeResult<bool> releaseRenderContext(int handle) {
    if (_ffi == null) {
      return NativeBridgeResult.error(
        message: 'Bridge not initialized',
        errorCode: -1,
      );
    }

    try {
      final result = _ffi!._renderReleaseContext(handle);
      if (result != 0) {
        return NativeBridgeResult.error(
          message: 'Failed to release render context',
          errorCode: result,
        );
      }

      return NativeBridgeResult.success(true);
    } catch (e) {
      return NativeBridgeResult.error(
        message: e.toString(),
        errorCode: -1,
      );
    }
  }

  /// Apply render effect to frame
  static NativeBridgeResult<bool> applyRenderEffect({
    required int contextHandle,
    required RenderEffectType effectType,
    required double intensity,
    required List<int> inputFrame,
  }) {
    if (_ffi == null) {
      return NativeBridgeResult.error(
        message: 'Bridge not initialized',
        errorCode: -1,
      );
    }

    try {
      // Allocate output buffer
      final outputBuffer = malloc<Uint8>(inputFrame.length);

      // Convert input to native memory
      final inputBuffer = malloc<Uint8>(inputFrame.length);
      for (int i = 0; i < inputFrame.length; i++) {
        inputBuffer[i] = inputFrame[i];
      }

      final result = _ffi!._renderApplyEffect(
        contextHandle,
        effectType.code,
        intensity,
        inputBuffer,
        inputFrame.length,
        outputBuffer,
        inputFrame.length,
      );

      malloc.free(inputBuffer);
      malloc.free(outputBuffer);

      if (result != 0) {
        return NativeBridgeResult.error(
          message: 'Failed to apply render effect',
          errorCode: result,
        );
      }

      return NativeBridgeResult.success(true);
    } catch (e) {
      return NativeBridgeResult.error(
        message: e.toString(),
        errorCode: -1,
      );
    }
  }

  // ====================================================
  // FFmpeg Bridge APIs
  // ====================================================

  /// Get FFmpeg version
  static String? get ffmpegVersion {
    if (_ffi == null) return null;
    return _ffi!._ffmpegGetVersion().toDartString();
  }

  /// Get video metadata
  static NativeBridgeResult<VideoMetadata> getVideoMetadata(String filePath) {
    if (_ffi == null) {
      return NativeBridgeResult.error(
        message: 'Bridge not initialized',
        errorCode: -1,
      );
    }

    try {
      final pathPtr = filePath.toNativeUtf8();
      final width = malloc<Int32>();
      final height = malloc<Int32>();
      final duration = malloc<Int64>();
      final fps = malloc<Float>();

      final result = _ffi!._ffmpegGetMetadata(pathPtr, width, height, duration, fps);

      final metadata = VideoMetadata(
        width: width.value,
        height: height.value,
        durationMs: duration.value,
        fps: fps.value,
      );

      malloc.free(pathPtr);
      malloc.free(width);
      malloc.free(height);
      malloc.free(duration);
      malloc.free(fps);

      if (result != 0) {
        return NativeBridgeResult.error(
          message: 'Failed to get video metadata',
          errorCode: result,
        );
      }

      return NativeBridgeResult.success(metadata);
    } catch (e) {
      return NativeBridgeResult.error(
        message: e.toString(),
        errorCode: -1,
      );
    }
  }

  /// Create video decoder
  static NativeBridgeResult<int> createVideoDecoder(
    String filePath, {
    HardwareAcceleration hwaccel = HardwareAcceleration.auto,
  }) {
    if (_ffi == null) {
      return NativeBridgeResult.error(
        message: 'Bridge not initialized',
        errorCode: -1,
      );
    }

    try {
      final pathPtr = filePath.toNativeUtf8();
      final handle = _ffi!._ffmpegCreateDecoder(pathPtr, hwaccel.code);
      malloc.free(pathPtr);

      if (handle <= 0) {
        return NativeBridgeResult.error(
          message: 'Failed to create video decoder',
          errorCode: -1,
        );
      }

      return NativeBridgeResult.success(handle as int);
    } catch (e) {
      return NativeBridgeResult.error(
        message: e.toString(),
        errorCode: -1,
      );
    }
  }

  /// Release video decoder
  static NativeBridgeResult<bool> releaseVideoDecoder(int handle) {
    if (_ffi == null) {
      return NativeBridgeResult.error(
        message: 'Bridge not initialized',
        errorCode: -1,
      );
    }

    try {
      final result = _ffi!._ffmpegReleaseDecoder(handle);
      if (result != 0) {
        return NativeBridgeResult.error(
          message: 'Failed to release video decoder',
          errorCode: result,
        );
      }

      return NativeBridgeResult.success(true);
    } catch (e) {
      return NativeBridgeResult.error(
        message: e.toString(),
        errorCode: -1,
      );
    }
  }

  // ====================================================
  // Timeline Acceleration APIs
  // ====================================================

  /// Create timeline acceleration context
  static NativeBridgeResult<int> createTimelineContext({
    required int maxClips,
    required int cacheSizeMb,
  }) {
    if (_ffi == null) {
      return NativeBridgeResult.error(
        message: 'Bridge not initialized',
        errorCode: -1,
      );
    }

    try {
      final handle = _ffi!._timelineCreateContext(maxClips, cacheSizeMb);
      if (handle <= 0) {
        return NativeBridgeResult.error(
          message: 'Failed to create timeline context',
          errorCode: -1,
        );
      }

      return NativeBridgeResult.success(handle as int);
    } catch (e) {
      return NativeBridgeResult.error(
        message: e.toString(),
        errorCode: -1,
      );
    }
  }

  /// Release timeline context
  static NativeBridgeResult<bool> releaseTimelineContext(int handle) {
    if (_ffi == null) {
      return NativeBridgeResult.error(
        message: 'Bridge not initialized',
        errorCode: -1,
      );
    }

    try {
      final result = _ffi!._timelineReleaseContext(handle);
      if (result != 0) {
        return NativeBridgeResult.error(
          message: 'Failed to release timeline context',
          errorCode: result,
        );
      }

      return NativeBridgeResult.success(true);
    } catch (e) {
      return NativeBridgeResult.error(
        message: e.toString(),
        errorCode: -1,
      );
    }
  }

  /// Register clip in timeline
  static NativeBridgeResult<bool> registerTimelineClip({
    required int contextHandle,
    required int clipId,
    required String filePath,
    required int startMs,
    required int durationMs,
  }) {
    if (_ffi == null) {
      return NativeBridgeResult.error(
        message: 'Bridge not initialized',
        errorCode: -1,
      );
    }

    try {
      final pathPtr = filePath.toNativeUtf8();
      final result = _ffi!._timelineRegisterClip(
        contextHandle,
        clipId,
        pathPtr,
        startMs,
        durationMs,
      );
      malloc.free(pathPtr);

      if (result != 0) {
        return NativeBridgeResult.error(
          message: 'Failed to register timeline clip',
          errorCode: result,
        );
      }

      return NativeBridgeResult.success(true);
    } catch (e) {
      return NativeBridgeResult.error(
        message: e.toString(),
        errorCode: -1,
      );
    }
  }
}

// ====================================================
// Data Classes
// ====================================================

/// Video metadata information
class VideoMetadata {
  final int width;
  final int height;
  final int durationMs;
  final double fps;

  VideoMetadata({
    required this.width,
    required this.height,
    required this.durationMs,
    required this.fps,
  });

  @override
  String toString() =>
      'VideoMetadata(${width}x${height}, ${durationMs}ms, ${fps.toStringAsFixed(2)} fps)';
}
