#include "../include/ffmpeg_wrapper.h"

namespace cinematic {

FFmpegResult FFmpegWrapper::initialize() {
    return FFmpegResult{true, FFmpegStatus::Ready, FFmpegError::None, "FFmpeg wrapper initialized", 0};
}

FFmpegResult FFmpegWrapper::shutdown() {
    return FFmpegResult{true, FFmpegStatus::Shutdown, FFmpegError::None, "FFmpeg wrapper shut down", 0};
}

FFmpegResult FFmpegWrapper::probeMedia(const std::string& inputPath) {
    if (inputPath.empty()) {
        return FFmpegResult{false, FFmpegStatus::Error, FFmpegError::InvalidParameter, "Input path is empty", 1};
    }

    return FFmpegResult{true, FFmpegStatus::Ready, FFmpegError::None, "Media probe stub", 0};
}

FFmpegResult FFmpegWrapper::extractFrame(
    const std::string& inputPath,
    int64_t timestampMs,
    const std::string& outputPath) {
    if (inputPath.empty() || outputPath.empty() || timestampMs < 0) {
        return FFmpegResult{false, FFmpegStatus::Error, FFmpegError::InvalidParameter, "Invalid extractFrame parameters", 1};
    }

    return FFmpegResult{true, FFmpegStatus::Ready, FFmpegError::None, "Frame extraction stub", 0};
}

FFmpegResult FFmpegWrapper::renderPreview(
    const std::string& inputPath,
    const RenderOptions& options,
    const std::string& outputPath) {
    if (inputPath.empty() || outputPath.empty()) {
        return FFmpegResult{false, FFmpegStatus::Error, FFmpegError::InvalidParameter, "Invalid renderPreview parameters", 1};
    }

    return FFmpegResult{true, FFmpegStatus::Ready, FFmpegError::None, "Preview render stub", 0};
}

FFmpegResult FFmpegWrapper::exportVideo(
    const std::string& inputPath,
    const ExportProfile& profile,
    const std::string& outputPath) {
    if (inputPath.empty() || outputPath.empty()) {
        return FFmpegResult{false, FFmpegStatus::Error, FFmpegError::InvalidParameter, "Invalid exportVideo parameters", 1};
    }

    return FFmpegResult{true, FFmpegStatus::Ready, FFmpegError::None, "Video export stub", 0};
}

} // namespace cinematic
