# Service Registration Audit

This document summarizes the registered services in `lib/main.dart` and confirms the newly added service locator registrations.

## Registered Services

### Existing registrations retained

- `DeviceSecurityService`
- `LocalAiEngine`
- `AiCommandParserService`
- `BackgroundRemovalService`
- `ModelDownloadService`
- `InferencePipelineService`
- `AICubit`

### Newly registered services

- `TaskQueueService`
- `ProxyGenerationService`
- `AutoCaptionService`
- `MotionTrackingService`
- `StabilizationService`

## Notes

- `ProxyGenerationService` is registered with a dependency on `TaskQueueService`.
- `InferencePipelineService` is now constructed with an injected `AutoCaptionService`.
- No UI or EditorCubit changes were made as part of this update.
