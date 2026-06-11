// native/cpp/include/cinematic_bridge.h
// Main header file defining the FFI interface between Dart and C++
// All C functions are exposed through this header for use in Dart FFI

#ifndef CINEMATIC_BRIDGE_H
#define CINEMATIC_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// ====================================================
// Version Information
// ====================================================

/// Get the native bridge version string
/// Returns: Version string (e.g., "1.0.0")
const char* get_bridge_version(void);

/// Get the build timestamp
/// Returns: Build timestamp string
const char* get_build_timestamp(void);

// ====================================================
// Engine Initialization and Lifecycle
// ====================================================

/// Initialize the native engine
/// This must be called once before using any other functions
/// Returns: 0 on success, error code on failure
int32_t engine_init(void);

/// Shutdown the native engine
/// This must be called once before exiting the application
/// Returns: 0 on success, error code on failure
int32_t engine_shutdown(void);

/// Check if the engine is initialized
/// Returns: 1 if initialized, 0 otherwise
int32_t engine_is_initialized(void);

// ====================================================
// Render Engine Acceleration Hooks
// ====================================================

/// Request render acceleration for timeline processing
/// This prepares resources for accelerated rendering
/// Parameters:
///   width: Frame width in pixels
///   height: Frame height in pixels
///   fps: Frames per second
/// Returns: Handle to accelerated render context (0 on failure)
int64_t render_create_context(int32_t width, int32_t height, int32_t fps);

/// Release render acceleration context
/// Parameters:
///   handle: Context handle from render_create_context
/// Returns: 0 on success, error code on failure
int32_t render_release_context(int64_t handle);

/// Process a frame through the acceleration pipeline
/// Parameters:
///   handle: Context handle
///   input_buffer: Pointer to input frame data (RGBA)
///   input_size: Size of input buffer in bytes
///   output_buffer: Pointer to output buffer (must be pre-allocated)
///   output_size: Size of output buffer in bytes
/// Returns: Size of processed frame in bytes, -1 on error
int64_t render_process_frame(
    int64_t handle,
    const uint8_t* input_buffer,
    int64_t input_size,
    uint8_t* output_buffer,
    int64_t output_size
);

/// Apply effects acceleration to a frame
/// Parameters:
///   handle: Context handle
///   effect_id: Type of effect (0=blur, 1=brightness, 2=contrast, etc.)
///   intensity: Effect intensity (0.0 to 1.0)
///   input_buffer: Input frame data
///   input_size: Size of input
///   output_buffer: Output buffer
///   output_size: Size of output
/// Returns: 0 on success, error code on failure
int32_t render_apply_effect(
    int64_t handle,
    int32_t effect_id,
    float intensity,
    const uint8_t* input_buffer,
    int64_t input_size,
    uint8_t* output_buffer,
    int64_t output_size
);

// ====================================================
// FFmpeg Bridge Operations
// ====================================================

/// Initialize FFmpeg subsystem
/// This must be called before any FFmpeg operations
/// Returns: 0 on success, error code on failure
int32_t ffmpeg_init(void);

/// Shutdown FFmpeg subsystem
/// Returns: 0 on success, error code on failure
int32_t ffmpeg_shutdown(void);

/// Get FFmpeg library version information
/// Returns: Version string (e.g., "N-98765-g...")
const char* ffmpeg_get_version(void);

/// Create a video decoder for heavy lifting
/// Parameters:
///   file_path: Full path to video file
///   hwaccel: Enable hardware acceleration (0=no, 1=auto, 2=force)
/// Returns: Decoder handle (0 on failure)
int64_t ffmpeg_create_decoder(const char* file_path, int32_t hwaccel);

/// Release video decoder
/// Parameters:
///   handle: Decoder handle from ffmpeg_create_decoder
/// Returns: 0 on success, error code on failure
int32_t ffmpeg_release_decoder(int64_t handle);

/// Decode a frame at specific timestamp
/// Parameters:
///   handle: Decoder handle
///   timestamp_ms: Frame timestamp in milliseconds
///   output_buffer: Buffer to store decoded frame (pre-allocated, RGBA)
///   output_size: Size of output buffer
/// Returns: Size of decoded frame, -1 on error
int64_t ffmpeg_decode_frame(
    int64_t handle,
    int64_t timestamp_ms,
    uint8_t* output_buffer,
    int64_t output_size
);

/// Get video metadata
/// Parameters:
///   file_path: Full path to video file
///   width: Output pointer for width
///   height: Output pointer for height
///   duration_ms: Output pointer for duration in milliseconds
///   fps: Output pointer for frames per second
/// Returns: 0 on success, error code on failure
int32_t ffmpeg_get_metadata(
    const char* file_path,
    int32_t* width,
    int32_t* height,
    int64_t* duration_ms,
    float* fps
);

/// Create audio encoder for heavy-duty encoding
/// Parameters:
///   output_path: Path to output audio file
///   sample_rate: Audio sample rate (e.g., 48000)
///   channels: Number of audio channels (1, 2, etc.)
///   bitrate_kbps: Bitrate in kilobits per second
/// Returns: Encoder handle (0 on failure)
int64_t ffmpeg_create_audio_encoder(
    const char* output_path,
    int32_t sample_rate,
    int32_t channels,
    int32_t bitrate_kbps
);

/// Release audio encoder
/// Parameters:
///   handle: Encoder handle
/// Returns: 0 on success, error code on failure
int32_t ffmpeg_release_audio_encoder(int64_t handle);

/// Encode audio samples
/// Parameters:
///   handle: Encoder handle
///   samples: Pointer to audio samples (float array)
///   sample_count: Number of samples to encode
/// Returns: 0 on success, error code on failure
int32_t ffmpeg_encode_audio(
    int64_t handle,
    const float* samples,
    int64_t sample_count
);

// ====================================================
// Timeline Acceleration
// ====================================================

/// Create accelerated timeline context
/// This prepares the engine for processing timeline operations
/// Parameters:
///   max_clips: Maximum number of clips to process
///   cache_size_mb: Cache size in megabytes
/// Returns: Timeline context handle (0 on failure)
int64_t timeline_create_context(int32_t max_clips, int32_t cache_size_mb);

/// Release timeline context
/// Parameters:
///   handle: Timeline context handle
/// Returns: 0 on success, error code on failure
int32_t timeline_release_context(int64_t handle);

/// Register clip in timeline context
/// Parameters:
///   handle: Timeline context handle
///   clip_id: Unique clip identifier
///   file_path: Path to video file
///   start_ms: Start time in milliseconds
///   duration_ms: Clip duration in milliseconds
/// Returns: 0 on success, error code on failure
int32_t timeline_register_clip(
    int64_t handle,
    int32_t clip_id,
    const char* file_path,
    int64_t start_ms,
    int64_t duration_ms
);

/// Unregister clip from timeline
/// Parameters:
///   handle: Timeline context handle
///   clip_id: Clip identifier
/// Returns: 0 on success, error code on failure
int32_t timeline_unregister_clip(int64_t handle, int32_t clip_id);

/// Composite multiple clips at given timestamp
/// Parameters:
///   handle: Timeline context handle
///   timestamp_ms: Composition timestamp
///   clip_ids: Array of clip IDs to composite
///   clip_count: Number of clips
///   output_buffer: Output frame buffer
///   output_size: Size of output buffer
/// Returns: Size of composited frame, -1 on error
int64_t timeline_composite_at_time(
    int64_t handle,
    int64_t timestamp_ms,
    const int32_t* clip_ids,
    int32_t clip_count,
    uint8_t* output_buffer,
    int64_t output_size
);

// ====================================================
// Error Handling
// ====================================================

/// Get human-readable error message for error code
/// Parameters:
///   error_code: Error code from any native function
/// Returns: Error message string
const char* get_error_message(int32_t error_code);

/// Clear the last error state
/// Returns: void
void clear_error(void);

// ====================================================
// Logging and Debugging
// ====================================================

/// Set logging callback for native operations
/// Parameters:
///   callback: Function pointer to log callback
///   user_data: Optional user data passed to callback
/// Returns: 0 on success
int32_t set_log_callback(
    void (*callback)(int32_t level, const char* message, void* user_data),
    void* user_data
);

/// Get performance statistics
/// Parameters:
///   stats: Output buffer for stats string (pre-allocated)
///   max_size: Size of stats buffer
/// Returns: Actual size of stats written, -1 on error
int64_t get_performance_stats(char* stats, int64_t max_size);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // CINEMATIC_BRIDGE_H
