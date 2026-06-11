# Model Download Architecture

**Repository:** cinematic_editor
**Date:** 2026-06-11
**Service:** `lib/features/ai_commands/services/model_download_service.dart`

---

## Overview

The ModelDownloadService manages the lifecycle of ML model files on the device. It handles on-demand downloading, versioning, integrity verification, local caching, retry logic, and automatic loading into LocalAiEngine.

---

## Download Flow

```
ModelDownloadRequest
    |
    v
Check cache (CacheManifest + file existence + size validation)
    |
    ├── Cache hit + version match + file valid
    |       |
    |       v
    |   Return ModelDownloadResult.cached
    |   If autoLoadIntoEngine: load into LocalAiEngine
    |
    └── Cache miss / version mismatch / file missing
            |
            v
        Resolve ModelMetadata from ModelRegistry
            |
            v
        Resolve download URL (CDN / API)
            |
            v
        Download with retry (max 3, exponential backoff)
            |-- Attempt 1
            |-- Attempt 2 (after 2s)
            |-- Attempt 3 (after 4s)
            |
            v
        Stream response with progress tracking
            |
            v
        Verify SHA-256 checksum
            |-- Mismatch → fail attempt, retry
            |
            v
        Write to disk (atomic: temp file → rename)
            |
            v
        Update CacheManifest + persist to disk
            |
            v
        If autoLoadIntoEngine: load into LocalAiEngine
            |
            v
        Return ModelDownloadResult.downloaded
```

---

## Type System

### ModelMetadata

Describes a downloadable model — the source of truth for what the app knows about.

| Field | Type | Description |
|---|---|---|
| id | `String` | Unique identifier (e.g., `self_segmentation`) |
| displayName | `String` | Human-readable name |
| description | `String` | What the model does |
| version | `String` | Semantic version (e.g., `1.0.0`) |
| sizeBytes | `int` | Exact file size in bytes |
| sha256 | `String` | Expected SHA-256 hash of the model file |
| fileName | `String` | File name on disk (e.g., `self_segmentation.tflite`) |
| modelFormat | `String` | `tflite`, `onnx`, or `mediapipe` |
| inputShape | `List<int>` | Model input tensor shape |
| outputShape | `List<int>` | Model output tensor shape |
| inputType | `String` | Input tensor data type |
| outputType | `String` | Output tensor data type |
| quantized | `bool` | Whether the model uses quantization |
| numThreads | `int?` | Recommended inference thread count |
| releasedAt | `DateTime?` | When this version was published |
| minAppVersion | `String?` | Minimum app version required |

Has a `toModelDefinition(localPath)` method that converts to `TFLiteModelDefinition` for LocalAiEngine loading.

### ModelDownloadRequest

| Field | Type | Default | Description |
|---|---|---|---|
| modelId | `String` | required | Which model to download |
| targetVersion | `String?` | null | Specific version, or null for latest |
| forceRedownload | `bool` | false | Skip cache check, always download |
| autoLoadIntoEngine | `bool` | true | Load into LocalAiEngine after download |

### ModelDownloadResult

| Field | Type | Description |
|---|---|---|
| success | `bool` | Whether the operation succeeded |
| modelId | `String` | Which model was requested |
| localPath | `String?` | Path to the model file on disk |
| version | `String?` | Version that was downloaded/found |
| sizeBytes | `int?` | File size in bytes |
| downloadTime | `Duration?` | Wall time for download (not set for cache hits) |
| errorMessage | `String?` | Error if failed |
| status | `ModelDownloadStatus` | Final pipeline step reached |
| wasAlreadyCached | `bool` | True if the model was already on disk |
| loadedIntoEngine | `bool` | True if loaded into LocalAiEngine successfully |

Three factory constructors:
- `ModelDownloadResult.cached()` — model was already on disk
- `ModelDownloadResult.downloaded()` — model was fetched from network
- `ModelDownloadResult.failed()` — operation failed

### ModelDownloadProgress

Emitted during download via `ModelDownloadProgressCallback`.

| Field | Type | Description |
|---|---|---|
| modelId | `String` | Which model is downloading |
| status | `ModelDownloadStatus` | Current pipeline step |
| receivedBytes | `int` | Bytes received so far |
| totalBytes | `int` | Total expected bytes |
| speedBytesPerSec | `double` | Current download speed |
| elapsed | `Duration` | Time since download started |
| progress | `double` | Computed: receivedBytes / totalBytes |

### ModelDownloadStatus

10-state lifecycle:

`idle` → `checkingCache` → `fetchingMetadata` → `downloading` → `verifyingChecksum` → `writingToDisk` → `loadingIntoEngine` → `completed`

Error states: `failed`, `cancelled`

---

## Versioning

### Model Registry

`ModelRegistry` is a static map of all known models and their metadata. Currently hardcoded from `PredefinedModels` definitions. In production, this would be fetched from a remote manifest API:

```
GET /v1/models/manifest
Response: { models: [ ModelMetadata, ModelMetadata, ... ] }
```

The registry enables:
- **Update detection**: `isUpdateAvailable(modelId)` compares cached version vs. registry version
- **Version pinning**: `ModelDownloadRequest.targetVersion` requests a specific version
- **Batch updates**: `modelsWithUpdates` lists all models with newer versions available

### Cache Manifest

Persisted as `ai_models/cache_manifest.json` in the application support directory. Contains:

```json
{
  "entries": {
    "self_segmentation": {
      "modelId": "self_segmentation",
      "version": "1.0.0",
      "localPath": "/data/.../ai_models/self_segmentation.tflite",
      "sha256": "abc123...",
      "sizeBytes": 3145728,
      "downloadedAt": "2026-06-11T10:30:00Z",
      "modelFormat": "tflite"
    }
  },
  "updatedAt": "2026-06-11T10:30:00Z"
}
```

---

## Checksum Verification

Every downloaded model is verified against its expected SHA-256 hash before being written to the final location.

Flow:
1. Collect all response bytes into memory
2. Compute `sha256.convert(bytes)`
3. Compare against `ModelMetadata.sha256`
4. If mismatch: report error, retry (up to `_maxRetries`)
5. If match: proceed to disk write

The actual hash is stored both in the registry (expected) and the manifest (actual), allowing future integrity audits.

---

## Local Caching

### Storage Location

Models are stored in the application support directory (persisted across app launches, not backed up to cloud):

```
getApplicationSupportDirectory()/
  projects/
    ai_models/
      self_segmentation.tflite
      deeplabv3_lite.tflite
      cache_manifest.json
```

This follows the same pattern as `ProxyCacheService` which uses `getTemporaryDirectory()/projects/{projectId}/proxies/`.

### Atomic Writes

Model files are written atomically to prevent corruption from interrupted writes:

1. Write bytes to `{fileName}.tmp`
2. Delete existing `{fileName}` if present
3. Rename `.tmp` to final name

### Cache Validation

A cached model is considered valid only when all three checks pass:
1. Entry exists in the cache manifest
2. File exists on disk at the recorded path
3. File size matches the manifest's `sizeBytes`

If any check fails, the cache entry is removed and the model is re-downloaded.

### Cache Operations

| Method | Description |
|---|---|
| `isModelCached(id)` | Check if model is in cache and valid |
| `getCachedModelPath(id)` | Get local path if cached |
| `deleteCachedModel(id)` | Remove from disk, manifest, and engine |
| `clearAllCache()` | Delete entire ai_models directory |
| `getCacheSize()` | Sum of all cached model file sizes |
| `cachedModels` | List all cache entries |

---

## Retry Mechanism

Exponential backoff with 3 attempts:

| Attempt | Delay before retry |
|---|---|
| 1 | 0s (initial attempt) |
| 2 | 2s |
| 3 | 4s |

Retry is triggered for:
- HTTP errors (non-200 status)
- Network timeouts
- Checksum mismatches
- Disk write failures

Retry is NOT triggered for:
- Unknown model ID (permanent error)
- Version mismatch (permanent error)
- Download already in progress (concurrency guard)

### Concurrency Guard

`_activeDownloads` map prevents concurrent downloads of the same model. If `downloadModel()` is called for a model already being downloaded, it returns a failed result immediately rather than queueing.

---

## Progress Reporting

`ModelDownloadProgressCallback` receives updates at each pipeline step:

```dart
void onProgress(ModelDownloadProgress progress) {
  // progress.status      — current step (downloading, verifying, etc.)
  // progress.progress    — 0.0 to 1.0 download progress
  // progress.formattedSize — "1.5 / 3.0 MB" human-readable
  // progress.speedBytesPerSec — current download speed
}
```

During the `downloading` phase, progress updates are emitted for every HTTP stream chunk, providing smooth real-time progress.

---

## Integration with LocalAiEngine

The service integrates with LocalAiEngine through two paths:

### Automatic (via `autoLoadIntoEngine`)

When `ModelDownloadRequest.autoLoadIntoEngine` is true (default):
1. After successful download or cache hit
2. `ModelMetadata.toModelDefinition(localPath)` creates a `TFLiteModelDefinition`
3. `LocalAiEngine.loadModel(modelDef:)` loads the model into the TFLite interpreter
4. `ModelDownloadResult.loadedIntoEngine` reports whether loading succeeded

### Convenience Method

```dart
// Ensure model is downloaded and loaded — used by InferencePipelineService
final result = await modelDownloadService.ensureModelAvailable(
  'self_segmentation',
  onProgress: (p) => print(p),
);
```

### InferencePipelineService Integration

The inference pipeline uses `ModelDownloadService` in its `_ensureModelLoaded()` method:

```dart
Future<bool> _ensureModelLoaded(AIModelSelection model) async {
  final modelId = _modelIdForSelection(model);
  final result = await _modelDownloadService.ensureModelAvailable(modelId);
  return result.success;
}
```

---

## URL Resolution

`_resolveDownloadUrl()` is the integration point for the remote model distribution infrastructure. No actual URLs are hardcoded.

Production patterns:
- CDN with versioned paths: `https://cdn.example.com/models/{id}/{version}/{fileName}`
- API download endpoint: `${AppConstants.apiBaseUrl}/models/{id}/download`
- Signed URL from auth endpoint: fetch a time-limited URL from the API

The current sentinel value produces a clear error if download is attempted before configuration.

---

## Dependency Notes

The service uses two packages not yet in pubspec.yaml:

| Package | Purpose | Status |
|---|---|---|
| `crypto` | SHA-256 checksum verification | Not in pubspec — needed for production |
| `http` | HTTP client for model downloads | Not in pubspec — needed for production |

Both are standard Dart packages with no native dependencies. When activating the download pipeline, add:

```yaml
dependencies:
  crypto: ^3.0.3
  http: ^1.2.0
```

The `path_provider` and `path` packages are already used by `ProxyCacheService` and are in pubspec.

---

## Blocking Gaps

| Gap | Impact | Resolution |
|---|---|---|
| No remote manifest endpoint | ModelRegistry is hardcoded; no version updates without app release | Build `/v1/models/manifest` API |
| No download URL configuration | `_resolveDownloadUrl` returns sentinel | Configure CDN or API download endpoint |
| `crypto` not in pubspec | SHA-256 verification will not compile | Add `crypto: ^3.0.3` to pubspec.yaml |
| `http` not in pubspec | HTTP download will not compile | Add `http: ^1.2.0` to pubspec.yaml |
| No disk space checking | Download could fail if device is low on storage | Add pre-download storage check |
| No download cancellation | Active download runs to completion | Add `CancelToken` pattern for user-initiated cancel |
