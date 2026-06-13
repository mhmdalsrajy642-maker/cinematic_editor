#ifndef CINEMATIC_ENGINE_H
#define CINEMATIC_ENGINE_H

#include <cstdint>
#include <string>
#include <vector>

namespace cinematic {

// Describes static engine configuration values.
struct EngineConfig {
    std::string applicationName;
    std::string version;
    int32_t targetFps;
    int32_t defaultWidth;
    int32_t defaultHeight;
    bool enableAudioProcessing;
    bool enableVideoProcessing;
};

// Describes the engine's current capabilities.
struct EngineCapabilities {
    bool supportsTimelinePlayback;
    bool supportsFrameRendering;
    bool supportsExport;
    bool supportsAudioMixing;
    bool supportsVideoEffects;
};

// Represents the current runtime state of the engine.
struct EngineState {
    bool isInitialized;
    bool hasLoadedTimeline;
    bool isRendering;
    bool isExporting;
    std::string lastError;
};

// Represents the loaded timeline context.
struct TimelineContext {
    std::string projectId;
    int64_t durationMs;
    int32_t frameRate;
    int32_t width;
    int32_t height;
    std::vector<std::string> videoTrackIds;
    std::vector<std::string> audioTrackIds;
};

// Represents the result of engine operations.
struct EngineResult {
    bool success;
    int32_t errorCode;
    std::string message;
    int64_t framesRendered;
    int64_t exportDurationMs;
};

// Main engine interface.
class CinematicEngine {
public:
    explicit CinematicEngine(const EngineConfig& config);
    ~CinematicEngine();

    // Lifecycle
    bool initialize();
    bool shutdown();

    // Timeline management
    EngineResult loadTimeline(const TimelineContext& timeline);

    // Frame rendering
    EngineResult renderFrame(uint8_t* outputBuffer, int64_t outputSize);

    // Export the current project.
    EngineResult exportProject(const std::string& outputPath);

    // Query helpers
    EngineCapabilities getCapabilities() const;
    EngineState getState() const;
    TimelineContext getTimelineContext() const;

private:
    EngineConfig config_;
    EngineCapabilities capabilities_;
    EngineState state_;
    TimelineContext timeline_;

    void resetState_();
};

} // namespace cinematic

#endif // CINEMATIC_ENGINE_H
