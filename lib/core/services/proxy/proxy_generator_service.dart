import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../shared/constants/app_constants.dart';

class ProxyGenerationTask {
  final String taskId;
  final String originalPath;
  final String proxyPath;
  final String clipId;
  final Future<String> future;
  bool _cancelled = false;

  ProxyGenerationTask._({
    required this.taskId,
    required this.originalPath,
    required this.proxyPath,
    required this.clipId,
    required this.future,
  });

  bool get isCancelled => _cancelled;

  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    await FFmpegKit.cancel();
  }

  factory ProxyGenerationTask.create({
    required String originalPath,
    required String proxyPath,
    required String clipId,
    required Future<String> future,
  }) {
    return ProxyGenerationTask._(
      taskId: const Uuid().v4(),
      originalPath: originalPath,
      proxyPath: proxyPath,
      clipId: clipId,
      future: future,
    );
  }
}

class ProxyGeneratorService {
  const ProxyGeneratorService();

  ProxyGenerationTask createProxyTask({
    required String originalPath,
    required String proxyPath,
    required String clipId,
  }) {
    final taskCompleter = Completer<String>();

    final task = ProxyGenerationTask.create(
      originalPath: originalPath,
      proxyPath: proxyPath,
      clipId: clipId,
      future: taskCompleter.future,
    );

    _ensureParentDirectory(proxyPath).then((_) async {
      final proxyFile = File(proxyPath);
      if (await proxyFile.exists()) {
        if (!taskCompleter.isCompleted) {
          taskCompleter.complete(proxyPath);
        }
        return;
      }

      final command = _buildProxyCommand(originalPath, proxyPath);
      try {
        final session = await FFmpegKit.execute(command);
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          if (!taskCompleter.isCompleted) {
            taskCompleter.complete(proxyPath);
          }
        } else {
          if (!taskCompleter.isCompleted) {
            taskCompleter.completeError(
              Exception('Proxy generation failed for $originalPath'),
            );
          }
        }
      } catch (error) {
        if (!taskCompleter.isCompleted) {
          taskCompleter.completeError(error);
        }
      }
    });

    return task;
  }

  Future<void> _ensureParentDirectory(String proxyPath) async {
    final parent = Directory(p.dirname(proxyPath));
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
  }

  String _buildProxyCommand(String originalPath, String proxyPath) {
    final normalizedInput = _escapePath(originalPath);${AppConstants.proxyCRF} -b:v ${AppConstants.proxyBitrate}
    final normalizedOutput = _escapePath(proxyPath);
    return '-y -i $normalizedInput -vf scale=-2:360 -c:v libx264 -crf 28 -b:v 800k -preset veryfast -c:a copy $normalizedOutput';
  }

  String _escapePath(String path) {
    if (path.contains(' ')) {
      return '"$path"';
    }
    return path;
  }
}
