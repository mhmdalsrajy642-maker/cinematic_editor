# Strict Blueprint-to-Repository Gap Audit & Implementation Plan

**Generated:** 2026-06-08  
**Status:** Initial gap analysis (no production code modifications)  
**Scope:** Blueprint vs current repository state comparison

---

## 1. EXECUTIVE SUMMARY

### Current Implementation Score: 38/100

**Completed (Blue print ~= Reality):**
- ✅ Folder structure (mostly present)
- ✅ Core data models (VideoClip, AudioClip, TextLayer, TimelineState)
- ✅ Equatable state models + props
- ✅ Flutter Bloc architecture (EditorCubit present)
- ✅ Basic GetIt DI setup in main.dart
- ✅ Feature-first folder structure
- ✅ Undo/Redo service (JSON-based on disk)
- ✅ AI command parser service (local + API fallback)
- ✅ AppColors & AppTheme consistent with blueprint

**Missing (Blueprint expects ~= Reality is absent):**
- ❌ Data layer (repositories, DAOs)
- ❌ Domain layer (use cases/interactors)
- ❌ Export pipeline + FFmpeg integration
- ❌ Native C++ FFmpeg bridge
- ❌ Subscription system (payment module)
- ❌ Backend API clients (retrofit-generated)
- ❌ Database models (Drift ORM definitions)
- ❌ Full DI setup (only 1 service registered)
- ❌ Asset files (fonts, icons, animations all empty)
- ❌ Unit/integration tests
- ❌ Native platform channels (iOS/Android)
- ❌ MediaPipe integration for background removal
- ❌ Audio mixing/playback service (just_audio setup)
- ❌ Mock implementations for testing

---

## 2. CRITICAL BLOCKERS (Must Resolve First)

| Priority | Blocker | Impact | Dependencies |
|----------|---------|--------|--------------|
| 🔴 **P0** | **Export Pipeline Missing** | Cannot render/export video output at all | Requires FFmpeg bridge + native C++ |
| 🔴 **P0** | **Data Layer Absent** | DI incomplete, testability compromised, no persistence | Requires repository pattern + Drift setup |
| 🔴 **P0** | **Asset Files Empty** | Build warnings/errors, UI cannot load icons/fonts | Requires asset acquisition |
| 🟠 **P1** | **Incomplete DI Setup** | EditorCubit tightly coupled, harder to test/inject | Requires GetIt module + interfaces |
| 🟠 **P1** | **No Subscription Module** | Payment flow not wired | Requires revenue_cat / in_app_purchase setup |
| 🟠 **P1** | **Missing Native C++ Engine** | No performance acceleration, FFmpeg unavailable | C++ code + JNI/Swift bindings |
| 🟡 **P2** | **Retrofit/API Clients Not Generated** | Network calls won't work (AI API, backend) | Code generation + API models |
| 🟡 **P2** | **Database Models & Hive/Drift Not Initialized** | Project persistence doesn't work | Drift DB schema + migrations |

---

## 3. FILES THAT MUST BE CREATED (In Order)

### PHASE 1: Foundation (Data Layer & Persistence)

#### 1.1 Database & Persistence Layer
```
Priority: P0 (blocks all persistence features)
```

**Files to create:**

1. **lib/core/database/drift/app_database.dart** (Drift database definition)
   - Define `@DataClassName` for VideoClip, AudioClip, TextLayer, Project
   - Define queries for CRUD operations
   - Requires build_runner code generation

2. **lib/core/database/hive/models/** (Hive box models)
   - `lib/core/database/hive/hive_project_model.dart`
   - `lib/core/database/hive/hive_timeline_model.dart`
   - Type adapter generation via hive_generator

3. **lib/core/database/mappers/** (DTO ↔ Model converters)
   - `lib/core/database/mappers/video_clip_mapper.dart`
   - `lib/core/database/mappers/timeline_state_mapper.dart`

4. **lib/core/local_storage/** (File-based storage)
   - `lib/core/local_storage/project_storage_service.dart` (interface)
   - `lib/core/local_storage/project_storage_impl.dart` (Hive/Drift implementation)

#### 1.2 Repository Layer (Data access abstraction)

1. **lib/features/editor/data/repositories/** (Editor data contracts)
   - `lib/features/editor/data/repositories/timeline_repository_interface.dart`
   - `lib/features/editor/data/repositories/timeline_repository_impl.dart`

2. **lib/features/export/data/repositories/** (Export data contracts)
   - `lib/features/export/data/repositories/export_repository_interface.dart`
   - `lib/features/export/data/repositories/export_repository_impl.dart`

3. **lib/features/subscription/data/repositories/**
   - `lib/features/subscription/data/repositories/subscription_repository_interface.dart`
   - `lib/features/subscription/data/repositories/subscription_repository_impl.dart`

#### 1.3 Domain Layer (Use Cases)

1. **lib/features/editor/domain/usecases/**
   - `lib/features/editor/domain/usecases/load_project_usecase.dart`
   - `lib/features/editor/domain/usecases/save_project_usecase.dart`
   - `lib/features/editor/domain/usecases/apply_effect_usecase.dart`
   - `lib/features/editor/domain/usecases/apply_ai_actions_usecase.dart`

2. **lib/features/export/domain/usecases/**
   - `lib/features/export/domain/usecases/export_video_usecase.dart`
   - `lib/features/export/domain/usecases/validate_export_settings_usecase.dart`

3. **lib/features/subscription/domain/usecases/**
   - `lib/features/subscription/domain/usecases/check_subscription_usecase.dart`
   - `lib/features/subscription/domain/usecases/purchase_subscription_usecase.dart`

### PHASE 2: Export Pipeline (Critical for functionality)

#### 2.1 Export Service & Pipeline

1. **lib/features/export/services/export_service.dart** (interface)
   - Signature: `Future<void> exportVideo(ExportConfig config, TimelineState timeline)`
   - Outputs: MP4, MOV with various presets (1080p, 4K, etc.)

2. **lib/features/export/services/ffmpeg_export_service.dart** (FFmpeg implementation)
   - Integration with `ffmpeg_kit_flutter_full_gpl`
   - Command building logic
   - Progress tracking

3. **lib/features/export/models/export_config.dart**
   ```dart
   class ExportConfig {
     final String resolution;        // "1080p", "4K", "720p"
     final String format;            // "mp4", "mov"
     final int bitrate;              // kbps
     final String outputPath;
     final bool includeAudio;
     final double audioQuality;
     // ...
   }
   ```

4. **lib/features/export/models/export_progress.dart**
   ```dart
   class ExportProgress {
     final double percentage;        // 0.0-1.0
     final String currentFrame;
     final Duration elapsedTime;
     final Duration estimatedRemaining;
   }
   ```

#### 2.2 Export Cubit

1. **lib/features/export/presentation/cubit/export_cubit.dart**
   - States: ExportInitial, ExportInProgress, ExportSuccess, ExportFailure
   - Methods: startExport(), cancelExport(), onProgress()

2. **lib/features/export/presentation/cubit/export_state.dart** (separate file for clarity)

#### 2.3 Export UI (Placeholder for now)

1. **lib/features/export/presentation/screens/export_settings_screen.dart**
2. **lib/features/export/presentation/screens/export_progress_screen.dart**
3. **lib/features/export/presentation/widgets/export_preset_selector.dart**

### PHASE 3: Subscription & Payment System

#### 3.1 Subscription Models

1. **lib/features/subscription/domain/entities/subscription_plan.dart**
   ```dart
   class SubscriptionPlan {
     final String id;                // "free", "pro", "pro_annual"
     final String name;
     final double price;
     final List<String> features;    // ["4K export", "Remove watermark", ...]
     final Duration billingCycle;    // 30 days, 365 days
   }
   ```

2. **lib/features/subscription/domain/entities/user_subscription.dart**
   ```dart
   class UserSubscription {
     final String userId;
     final SubscriptionPlan plan;
     final DateTime startDate;
     final DateTime expiryDate;
     final bool isActive;
     final String transactionId;
   }
   ```

#### 3.2 Subscription Services

1. **lib/features/subscription/services/subscription_service.dart** (interface)
   - Contracts: `checkSubscription()`, `purchase()`, `restore()`

2. **lib/features/subscription/services/subscription_service_impl.dart**
   - Integration with `revenue_cat_flutter_sdk` or `in_app_purchase`
   - Handle IAP responses, restore purchases

3. **lib/features/subscription/services/device_security_service.dart** (already exists, but needs refactoring)
   - Move to data layer
   - Add encryption for sensitive data

#### 3.3 Subscription Cubit

1. **lib/features/subscription/presentation/cubit/subscription_cubit.dart**
   - States: SubscriptionLoading, SubscriptionLoaded, PurchaseInProgress, PurchaseSuccess, PurchaseFailure

### PHASE 4: Network Layer (API Clients)

#### 4.1 Retrofit API Models

1. **lib/features/ai_commands/data/models/ai_request_model.dart**
   - Annotate with `@JsonSerializable()`
   - Generated via `json_serializable`

2. **lib/features/ai_commands/data/models/ai_response_model.dart**

3. **lib/core/network/api/ai_api_client.dart**
   - Retrofit client with endpoints
   - Code generated via `retrofit_generator`

4. **lib/core/network/api/backend_api_client.dart** (for backend-specific endpoints)

#### 4.2 Network Error Handling

1. **lib/core/network/exceptions/api_exception.dart**
2. **lib/core/network/interceptors/error_interceptor.dart**
3. **lib/core/network/interceptors/auth_interceptor.dart** (for Bearer tokens if needed)

### PHASE 5: Native Layers & Bridges

#### 5.1 C++ Native Engine

1. **native/cpp/engine/video_processor.h/cpp**
   - FFmpeg initialization
   - Video frame processing
   - Codec handling

2. **native/cpp/ffmpeg_bridge/ffmpeg_bridge.h/cpp**
   - JNI wrappers for Android
   - Swift wrappers for iOS
   - Exposes video encoding interface

3. **native/cpp/CMakeLists.txt** (already exists, needs population)

#### 5.2 Platform Channels

1. **android/app/src/main/kotlin/com/example/cinematic_editor/VideoExportChannel.kt**
   - Method channel: `com.cinematiceditor/video_export`
   - Handles FFmpeg calls from Flutter

2. **ios/Runner/VideoExportChannel.swift**
   - iOS equivalent using MethodChannel

3. **lib/core/services/native/video_export_channel.dart**
   - Dart-side platform channel wrapper

---

## 4. FILES THAT MUST BE REFACTORED (In Order)

### CRITICAL REFACTORS

| File | Issue | Action | Priority |
|------|-------|--------|----------|
| `lib/features/editor/presentation/cubit/editor_cubit.dart` | **Oversized** (800+ lines, too many responsibilities) | Split into: PlaybackCubit, TimelineCubit, AudioCubit, AICubit | 🔴 P0 |
| `lib/main.dart` | GetIt minimal DI | Full module setup with factories for all services | 🔴 P0 |
| `lib/features/subscription/services/device_security_service.dart` | Mixed concerns (security + subscription) | Move to data layer as EncryptionService | 🟠 P1 |
| `lib/core/services/undo_redo_service.dart` | Uses temp files, not persistent DB | Refactor to use Drift/Hive for history | 🟠 P1 |
| `lib/features/ai_commands/services/ai_command_parser_service.dart` | Tightly coupled to Dio | Extract into repository pattern | 🟠 P1 |
| `lib/features/editor/presentation/screens/editor_screen.dart` | Monolithic widget | Break into smaller composable widgets | 🟡 P2 |
| `pubspec.yaml` | 25+ unused dependencies | Remove or comment pending: firebase_*, tflite_*, hive, drift | 🟡 P2 |

### REFACTOR PLAN FOR EditorCubit

**Current State:** Single 800-line Cubit handling everything (timeline, playback, export, AI, audio)

**Target State:** 4 separate Cubits with clear responsibilities

```
lib/features/editor/presentation/cubit/
├── timeline_cubit.dart          (VideoClip + AudioClip CRUD)
├── playback_cubit.dart          (Play/pause, seek, zoom)
├── audio_cubit.dart             (Audio track management, mixing)
├── ai_cubit.dart                (AI action parsing + application)
├── editor_state.dart            (Root state combining above)
└── editor_cubit.dart            (Coordinator Cubit)
```

---

## 5. DEPENDENCY ISSUES & CLEANUP

### Unused Dependencies (Bloat Alert)

These were declared in `pubspec.yaml` but are **never imported** in lib/:

1. **video_player** — used in blueprint but code not fully wired
2. **just_audio** — audio playback not implemented
3. **ffmpeg_kit_flutter_full_gpl** — export pipeline not implemented
4. **tflite_flutter** — ML models not loaded
5. **google_mediapipe** — background removal not integrated
6. **hive**, **hive_flutter** — database not set up
7. **drift**, **sqlite3_flutter_libs** — no Drift models
8. **retrofit**, **json_annotation** — API clients not generated
9. **web_socket_channel** — real-time features not planned yet
10. **firebase_core, firebase_analytics, firebase_crashlytics, firebase_auth, cloud_firestore** — not initialized
11. **in_app_purchase**, **purchases_flutter** — payment not integrated
12. **image_picker**, **file_picker** — media picking partially needed
13. **cached_network_image** — no network images yet
14. **photo_view** — no image preview needed
15. **syncfusion_flutter_sliders** — custom sliders preferred

### Recommendation
Create `.dependencies_status.yaml` to track:
- Ready (green): video_player, flutter_bloc, equatable, uuid
- In Progress (yellow): none yet
- Pending (red): ffmpeg_kit, hive, drift, firebase_*, retrofit, tflite_flutter

---

## 6. FOLDER STRUCTURE GAP ANALYSIS

### Blueprint Expects (From PROJECT_SOURCE_MASTER.txt)

```
lib/
├── core/
│   ├── engine/              ❌ MISSING (Native C++ bridge placeholder)
│   ├── models/              ✅ EXISTS (timeline_models.dart)
│   ├── services/            ⚠️  INCOMPLETE (only undo_redo, device_security)
│   │   ├── database/        ❌ MISSING
│   │   ├── network/         ❌ MISSING
│   │   └── native/          ❌ MISSING
│   └── utils/               ❌ MISSING
├── features/
│   ├── ai_commands/
│   │   ├── data/            ❌ MISSING (models, mappers, repositories)
│   │   ├── domain/          ❌ MISSING (use cases, entities)
│   │   ├── presentation/    ⚠️  INCOMPLETE (services only)
│   │   └── services/        ✅ EXISTS (parser only)
│   ├── audio/
│   │   ├── data/            ❌ MISSING
│   │   ├── domain/          ❌ MISSING
│   │   ├── presentation/    ❌ MISSING
│   │   └── services/        ❌ MISSING
│   ├── export/              ❌ COMPLETELY MISSING
│   ├── templates/           ❌ MISSING (UI only, no logic)
│   ├── auth/                ❌ MISSING
│   ├── subscription/
│   │   ├── data/            ❌ MISSING
│   │   ├── domain/          ❌ MISSING
│   │   ├── presentation/    ❌ MISSING
│   │   └── services/        ⚠️  INCOMPLETE (device_security only)
│   ├── editor/
│   │   ├── data/            ❌ MISSING (repositories)
│   │   ├── domain/          ❌ MISSING (use cases)
│   │   ├── presentation/    ⚠️  EXISTS (UI mostly, Cubit oversized)
│   │   └── services/        ❌ MISSING
│   └── ...
├── shared/
│   ├── constants/           ✅ EXISTS
│   ├── theme/               ✅ EXISTS
│   ├── widgets/             ❌ MISSING (reusable UI components)
│   └── utils/               ❌ MISSING
└── main.dart                ✅ EXISTS (minimal DI)

assets/
├── fonts/                   ❌ EMPTY (blueprint expects: Inter-*.ttf)
├── icons/                   ❌ EMPTY
└── animations/              ❌ EMPTY

native/
├── cpp/
│   ├── engine/              ❌ EMPTY (no .h/.cpp)
│   ├── ffmpeg_bridge/       ❌ EMPTY
│   └── CMakeLists.txt       ⚠️  EXISTS (template only)
├── kotlin/ (Android)        ❌ MISSING (VideoExportChannel.kt)
└── swift/ (iOS)             ❌ MISSING (VideoExportChannel.swift)

backend/
├── app/
│   ├── api/                 ❌ EMPTY (no routes)
│   ├── models/              ❌ EMPTY
│   ├── services/            ❌ EMPTY
│   └── core/                ❌ EMPTY
└── requirements.txt         ❌ MISSING (FastAPI + AWS deps)
```

---

## 7. PRIORITY IMPLEMENTATION ORDER

### **MUST DO (Weeks 1-2)**

1. ✅ Create asset files (fonts, icons, placeholder animations) — *prevents build errors*
2. ✅ Refactor EditorCubit into 4 smaller Cubits — *reduces complexity*
3. ✅ Set up full DI module with all service factories — *improves testability*
4. ✅ Create data layer scaffold (repositories, DTOs, mappers) — *enables persistence*
5. ✅ Create domain layer scaffold (use cases, entities) — *enforces architecture*

### **SHOULD DO (Weeks 3-4)**

6. ✅ Implement FFmpeg export pipeline (native bridge + service)
7. ✅ Implement Drift/Hive database persistence
8. ✅ Generate Retrofit API clients
9. ✅ Implement subscription module (IAP setup)
10. ✅ Add unit tests for Cubits, services, repositories

### **NICE TO HAVE (Weeks 5+)**

11. ⬜ Implement background removal (MediaPipe)
12. ⬜ Implement audio mixing (just_audio)
13. ⬜ Add platform channels (native video export acceleration)
14. ⬜ Implement cloud sync (Firebase)
15. ⬜ Add analytics dashboards

---

## 8. BLOCKERS & RISKS

### Technical Blockers

| Blocker | Root Cause | Mitigation | Timeline |
|---------|-----------|------------|----------|
| **FFmpeg Not Integrated** | Native code not compiled; JNI/Swift bridges missing | Build CMakeLists.txt, create platform channels | Week 2-3 |
| **No Database Schema** | Drift models not defined | Define @DataClass entities + migrations | Week 1 |
| **Retrofit Clients Not Generated** | No @RestApi annotated interfaces | Create API contract models + run build_runner | Week 1 |
| **GetIt Incomplete** | Only 1 service registered | Full module pattern setup | Week 1 |
| **Asset Files Empty** | Not acquired | Placeholder assets needed | Week 1 |

### Business Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| **Export fails on device** | Cannot ship app | Medium | Early prototype on Android + iOS |
| **Subscription IAP fails** | Revenue lost | Medium | Test with actual IAP sandbox first |
| **Database migration issues** | Data loss | Low | Schema versioning + tests |
| **Performance degradation** | UX poor | Medium | Benchmark on low-end devices |

---

## 9. TESTING & VALIDATION GATES

### Pre-Phase 1 Review
- [ ] Folder structure complete and matches blueprint
- [ ] All models have valid toJson/fromJson
- [ ] pubspec.yaml dependencies rationalized

### Pre-Phase 2 Review
- [ ] DI container fully configured
- [ ] 50% unit test coverage (Cubits, services)
- [ ] 1 e2e test: "Create Project → Save → Load"

### Pre-Phase 3 Review
- [ ] Export pipeline works on Android simulator
- [ ] FFmpeg produces valid MP4
- [ ] Progress tracking accurate

### Pre-Phase 4 Review
- [ ] API clients generate without errors
- [ ] Mock API responses work in tests
- [ ] Network error handling tested

### Pre-Phase 5 Review
- [ ] Subscription sandbox testing complete
- [ ] Native platform channels functional
- [ ] Performance benchmarks green

---

## 10. ESTIMATED EFFORT

| Phase | Tasks | Est. Hours | Priority |
|-------|-------|-----------|----------|
| Phase 1: Foundation | 8 files (DB, repos, use cases) | 40 | 🔴 P0 |
| Phase 2: Export | 6 files (export service, Cubit, UI) | 50 | 🔴 P0 |
| Phase 3: Subscription | 4 files (payment integration) | 25 | 🟠 P1 |
| Phase 4: Network | 4 files (API clients) | 20 | 🟠 P1 |
| Phase 5: Native | 5 files (C++, platform channels) | 60 | 🟠 P1 |
| **Refactors** | EditorCubit split, DI setup, cleanup | 30 | 🔴 P0 |
| **Testing** | Unit + integration tests | 40 | 🟡 P2 |
| **TOTAL** | — | **265 hours** (~7 weeks, 1 dev) | — |

---

## 11. NEXT IMMEDIATE STEPS (Do Today)

```bash
# 1. Create foundation files (no code yet, just scaffolds)
mkdir -p lib/core/database/{drift,hive,mappers}
mkdir -p lib/core/network/{api,interceptors,exceptions}
mkdir -p lib/features/export/{data,domain,presentation/{cubit,screens,widgets}}
mkdir -p lib/features/subscription/{data,domain}
mkdir -p native/cpp/{engine,ffmpeg_bridge}

# 2. Stub out interfaces (no implementation)
touch lib/core/database/project_storage_service.dart
touch lib/features/editor/data/repositories/timeline_repository_interface.dart
touch lib/features/export/services/export_service.dart
touch lib/features/subscription/domain/entities/subscription_plan.dart

# 3. Create .dependencies_status.yaml to track which packages are actually needed
cat > .dependencies_status.yaml << 'EOF'
# Track dependency usage
status:
  green:  # Ready to use
    - flutter_bloc
    - equatable
    - uuid
    - flutter
    - get_it
    - dio
    - path_provider
  yellow: # In progress (wired but incomplete)
    - video_player
    - flutter_secure_storage
  red:    # Pending integration (declared but unused)
    - ffmpeg_kit_flutter_full_gpl
    - just_audio
    - hive
    - drift
    - retrofit
    - json_annotation
    - firebase_*
    - in_app_purchase
    - purchases_flutter
    - tflite_flutter
    - google_mediapipe
EOF

# 4. Commit these scaffolds
git add -A
git commit -m "🏗️ Scaffold Phase 1: Data/Domain/Export layers (no implementation yet)"
```

---

## 12. SUMMARY TABLE: What's Missing vs Blueprint

| Component | Blueprint | Repo | Gap | Effort |
|-----------|-----------|------|-----|--------|
| **Data Layer** | Full CRUD repos | None | 100% | High |
| **Domain Layer** | Use cases/interactors | None | 100% | Medium |
| **Export Pipeline** | FFmpeg + service | None | 100% | Very High |
| **Persistence** | Drift DB | UndoRedo temp files | 95% | High |
| **Subscription** | IAP + backend | None | 100% | Medium |
| **API Clients** | Retrofit generated | Manual Dio | 80% | Medium |
| **DI Setup** | Full GetIt module | 1 service | 90% | Low |
| **Native Bridge** | C++ + JNI/Swift | None | 100% | Very High |
| **Tests** | 60%+ coverage | ~5% | 95% | High |
| **Assets** | Fonts/icons/anims | Empty folders | 100% | Low |

**Total Gap Coverage: 87% of blueprint NOT yet implemented**

---

## APPENDIX: File Creation Template

To create a new file with proper structure:

```dart
// lib/features/[FEATURE]/data/repositories/[name]_repository_impl.dart

import 'package:cinematic_editor/features/[feature]/domain/repositories/[name]_repository.dart';
import 'package:cinematic_editor/core/models/timeline_models.dart';

class [Name]RepositoryImpl implements [Name]Repository {
  // TODO: Implement interface methods
  
  @override
  Future<void> example() async {
    // Implementation
  }
}
```

---

**End of Gap Audit & Implementation Plan**

*Note: This document is read-only during gap analysis phase. Implementation begins only after stakeholder review.*
