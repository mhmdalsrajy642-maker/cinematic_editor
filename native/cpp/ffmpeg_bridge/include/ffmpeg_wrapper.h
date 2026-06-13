#ifndef FFMPEG_WRAPPER_H
#define FFMPEG_WRAPPER_H

#include "ffmpeg_types.h"
#include <cstdint>
#include <string>

namespace cinematic {

class FFmpegWrapper {
public:
    FFmpegWrapper() = default;
    ~FFmpegWrapper() = default;

    // Initialize the FFmpeg bridge.
    FFmpegResult initialize();

    // Shut down the FFmpeg bridge and release resources.
    FFmpegResult shutdown();

    // Probe media metadata from a file or stream.
    FFmpegResult probeMedia(const std::string& inputPath);

    // Extract a single video frame at the specified timestamp.
    FFmpegResult extractFrame(
        const std::string& inputPath,
        int64_t timestampMs,
        const std::string& outputPath);

    // Render a preview frame or segment using preview-only settings.
    FFmpegResult renderPreview(
        const std::string& inputPath,
        const RenderOptions& options,
        const std::string& outputPath);

    // Export video using a specified export profile.
    FFmpegResult exportVideo(
        const std::string& inputPath,
        const ExportProfile& profile,
        const std::string& outputPath);
};

} // namespace cinematic

#endif // FFMPEG_WRAPPER_H
