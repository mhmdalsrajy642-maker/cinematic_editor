// lib/features/ai_commands/services/model_download_service.dart
// On-demand AI model download, versioning, checksum verification,
// local caching, retry mechanism, and progress reporting.
// Integrates with LocalAiEngine for automatic loading after download.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../shared/constants/app_constants.dart';
import 'local_ai_engine.dart';

// ====================================================
// Strongly Typed Models
// ====================================================

/// Metadata describing a downloadable model
class ModelMetadata {
  final String id;
  final String displayName;
  final String description;
  final String version;
  final int sizeBytes;
  final String sha256;
  final String fileName;
  final String modelFormat;  // 'tflite', 'onnx', 'mediapipe'
  final List<int> inputShape;
  final List<int> outputShape;
  final String inputType;
  final String outputType;
  final bool quantized;
  final int? numThreads;
  final DateTime? releasedAt;
  final String? minAppVersion;
  final Map<String, String>? platformOverrides;

  const ModelMetadata({
    required this.id,
    required this.displayName,
    required this.description,
    required this.version,
    required this.sizeBytes,
    required this.sha256,
    required this.fileName,
    required this.modelFormat = 'tflite',
    required this.inputShape,
    required this.outputShape,
    required this.inputType,
    required this.outputType,
    this.quantized = false,
    this.numThreads,
    this.releasedAt,
    this.minAppVersion,
    this.platformOverrides,
  });

  /// TFLiteModelDefinition derived from this metadata + local path
  TFLiteModelDefinition toModelDefinition(String localPath) {
    return TFLiteModelDefinition(
      modelPath: localPath,
      name: id,
      description: description,
      inputShape: inputShape,
      outputShape: outputShape,
      inputType: inputType,
      outputType: outputType,
      quantized: quantized,
      numThreads: numThreads,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'description': description,
        'version': version,
        'sizeBytes': sizeBytes,
        'sha256': sha256,
        'fileName': fileName,
        'modelFormat': modelFormat,
        'inputShape': inputShape,
        'outputShape': outputShape,
        'inputType': inputType,
        'outputType': outputType,
        'quantized': quantized,
        'numThreads': numThreads,
        'releasedAt': releasedAt?.toIso8601String(),
        'minAppVersion': minAppVersion,
      };

  factory ModelMetadata.fromJson(Map<String, dynamic> json) {
    return ModelMetadata(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      description: json['description'] as String? ?? '',
      version: json['version'] as String,
      sizeBytes: json['sizeBytes'] as int,
      sha256: json['sha256'] as String,
      fileName: json['fileName'] as String,
      modelFormat: json['modelFormat'] as String? ?? 'tflite',
      inputShape: (json['inputShape'] as List).cast<int>(),
      outputShape: (json['outputShape'] as List).cast<int>(),
      inputType: json['inputType'] as String,
      outputType: json['outputType'] as String,
      quantized: json['quantized'] as bool? ?? false,
      numThreads: json['numThreads'] as int?,
      releasedAt: json['releasedAt'] != null
          ? DateTime.tryParse(json['releasedAt'] as String)
          : null,
      minAppVersion: json['minAppVersion'] as String?,
    );
  }

  @override
  String toString() => '$id v$version ($displayName, '
      '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB)';
}

/// Request to download a model
class ModelDownloadRequest {
  final String modelId;
  final String? targetVersion;
  final bool forceRedownload;
  final bool autoLoadIntoEngine;

  const ModelDownloadRequest({
    required this.modelId,
    this.targetVersion,
    this.forceRedownload = false,
    this.autoLoadIntoEngine = true,
  });
}

/// Result of a model download operation
class ModelDownloadResult {
  final bool success;
  final String modelId;
  final String? localPath;
  final String? version;
  final int? sizeBytes;
  final Duration? downloadTime;
  final String? errorMessage;
  final ModelDownloadStatus status;
  final bool wasAlreadyCached;
  final bool loadedIntoEngine;

  const ModelDownloadResult({
    required this.success,
    required this.modelId,
    this.localPath,
    this.version,
    this.sizeBytes,
    this.downloadTime,
    this.errorMessage,
    required this.status,
    this.wasAlreadyCached = false,
    this.loadedIntoEngine = false,
  });

  factory ModelDownloadResult.cached({
    required String modelId,
    required String localPath,
    required String version,
    required int sizeBytes,
    bool loadedIntoEngine = false,
  }) {
    return ModelDownloadResult(
      success: true,
      modelId: modelId,
      localPath: localPath,
      version: version,
      sizeBytes: sizeBytes,
      status: ModelDownloadStatus.completed,
      wasAlreadyCached: true,
      loadedIntoEngine: loadedIntoEngine,
    );
  }

  factory ModelDownloadResult.downloaded({
    required String modelId,
    required String localPath,
    required String version,
    required int sizeBytes,
    required Duration downloadTime,
    bool loadedIntoEngine = false,
  }) {
    return ModelDownloadResult(
      success: true,
      modelId: modelId,
      localPath: localPath,
      version: version,
      sizeBytes: sizeBytes,
      downloadTime: downloadTime,
      status: ModelDownloadStatus.completed,
      loadedIntoEngine: loadedIntoEngine,
    );
  }

  factory ModelDownloadResult.failed({
    required String modelId,
    required String errorMessage,
    required ModelDownloadStatus status,
  }) {
    return ModelDownloadResult(
      success: false,
      modelId: modelId,
      errorMessage: errorMessage,
      status: status,
    );
  }
}

/// Lifecycle status of a model download
enum ModelDownloadStatus {
  idle,
  checkingCache,
  fetchingMetadata,
  downloading,
  verifyingChecksum,
  writingToDisk,
  loadingIntoEngine,
  completed,
  failed,
  cancelled,
}

/// Progress update during a model download
class ModelDownloadProgress {
  final String modelId;
  final ModelDownloadStatus status;
  final int receivedBytes;
  final int totalBytes;
  final double speedBytesPerSec;
  final Duration elapsed;

  const ModelDownloadProgress({
    required this.modelId,
    required this.status,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.speedBytesPerSec = 0,
    this.elapsed = Duration.zero,
  });

  double get progress =>
      totalBytes > 0 ? receivedBytes / totalBytes : 0.0;

  String get formattedSize =>
      '${(receivedBytes / 1024 / 1024).toStringAsFixed(1)} / '
      '${(totalBytes / 1024 / 1024).toStringAsFixed(1)} MB';

  @override
  String toString() =>
      'ModelDownloadProgress($modelId: ${(progress * 100).toStringAsFixed(0)}%, '
      '$status, $formattedSize)';
}

typedef ModelDownloadProgressCallback = void Function(ModelDownloadProgress progress);

// ====================================================
// Model Registry
// ====================================================

/// Known model registry — maps model IDs to their metadata.
/// In production, this would be fetched from a remote manifest endpoint.
/// Currently hardcoded with the models defined in PredefinedModels.
abstract class ModelRegistry {
  static final Map<String, ModelMetadata> _entries = {
    'self_segmentation': ModelMetadata(
      id: 'self_segmentation',
      displayName: 'Self Segmentation',
      description: 'Portrait segmentation for background removal',
      version: '1.0.0',
      sizeBytes: 3145728,
      sha256: '',
      fileName: 'self_segmentation.tflite',
      inputShape: [1, 256, 256, 3],
      outputShape: [1, 256, 256, 1],
      inputType: 'float32',
      outputType: 'float32',
      quantized: false,
      numThreads: 2,
    ),
    'deeplabv3_lite': ModelMetadata(
      id: 'deeplabv3_lite',
      displayName: 'DeepLabV3 Lite',
      description: 'General semantic segmentation',
      version: '1.0.0',
      sizeBytes: 2097152,
      sha256: '',
      fileName: 'deeplabv3_lite.tflite',
      inputShape: [1, 257, 257, 3],
      outputShape: [1, 257, 257, 21],
      inputType: 'uint8',
      outputType: 'uint8',
      quantized: true,
      numThreads: 4,
    ),
    'mobilenetv3': ModelMetadata(
      id: 'mobilenetv3',
      displayName: 'MobileNetV3',
      description: 'Image classification',
      version: '1.0.0',
      sizeBytes: 5242880,
      sha256: '',
      fileName: 'mobilenetv3.tflite',
      inputShape: [1, 224, 224, 3],
      outputShape: [1, 1000],
      inputType: 'uint8',
      outputType: 'uint8',
      quantized: true,
      numThreads: 4,
    ),
    'image_to_text': ModelMetadata(
      id: 'image_to_text',
      displayName: 'Image to Text',
      description: 'Caption generation from image input',
      version: '1.0.0',
      sizeBytes: 41943040,
      sha256: '',
      fileName: 'image_to_text.tflite',
      inputShape: [1, 224, 224, 3],
      outputShape: [1, 100],
      inputType: 'float32',
      outputType: 'float32',
      quantized: false,
      numThreads: 2,
    ),
  };

  /// Get metadata for a known model, or null if unknown
  static ModelMetadata? get(String modelId) => _entries[modelId];

  /// List all known model IDs
  static List<String> get allIds => _entries.keys.toList();

  /// List all known model metadata
  static List<ModelMetadata> get all => _entries.values.toList();
}

// ====================================================
// Local Cache Manifest
// ====================================================

/// Tracks which models are cached locally with their versions.
/// Persisted as a JSON file alongside the model files.
class CacheManifest {
  final Map<String, CachedModelEntry> entries;

  CacheManifest([Map<String, CachedModelEntry>? entries])
      : entries = entries ?? {};

  bool contains(String modelId, {String? version}) {
    final entry = entries[modelId];
    if (entry == null) return false;
    if (version != null) return entry.version == version;
    return true;
  }

  CachedModelEntry? get(String modelId) => entries[modelId];

  void put(String modelId, CachedModelEntry entry) {
    entries[modelId] = entry;
  }

  void remove(String modelId) {
    entries.remove(modelId);
  }

  Map<String, dynamic> toJson() => {
        'entries': entries.map((k, v) => MapEntry(k, v.toJson())),
        'updatedAt': DateTime.now().toIso8601String(),
      };

  factory CacheManifest.fromJson(Map<String, dynamic> json) {
    final entriesMap = json['entries'] as Map<String, dynamic>? ?? {};
    return CacheManifest(
      entriesMap.map((k, v) =>
          MapEntry(k, CachedModelEntry.fromJson(v as Map<String, dynamic>))),
    );
  }
}

/// Entry in the cache manifest for a single downloaded model
class CachedModelEntry {
  final String modelId;
  final String version;
  final String localPath;
  final String sha256;
  final int sizeBytes;
  final DateTime downloadedAt;
  final String modelFormat;

  const CachedModelEntry({
    required this.modelId,
    required this.version,
    required this.localPath,
    required this.sha256,
    required this.sizeBytes,
    required this.downloadedAt,
    this.modelFormat = 'tflite',
  });

  Map<String, dynamic> toJson() => {
        'modelId': modelId,
        'version': version,
        'localPath': localPath,
        'sha256': sha256,
        'sizeBytes': sizeBytes,
        'downloadedAt': downloadedAt.toIso8601String(),
        'modelFormat': modelFormat,
      };

  factory CachedModelEntry.fromJson(Map<String, dynamic> json) {
    return CachedModelEntry(
      modelId: json['modelId'] as String,
      version: json['version'] as String,
      localPath: json['localPath'] as String,
      sha256: json['sha256'] as String,
      sizeBytes: json['sizeBytes'] as int,
      downloadedAt: DateTime.parse(json['downloadedAt'] as String),
      modelFormat: json['modelFormat'] as String? ?? 'tflite',
    );
  }
}

// ====================================================
// Model Download Service
// ====================================================

/// Manages on-demand AI model downloads with versioning,
/// checksum verification, local caching, retry, and progress reporting.
class ModelDownloadService {
  final LocalAiEngine _aiEngine;
  final http.Client _httpClient;

  /// Maximum retry attempts for failed downloads
  static const int _maxRetries = 3;

  /// Delay between retries (exponential backoff base)
  static const Duration _retryBaseDelay = Duration(seconds: 2);

  /// Active downloads — prevents concurrent downloads of the same model
  final Map<String, bool> _activeDownloads = {};

  /// In-memory cache manifest
  CacheManifest _manifest = CacheManifest();

  /// Local model storage directory (lazy initialized)
  Directory? _modelsDirectory;

  bool _isInitialized = false;

  ModelDownloadService({
    required LocalAiEngine aiEngine,
    http.Client? httpClient,
  })  : _aiEngine = aiEngine,
        _httpClient = httpClient ?? http.Client();

  bool get isInitialized => _isInitialized;

  // ====================================================
  // Lifecycle
  // ====================================================

  /// Initialize the service: resolve storage directory, load manifest
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _modelsDirectory = await _getModelsDirectory();
      _manifest = await _loadManifest();
      _isInitialized = true;
      debugPrint('ModelDownloadService initialized '
          '(${_manifest.entries.length} cached models)');
    } catch (e) {
      debugPrint('ModelDownloadService init failed: $e');
      rethrow;
    }
  }

  /// Shutdown: persist manifest, close HTTP client
  Future<void> shutdown() async {
    await _persistManifest();
    _httpClient.close();
    _isInitialized = false;
  }

  // ====================================================
  // Download Model
  // ====================================================

  /// Download a model on demand, with caching, verification, and retry.
  Future<ModelDownloadResult> downloadModel(
    ModelDownloadRequest request, {
    ModelDownloadProgressCallback? onProgress,
  }) async {
    if (!_isInitialized) {
      return ModelDownloadResult.failed(
        modelId: request.modelId,
        errorMessage: 'ModelDownloadService not initialized',
        status: ModelDownloadStatus.failed,
      );
    }

    // Prevent concurrent downloads of the same model
    if (_activeDownloads[request.modelId] == true) {
      return ModelDownloadResult.failed(
        modelId: request.modelId,
        errorMessage: 'Download already in progress for ${request.modelId}',
        status: ModelDownloadStatus.failed,
      );
    }

    _activeDownloads[request.modelId] = true;

    try {
      // Step 1: Check cache — skip download if already cached and valid
      onProgress?.call(ModelDownloadProgress(
        modelId: request.modelId,
        status: ModelDownloadStatus.checkingCache,
      ));

      if (!request.forceRedownload) {
        final cached = await _checkCache(
          request.modelId,
          version: request.targetVersion,
        );
        if (cached != null) {
          debugPrint('ModelDownloadService: ${request.modelId} already cached');

          bool loadedIntoEngine = false;
          if (request.autoLoadIntoEngine && _aiEngine.isInitialized) {
            loadedIntoEngine = await _loadIntoEngine(
              request.modelId,
              cached.localPath,
            );
          }

          _activeDownloads[request.modelId] = false;
          return ModelDownloadResult.cached(
            modelId: request.modelId,
            localPath: cached.localPath,
            version: cached.version,
            sizeBytes: cached.sizeBytes,
            loadedIntoEngine: loadedIntoEngine,
          );
        }
      }

      // Step 2: Resolve model metadata
      onProgress?.call(ModelDownloadProgress(
        modelId: request.modelId,
        status: ModelDownloadStatus.fetchingMetadata,
      ));

      final metadata = ModelRegistry.get(request.modelId);
      if (metadata == null) {
        _activeDownloads[request.modelId] = false;
        return ModelDownloadResult.failed(
          modelId: request.modelId,
          errorMessage: 'Unknown model: ${request.modelId}',
          status: ModelDownloadStatus.failed,
        );
      }

      // Verify target version if specified
      if (request.targetVersion != null &&
          request.targetVersion != metadata.version) {
        _activeDownloads[request.modelId] = false;
        return ModelDownloadResult.failed(
          modelId: request.modelId,
          errorMessage: 'Requested version ${request.targetVersion} not found. '
              'Available: ${metadata.version}',
          status: ModelDownloadStatus.failed,
        );
      }

      // Step 3: Download with retry
      final downloadResult = await _downloadWithRetry(
        metadata: metadata,
        onProgress: onProgress,
      );

      if (!downloadResult.success) {
        _activeDownloads[request.modelId] = false;
        return downloadResult;
      }

      // Step 4: Load into engine if requested
      bool loadedIntoEngine = false;
      if (request.autoLoadIntoEngine && _aiEngine.isInitialized) {
        onProgress?.call(ModelDownloadProgress(
          modelId: request.modelId,
          status: ModelDownloadStatus.loadingIntoEngine,
        ));
        loadedIntoEngine = await _loadIntoEngine(
          request.modelId,
          downloadResult.localPath!,
        );
      }

      _activeDownloads[request.modelId] = false;
      return ModelDownloadResult.downloaded(
        modelId: request.modelId,
        localPath: downloadResult.localPath,
        version: metadata.version,
        sizeBytes: metadata.sizeBytes,
        downloadTime: downloadResult.downloadTime!,
        loadedIntoEngine: loadedIntoEngine,
      );
    } catch (e) {
      _activeDownloads[request.modelId] = false;
      return ModelDownloadResult.failed(
        modelId: request.modelId,
        errorMessage: e.toString(),
        status: ModelDownloadStatus.failed,
      );
    }
  }

  // ====================================================
  // Download with Retry
  // ====================================================

  Future<ModelDownloadResult> _downloadWithRetry({
    required ModelMetadata metadata,
    ModelDownloadProgressCallback? onProgress,
  }) async {
    ModelDownloadResult? lastResult;

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      if (attempt > 0) {
        final delay = _retryBaseDelay * (1 << (attempt - 1));
        debugPrint('ModelDownloadService: retry #$attempt for ${metadata.id} '
            'after ${delay.inSeconds}s');
        await Future.delayed(delay);
      }

      lastResult = await _performDownload(
        metadata: metadata,
        onProgress: onProgress,
      );

      if (lastResult.success) return lastResult;

      debugPrint('ModelDownloadService: download attempt #$attempt failed: '
          '${lastResult.errorMessage}');
    }

    return lastResult!;
  }

  /// Single download attempt
  Future<ModelDownloadResult> _performDownload({
    required ModelMetadata metadata,
    ModelDownloadProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Build download URL — in production this comes from a manifest
      // or CDN endpoint. No actual URLs are hardcoded per requirements.
      final downloadUrl = _resolveDownloadUrl(metadata);

      onProgress?.call(ModelDownloadProgress(
        modelId: metadata.id,
        status: ModelDownloadStatus.downloading,
        totalBytes: metadata.sizeBytes,
      ));

      // Stream download with progress tracking
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await _httpClient.send(request);

      if (response.statusCode != 200) {
        stopwatch.stop();
        return ModelDownloadResult.failed(
          modelId: metadata.id,
          errorMessage: 'HTTP ${response.statusCode}: download failed',
          status: ModelDownloadStatus.failed,
        );
      }

      // Collect bytes with progress
      final bytes = <int>[];
      int receivedBytes = 0;
      final contentLength = response.contentLength ?? metadata.sizeBytes;

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        receivedBytes += chunk.length;

        onProgress?.call(ModelDownloadProgress(
          modelId: metadata.id,
          status: ModelDownloadStatus.downloading,
          receivedBytes: receivedBytes,
          totalBytes: contentLength,
          elapsed: stopwatch.elapsed,
          speedBytesPerSec: receivedBytes /
              (stopwatch.elapsedMilliseconds / 1000).clamp(0.001, double.infinity),
        ));
      }

      stopwatch.stop();

      // Verify checksum
      onProgress?.call(ModelDownloadProgress(
        modelId: metadata.id,
        status: ModelDownloadStatus.verifyingChecksum,
        receivedBytes: receivedBytes,
        totalBytes: contentLength,
      ));

      final actualSha256 = sha256.convert(bytes).toString();
      if (metadata.sha256.isNotEmpty && actualSha256 != metadata.sha256) {
        return ModelDownloadResult.failed(
          modelId: metadata.id,
          errorMessage: 'Checksum mismatch. Expected: ${metadata.sha256}, '
              'Got: $actualSha256',
          status: ModelDownloadStatus.failed,
        );
      }

      // Write to disk
      onProgress?.call(ModelDownloadProgress(
        modelId: metadata.id,
        status: ModelDownloadStatus.writingToDisk,
        receivedBytes: receivedBytes,
        totalBytes: contentLength,
      ));

      final localPath = await _writeModelFile(
        metadata.fileName,
        Uint8List.fromList(bytes),
      );

      // Update cache manifest
      _manifest.put(metadata.id, CachedModelEntry(
        modelId: metadata.id,
        version: metadata.version,
        localPath: localPath,
        sha256: actualSha256,
        sizeBytes: bytes.length,
        downloadedAt: DateTime.now(),
        modelFormat: metadata.modelFormat,
      ));
      await _persistManifest();

      return ModelDownloadResult.downloaded(
        modelId: metadata.id,
        localPath: localPath,
        version: metadata.version,
        sizeBytes: bytes.length,
        downloadTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return ModelDownloadResult.failed(
        modelId: metadata.id,
        errorMessage: e.toString(),
        status: ModelDownloadStatus.failed,
      );
    }
  }

  // ====================================================
  // Cache Operations
  // ====================================================

  /// Check if a model is already cached and its file still exists on disk.
  /// Returns the cache entry if valid, null otherwise.
  Future<CachedModelEntry?> _checkCache(
    String modelId, {
    String? version,
  }) async {
    final entry = _manifest.get(modelId);
    if (entry == null) return null;

    // Version mismatch means we need to re-download
    if (version != null && entry.version != version) return null;

    // File must still exist on disk
    final file = File(entry.localPath);
    if (!await file.exists()) {
      _manifest.remove(modelId);
      return null;
    }

    // Verify file size matches manifest
    final fileSize = await file.length();
    if (fileSize != entry.sizeBytes) {
      // Corrupted cache entry — remove and re-download
      await file.delete();
      _manifest.remove(modelId);
      await _persistManifest();
      return null;
    }

    return entry;
  }

  /// Check if a model is available locally (no download needed)
  Future<bool> isModelCached(String modelId, {String? version}) async {
    final entry = await _checkCache(modelId, version: version);
    return entry != null;
  }

  /// Get the local path for a cached model, or null if not cached
  Future<String?> getCachedModelPath(String modelId) async {
    final entry = await _checkCache(modelId);
    return entry?.localPath;
  }

  /// Delete a cached model from disk and manifest
  Future<bool> deleteCachedModel(String modelId) async {
    final entry = _manifest.get(modelId);
    if (entry == null) return false;

    final file = File(entry.localPath);
    if (await file.exists()) {
      await file.delete();
    }

    // Unload from engine if loaded
    if (_aiEngine.isModelLoaded(modelId)) {
      await _aiEngine.unloadModel(modelId);
    }

    _manifest.remove(modelId);
    await _persistManifest();
    return true;
  }

  /// Clear all cached models
  Future<void> clearAllCache() async {
    if (_modelsDirectory == null) return;

    final dir = _modelsDirectory!;
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      await dir.create(recursive: true);
    }

    _manifest = CacheManifest();
    await _persistManifest();
  }

  /// Get total disk space used by cached models
  Future<int> getCacheSize() async {
    int total = 0;
    for (final entry in _manifest.entries.values) {
      final file = File(entry.localPath);
      if (await file.exists()) {
        total += await file.length();
      }
    }
    return total;
  }

  /// List all cached models with their entries
  List<CachedModelEntry> get cachedModels => _manifest.entries.values.toList();

  // ====================================================
  // Versioning
  // ====================================================

  /// Check if a cached model is outdated compared to the registry
  bool isUpdateAvailable(String modelId) {
    final cached = _manifest.get(modelId);
    if (cached == null) return false;

    final latest = ModelRegistry.get(modelId);
    if (latest == null) return false;

    return cached.version != latest.version;
  }

  /// Get models that have updates available
  List<String> get modelsWithUpdates {
    return ModelRegistry.allIds
        .where((id) => isUpdateAvailable(id))
        .toList();
  }

  // ====================================================
  // Engine Integration
  // ====================================================

  /// Load a cached model into LocalAiEngine
  Future<bool> _loadIntoEngine(String modelId, String localPath) async {
    try {
      final metadata = ModelRegistry.get(modelId);
      if (metadata == null) return false;

      final modelDef = metadata.toModelDefinition(localPath);
      await _aiEngine.loadModel(modelDef: modelDef);
      debugPrint('ModelDownloadService: loaded $modelId into engine');
      return true;
    } catch (e) {
      debugPrint('ModelDownloadService: failed to load $modelId into engine: $e');
      return false;
    }
  }

  /// Ensure a model is both downloaded and loaded into the engine.
  /// Convenience method for the inference pipeline.
  Future<ModelDownloadResult> ensureModelAvailable(
    String modelId, {
    ModelDownloadProgressCallback? onProgress,
  }) async {
    return downloadModel(
      ModelDownloadRequest(
        modelId: modelId,
        autoLoadIntoEngine: true,
      ),
      onProgress: onProgress,
    );
  }

  // ====================================================
  // Disk I/O
  // ====================================================

  /// Resolve the local directory for storing model files.
  /// Uses the application support directory (persisted across app launches).
  Future<Directory> _getModelsDirectory() async {
    final baseDir = await getApplicationSupportDirectory();
    final modelsDir = Directory(p.join(
      baseDir.path,
      AppConstants.projectsFolder,
      'ai_models',
    ));

    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  /// Write model bytes to disk and return the full path
  Future<String> _writeModelFile(String fileName, Uint8List bytes) async {
    if (_modelsDirectory == null) {
      throw Exception('Models directory not initialized');
    }

    final filePath = p.join(_modelsDirectory!.path, fileName);
    final file = File(filePath);

    // Write atomically: write to temp file first, then rename
    final tempPath = '$filePath.tmp';
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(bytes, flush: true);

    // If target exists, delete it first
    if (await file.exists()) {
      await file.delete();
    }

    await tempFile.rename(filePath);
    return filePath;
  }

  /// Load the cache manifest from disk
  Future<CacheManifest> _loadManifest() async {
    if (_modelsDirectory == null) return CacheManifest();

    final manifestPath = p.join(_modelsDirectory!.path, 'cache_manifest.json');
    final file = File(manifestPath);

    if (!await file.exists()) return CacheManifest();

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return CacheManifest.fromJson(json);
    } catch (e) {
      debugPrint('ModelDownloadService: corrupt manifest, starting fresh: $e');
      return CacheManifest();
    }
  }

  /// Persist the cache manifest to disk
  Future<void> _persistManifest() async {
    if (_modelsDirectory == null) return;

    final manifestPath = p.join(_modelsDirectory!.path, 'cache_manifest.json');
    final file = File(manifestPath);

    try {
      final content = const JsonEncoder.withIndent('  ').convert(_manifest.toJson());
      await file.writeAsString(content, flush: true);
    } catch (e) {
      debugPrint('ModelDownloadService: failed to persist manifest: $e');
    }
  }

  // ====================================================
  // URL Resolution
  // ====================================================

  /// Resolve the download URL for a model.
  /// In production, this would query a CDN manifest or API endpoint.
  /// No actual URLs are hardcoded — this is the integration point
  /// for the remote model distribution infrastructure.
  String _resolveDownloadUrl(ModelMetadata metadata) {
    // Architecture placeholder: the production URL would come from
    // a remote model manifest API (e.g., GET /v1/models/{id}/download)
    // or a CDN with versioned paths.
    //
    // Example production pattern:
    //   ${AppConstants.apiBaseUrl}/models/${metadata.id}/${metadata.version}/download
    //
    // For now, return a sentinel that will produce a clear error
    // if a download is attempted before URL configuration.
    return 'about:blank#model-download-not-configured/${metadata.id}';
  }

  // ====================================================
  // Diagnostics
  // ====================================================

  /// Get a summary of the service state
  Map<String, dynamic> get status {
    return {
      'is_initialized': _isInitialized,
      'cached_models': _manifest.entries.keys.toList(),
      'active_downloads': _activeDownloads.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList(),
      'models_directory': _modelsDirectory?.path,
    };
  }
}
