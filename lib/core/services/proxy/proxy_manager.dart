import '../../../core/models/timeline_models.dart';
import 'proxy_cache_service.dart';
import 'proxy_generator_service.dart';

class ProxyManager {
  final ProxyGeneratorService _generatorService;
  final ProxyCacheService _cacheService;
  final Map<String, ProxyGenerationTask> _activeTasks = {};

  ProxyManager({
    ProxyGeneratorService? generatorService,
    ProxyCacheService? cacheService,
  })  : _generatorService = generatorService ?? const ProxyGeneratorService(),
        _cacheService = cacheService ?? const ProxyCacheService();

  Future<VideoClip> generateProxyForClip({
    required String projectId,
    required VideoClip clip,
  }) async {
    final proxyPath = await _cacheService.resolveProxyPath(projectId, clip.id);
    if (await _cacheService.proxyExists(proxyPath)) {
      return clip.copyWith(proxyPath: proxyPath);
    }

    final task = await _startProxyGeneration(projectId: projectId, clip: clip);
    final resolvedPath = await task.future;
    return clip.copyWith(proxyPath: resolvedPath);
  }

  Future<ProxyGenerationTask> _startProxyGeneration({
    required String projectId,
    required VideoClip clip,
  }) async {
    final existingTask = _activeTasks[clip.id];
    if (existingTask != null) {
      return existingTask;
    }

    final proxyPath = await _cacheService.resolveProxyPath(projectId, clip.id);
    final task = _generatorService.createProxyTask(
      originalPath: clip.originalPath,
      proxyPath: proxyPath,
      clipId: clip.id,
    );

    _activeTasks[clip.id] = task;
    task.future.whenComplete(() => _activeTasks.remove(clip.id));
    return task;
  }

  Future<bool> cancelProxyGeneration(String clipId) async {
    final task = _activeTasks[clipId];
    if (task == null) {
      return false;
    }

    await task.cancel();
    _activeTasks.remove(clipId);
    return true;
  }

  Future<String> resolveProxyPath(String projectId, String clipId) {
    return _cacheService.resolveProxyPath(projectId, clipId);
  }

  Future<void> deleteProjectProxyCache(String projectId) {
    return _cacheService.clearProjectProxyCache(projectId);
  }

  Future<void> refreshProjectProxyCache(
    String projectId,
    List<VideoClip> activeClips,
  ) {
    final clipIds = activeClips.map((clip) => clip.id).toList();
    return _cacheService.refreshProjectProxyCache(projectId, clipIds);
  }

  bool isGenerating(String clipId) {
    return _activeTasks.containsKey(clipId);
  }
}
