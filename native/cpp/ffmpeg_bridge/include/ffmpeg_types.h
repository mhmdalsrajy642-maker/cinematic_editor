#ifndef FFMPEG_TYPES_H
#define FFMPEG_TYPES_H

#include <cstdint>
#include <string>

namespace cinematic {

enum class FFmpegStatus {
    Unknown,
    Initialized,
    Ready,
    Busy,
    Error,
    Shutdown,
};

enum class FFmpegError {
    None = 0,
    NotInitialized,
    AlreadyInitialized,
    InvalidParameter,
    FileNotFound,
    UnsupportedCodec,
    UnsupportedFormat,
    ResourceUnavailable,
    InternalError,
    Unknown,
};

struct FFmpegResult {
    bool success;
    FFmpegStatus status;
    FFmpegError error;
    std::string message;
    int32_t code;
};

enum class VideoCodec {
    Unknown,
    H264,
    H265,
    VP8,
    VP9,
    AV1,
    MPEG4,
    HEVC,
};

enum class AudioCodec {
    Unknown,
    AAC,
    MP3,
    OPUS,
    PCM,
    AC3,
    FLAC,
};

enum class ContainerFormat {
    Unknown,
    MP4,
    MKV,
    MOV,
    AVI,
    WEBM,
    TS,
};

struct ExportProfile {
    ContainerFormat container;
    VideoCodec videoCodec;
    AudioCodec audioCodec;
    int32_t videoBitrateKbps;
    int32_t audioBitrateKbps;
    int32_t width;
    int32_t height;
    int32_t fps;
    bool enableHardwareAccel;
};

struct RenderOptions {
    int32_t width;
    int32_t height;
    int32_t fps;
    bool enableVSync;
    bool useGpu;
    bool enableColorManagement;
    ExportProfile exportProfile;
};

} // namespace cinematic

#endif // FFMPEG_TYPES_H
