import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../shared/constants/app_constants.dart';

class ProxyCacheService {
  const ProxyCacheService();

  Future<Directory> getProxyDirectory(String projectId) async {
    final baseDirectory = await getTemporaryDirectory();
    final proxyDirectory = Directory(
      p.join(
        baseDirectory.path,
        AppConstants.projectsFolder,
        projectId,
        AppConstants.proxiesFolder,
      ),
    );
    if (!await proxyDirectory.exists()) {
      await proxyDirectory.create(recursive: true);
    }
    return proxyDirectory;
  }

  Future<String> resolveProxyPath(String projectId, String clipId) async {
    final proxyDirectory = await getProxyDirectory(projectId);
    return p.join(
      proxyDirectory.path,
      '${clipId}_${AppConstants.proxyResolution}.mp4',
    );
  }

  Future<bool> proxyExists(String proxyPath) async {
    return File(proxyPath).exists();
  }

  Future<void> deleteProxy(String proxyPath) async {
    final file = File(proxyPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<List<String>> listProjectProxies(String projectId) async {
    final directory = await getProxyDirectory(projectId);
    if (!await directory.exists()) {
      return const [];
    }
    return directory
        .list(recursive: false)
        .where((entity) => entity is File)
        .map((entity) => entity.path)
        .toList();
  }

  Future<void> clearProjectProxyCache(String projectId) async {
    final directory = await getProxyDirectory(projectId);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> refreshProjectProxyCache(
    String projectId,
    List<String> activeClipIds,
  ) async {
    final directory = await getProxyDirectory(projectId);
    if (!await directory.exists()) {
      return;
    }

    final activePaths = activeClipIds
        .map((clipId) => p.join(
              directory.path,
              '${clipId}_${AppConstants.proxyResolution}.mp4',
            ))
        .toSet();

    await for (final entity in directory.list(recursive: false)) {
      if (entity is File && !activePaths.contains(entity.path)) {
        await entity.delete();
      }
    }
  }
}
