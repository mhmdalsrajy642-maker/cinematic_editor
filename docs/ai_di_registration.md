# AI Dependency Injection Registration

This document describes how AI services are registered in the applications service locator.

## Registered AI Services

- `LocalAiEngine`
  - Registered as a lazy singleton.
  - Provides TFLite model loading and inference execution.

- `AiCommandParserService`
  - Registered as a lazy singleton.
  - Parses free-form AI commands into actionable AST-like JSON structures.

- `BackgroundRemovalService`
  - Registered as a lazy singleton.
  - Orchestrates segmentation backends and manages background removal lifecycle.
  - Instantiated with defaults and a `LocalAiEngine` dependency.

- `ModelDownloadService`
  - Registered as a lazy singleton.
  - Handles model download, caching, verification, and optional engine integration.
  - Depends on `LocalAiEngine`.

- `InferencePipelineService`
  - Registered as a lazy singleton.
  - Orchestrates command parsing, model selection, backend selection, and inference execution.
  - Depends on `AiCommandParserService`, `LocalAiEngine`, and `BackgroundRemovalService`.

- `AICubit`
  - Registered as a factory.
  - Depends on `InferencePipelineService`.
  - Provides command execution state management and progress updates.

## Notes

- Existing service registrations remain unchanged.
- `lazySingleton` is used for long-lived shared components.
- `registerFactory` is used for `AICubit` to ensure each consumer receives a fresh cubit instance.
