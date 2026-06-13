#include "../include/cinematic_engine.h"

#include <cstring>
#include <utility>

namespace cinematic {

CinematicEngine::CinematicEngine(const EngineConfig& config)
    : config_(config),
      capabilities_{true, true, true, false, true},
      state_{false, false, false, false, ""},
      timeline_{"", 0, config.targetFps, config.defaultWidth, config.defaultHeight, {}, {}} {
}

CinematicEngine::~CinematicEngine() {
    if (state_.isInitialized) {
        shutdown();
    }
}

bool CinematicEngine::initialize() {
    if (state_.isInitialized) {
        return true;
    }

    state_.isInitialized = true;
    state_.lastError.clear();
    state_.isRendering = false;
    state_.isExporting = false;

    return true;
}

bool CinematicEngine::shutdown() {
    if (!state_.isInitialized) {
        state_.lastError = "Engine not initialized";
        return false;
    }

    state_.isInitialized = false;
    state_.hasLoadedTimeline = false;
    state_.isRendering = false;
    state_.isExporting = false;
    state_.lastError.clear();
    timeline_ = TimelineContext{"", 0, config_.targetFps, config_.defaultWidth, config_.defaultHeight, {}, {}};

    return true;
}

EngineResult CinematicEngine::loadTimeline(const TimelineContext& timeline) {
    if (!state_.isInitialized) {
        return EngineResult{false, 1, "Engine not initialized", 0, 0};
    }

    timeline_ = timeline;
    state_.hasLoadedTimeline = true;
    state_.lastError.clear();

    return EngineResult{true, 0, "Timeline loaded successfully", 0, 0};
}

EngineResult CinematicEngine::renderFrame(uint8_t* outputBuffer, int64_t outputSize) {
    if (!state_.isInitialized) {
        return EngineResult{false, 1, "Engine not initialized", 0, 0};
    }
    if (!state_.hasLoadedTimeline) {
        return EngineResult{false, 2, "Timeline not loaded", 0, 0};
    }
    if (!outputBuffer || outputSize <= 0) {
        return EngineResult{false, 3, "Invalid output buffer", 0, 0};
    }

    // Architecture placeholder: no real rendering yet.
    std::memset(outputBuffer, 0, static_cast<size_t>(outputSize));

    return EngineResult{true, 0, "Frame rendered", 1, 0};
}

EngineResult CinematicEngine::exportProject(const std::string& outputPath) {
    if (!state_.isInitialized) {
        return EngineResult{false, 1, "Engine not initialized", 0, 0};
    }
    if (!state_.hasLoadedTimeline) {
        return EngineResult{false, 2, "Timeline not loaded", 0, 0};
    }
    if (outputPath.empty()) {
        return EngineResult{false, 4, "Output path is empty", 0, 0};
    }

    state_.isExporting = true;

    // Architecture placeholder: export is not implemented yet.
    state_.isExporting = false;

    return EngineResult{true, 0, "Export completed (stub)", 0, 0};
}

EngineCapabilities CinematicEngine::getCapabilities() const {
    return capabilities_;
}

EngineState CinematicEngine::getState() const {
    return state_;
}

TimelineContext CinematicEngine::getTimelineContext() const {
    return timeline_;
}

void CinematicEngine::resetState_() {
    state_ = EngineState{false, false, false, false, ""};
    timeline_ = TimelineContext{"", 0, config_.targetFps, config_.defaultWidth, config_.defaultHeight, {}, {}};
}

} // namespace cinematic
