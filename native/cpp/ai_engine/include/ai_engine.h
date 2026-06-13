#pragma once

#include <string>
#include <vector>

namespace cinematic {

enum class AIModelType {
    Unknown,
    ImageClassification,
    ObjectDetection,
    Segmentation,
    PoseEstimation,
    Custom
};

struct AIModelInfo {
    std::string modelId;
    AIModelType type = AIModelType::Unknown;
    std::string version;
    std::string description;
};

struct AIInferenceRequest {
    std::string modelId;
    std::vector<uint8_t> inputData;
    std::string inputMimeType;
    std::string parameters;
};

struct AIInferenceResult {
    bool success = false;
    std::string modelId;
    std::vector<uint8_t> outputData;
    std::string outputMimeType;
    std::string errorMessage;
};

class AIEngine {
public:
    virtual ~AIEngine() = default;

    virtual bool initialize() = 0;
    virtual bool shutdown() = 0;

    virtual bool loadModel(const AIModelInfo& modelInfo) = 0;
    virtual bool unloadModel(const std::string& modelId) = 0;

    virtual AIInferenceResult runInference(const AIInferenceRequest& request) = 0;
};

} // namespace cinematic
