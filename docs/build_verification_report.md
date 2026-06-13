# Build Verification Report

## Summary
A repository-wide audit was performed on Dart source files, imports, dependency declarations, DI registration, duplicate model symbols, and compile risk indicators. Code was not modified.

## Findings

### Errors
- **Broken local import**
  - `lib/features/ai_commands/services/inference_pipeline_service.dart`
    - imports `../audio/services/auto_caption_service.dart`
    - The target path does not exist in the repository.

### Dependency Issues
- **Missing package dependency**
  - `lib/features/ai_commands/services/model_download_service.dart`
    - imports `package:http/http.dart`
  - `pubspec.yaml` does not declare `http` in `dependencies`.

- **Missing generated part file**
  - `lib/core/services/storage/app_database.dart`
    - declares `part 'app_database.g.dart';`
  - `lib/core/services/storage/app_database.g.dart` is missing from the repository.

- **Unused declared dependencies**
  - `pubspec.yaml` lists many packages that are not directly imported from `lib/**/*.dart`:
    - `cached_network_image`
    - `cloud_firestore`
    - `ffi`
    - `file_picker`
    - `firebase_analytics`
    - `firebase_auth`
    - `firebase_core`
    - `firebase_crashlytics`
    - `flutter_svg`
    - `google_fonts`
    - `hive`
    - `hive_flutter`
    - `hive_generator`
    - `image_picker`
    - `in_app_purchase`
    - `intl`
    - `json_annotation`
    - `just_audio`
    - `lottie`
    - `mockito`
    - `permission_handler`
    - `photo_view`
    - `purchases_flutter`
    - `retrofit`
    - `share_plus`
    - `shimmer`
    - `sqlite3_flutter_libs`
    - `syncfusion_flutter_sliders`
    - `web_socket_channel`

### Duplicate Model / Symbol Issues
- **Duplicate class symbol**: `DeviceSecurityService`
  - `lib/features/auth/services/device_security_service.dart`
  - `lib/features/subscription/services/device_security_service.dart`

- **Duplicate export model symbols**
  - `ExportJob`
    - `lib/features/export/domain/export_queue_service.dart`
    - `lib/features/export/models/export_pipeline_models.dart`
  - `ExportResult`
    - `lib/features/export/domain/export_service.dart`
    - `lib/features/export/models/export_pipeline_models.dart`

### DI Registration Issues
- `lib/main.dart` registers services via `GetIt`.
- Risk points:
  - `DeviceSecurityService` resolves from `features/subscription/services/device_security_service.dart` while `features/auth` contains an identically named class.
  - Registered service graph is long and currently only defined in `lib/main.dart`, so a missing or incorrect registration may only fail at runtime.

### Compile Risks
- Missing package dependency (`http`)
- Missing generated Drift part file (`app_database.g.dart`)
- Broken relative import path in `inference_pipeline_service.dart`
- Duplicate service/model symbols that can cause confusion and accidental name collisions
- `pubspec.yaml` contains many unused dependencies, increasing the chance of version resolution conflicts

## Risky Modules
- `lib/features/ai_commands/services/inference_pipeline_service.dart`
- `lib/features/ai_commands/services/model_download_service.dart`
- `lib/core/services/storage/app_database.dart`
- `lib/features/subscription/services/device_security_service.dart`
- `lib/features/auth/services/device_security_service.dart`
- `lib/features/export/domain/export_queue_service.dart`
- `lib/features/export/domain/export_service.dart`
- `lib/features/export/models/export_pipeline_models.dart`
- `lib/main.dart`

## Recommended Fixes
1. Fix the broken local import path in `lib/features/ai_commands/services/inference_pipeline_service.dart`.
2. Add `http` to `pubspec.yaml` dependencies.
3. Generate or add `lib/core/services/storage/app_database.g.dart`.
4. Rename or consolidate duplicate `DeviceSecurityService` classes into a single shared implementation.
5. Distinguish `ExportJob` / `ExportResult` model names across domain and pipeline model layers.
6. Remove unused dependencies from `pubspec.yaml` or verify if they are intentionally reserved for future modules.
7. Validate `GetIt` service registrations and ensure all injected services are imported from the intended files.

## Notes
- Full compile verification could not be completed because Flutter/Dart SDK is unavailable in this container.
- The audit is based on static file and manifest inspection only.
