# DI Audit Report

## Summary
This audit reviews `GetIt` registrations in the repository and verifies the DI setup for AI, export, template, subscription, and auth service areas. No code modifications were made.

## GetIt Registration Inventory
All `GetIt` registrations are centralized in `lib/main.dart`:

- `DeviceSecurityService`
- `LocalAiEngine`
- `AiCommandParserService`
- `BackgroundRemovalService`
- `ModelDownloadService`
- `TaskQueueService`
- `ProxyGenerationService`
- `AutoCaptionService`
- `MotionTrackingService`
- `StabilizationService`
- `InferencePipelineService`
- `ExportService`
- `ExportPipelineService`
- `ExportQueueService`
- `AICubit`

## DI Service Coverage by Category

### AI Services
Registered AI-related services:
- `LocalAiEngine`
- `AiCommandParserService`
- `BackgroundRemovalService`
- `ModelDownloadService`
- `AutoCaptionService`
- `InferencePipelineService`
- `AICubit`

Dependency graph:
- `BackgroundRemovalService` → `LocalAiEngine`
- `ModelDownloadService` → `LocalAiEngine`
- `InferencePipelineService` → `AiCommandParserService`, `LocalAiEngine`, `BackgroundRemovalService`, `ModelDownloadService`, `AutoCaptionService`
- `AICubit` → `InferencePipelineService`

Status:
- No circular dependencies detected in the AI registration graph.
- Both `LocalAiEngine` and `AiCommandParserService` are registered before the services that depend on them.

### Export Services
Registered export-related services:
- `ExportService`
- `ExportPipelineService`
- `ExportQueueService`

Dependency graph:
- `ExportService` → `DeviceSecurityService`
- `ExportPipelineService` → `ExportService`
- `ExportQueueService` → `ExportPipelineService`

Status:
- No circular dependencies detected.
- `ExportQueueService` is registered but not retrieved via `GetIt` in the current scanned source files.

### Template Services
Detected template-related classes with no `GetIt` registration:
- `TemplateDownloadService`
- `CreatorRevenueService`
- `TemplateRepository`

Status:
- Template services are not registered in `GetIt` at all.
- No `GetIt` retrievals for template service types were found.
- If template services are intended to be resolved through DI, these are missing registrations.

### Subscription Services
Detected subscription-related classes with no `GetIt` registration:
- `SubscriptionService`
- `SubscriptionProvider` (abstract)
- `RevenueCatProvider`
- `MockSubscriptionProvider`

Status:
- `SubscriptionService` is not registered in `GetIt`.
- No provider implementation is registered for `SubscriptionProvider`.
- These services are likely missing from the DI registration layer if subscription flows are intended to use `GetIt`.

### Auth Services
Detected auth-related classes:
- `DeviceSecurityService` in `lib/features/subscription/services/device_security_service.dart`
- `DeviceSecurityService` in `lib/features/auth/services/device_security_service.dart`

Status:
- `GetIt` registers `DeviceSecurityService` from `features/subscription/services/device_security_service.dart`.
- The auth-layer variant in `features/auth/services/device_security_service.dart` is not registered.
- This duplicate service name is a potential ambiguity risk.

## Missing Registrations
The following service classes are present in the codebase and do not have corresponding `GetIt` registration entries:

- `TemplateDownloadService`
- `CreatorRevenueService`
- `TemplateRepository`
- `SubscriptionService`
- `SubscriptionProvider`
- `RevenueCatProvider`
- `MockSubscriptionProvider`
- `lib/features/auth/services/device_security_service.dart` `DeviceSecurityService`

## Circular Dependencies
No circular dependency cycles were detected among registered `GetIt` services.
The registration graph is acyclic.

## Unreachable Services
Registered services that are not retrieved via `GetIt` anywhere in the scanned source files:

- `ExportQueueService`
- `MotionTrackingService`
- `ProxyGenerationService`
- `StabilizationService`

These services are registered but have no direct `GetIt` retrievals in the current codebase, making them unreachable via DI if the app relies solely on `GetIt` resolution.

## Notes and Observations
- DI registration is centralized in `lib/main.dart`, which simplifies auditing but also concentrates registration responsibility in one file.
- The `features/subscription` `DeviceSecurityService` is registered, while the `features/auth` variant is not, creating a name collision risk.
- Template and subscription modules include service classes that are not wired into `GetIt`, which may indicate incomplete DI coverage for those domains.
- There are no `GetIt` retrievals of `SubscriptionService` or template service types, suggesting those modules may currently be used outside the DI container or are not yet integrated.

## Recommended Actions
1. Register missing template services if DI resolution is intended for template workflows.
2. Register `SubscriptionService` and a concrete `SubscriptionProvider` implementation if subscription flows should be available via `GetIt`.
3. Resolve duplicate `DeviceSecurityService` types by renaming one implementation or consolidating them into a single shared service.
4. Audit registered services that are not retrieved via `GetIt` to confirm whether they should remain in DI or be removed.
5. Keep `GetIt` registrations aligned with service consumers to avoid hidden unreachable services.
