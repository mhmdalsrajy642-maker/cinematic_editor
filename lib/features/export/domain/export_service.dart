import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/models/timeline_models.dart';
import '../../../shared/constants/app_constants.dart';
import '../../subscription/services/device_security_service.dart';
import 'ffmpeg_command_builder.dart';

class ExportResult {
  final bool success;
  final String outputPath;
  final double progress;
  final bool cancelled;
  final String? errorMessage;
  final ExportPermission? permission;

  const ExportResult({
    required this.success,
    required this.outputPath,
    required this.progress,
    this.cancelled = false,
    this.errorMessage,
    this.permission,
  });
}

class ExportService {
  final DeviceSecurityService _securityService;
  final FFmpegCommandBuilder _commandBuilder;
  Completer<ExportResult>? _activeExport;
  bool _cancelled = false;

  ExportService({
    required DeviceSecurityService securityService,
    FFmpegCommandBuilder? commandBuilder,
  })  : _securityService = securityService,
        _commandBuilder = commandBuilder ?? const FFmpegCommandBuilder();

  Future<ExportResult> exportTimeline(
    TimelineState timeline,
    ExportProfile profile, {
    required bool hasSubscription,
    required void Function(double progress) onProgress,
  }) async {
    final permission = await _securityService.checkExportPermission(
      resolution: profile.resolutionName,
      hasSubscription: hasSubscription,
    );
    if (!permission.isAllowed) {
      return ExportResult(
        success: false,
        outputPath: '',
        progress: 0.0,
        errorMessage: permission.denialReason,
        permission: permission,
      );
    }

    final exportDirectory = await _getExportDirectory();
    final outputPath = p.join(
      exportDirectory.path,
      'export_${DateTime.now().millisecondsSinceEpoch}_${profile.resolutionName}.mp4',
    );

    final command = _commandBuilder.buildExportCommand(
      timeline,
      profile,
      outputPath,
    );

    _cancelled = false;
    _activeExport = Completer<ExportResult>();

    await exportDirectory.create(recursive: true);

    try {
      await FFmpegKit.executeAsync(
        command,
        (dynamic session) async {
          if (_cancelled) {
            _completeExport(ExportResult(
              success: false,
              outputPath: outputPath,
              progress: 0.0,
              cancelled: true,
              errorMessage: 'Export cancelled',
              permission: permission,
            ));
            return;
          }

          final returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode)) {
            if (!hasSubscription) {
              await _securityService.incrementExportCount(profile.resolutionName);
            }
            _completeExport(ExportResult(
              success: true,
              outputPath: outputPath,
              progress: 1.0,
              permission: permission,
            ));
          } else {
            await _cleanupFailedExport(outputPath);
            _completeExport(ExportResult(
              success: false,
              outputPath: outputPath,
              progress: 0.0,
              errorMessage: 'FFmpeg export failed with code $returnCode',
              permission: permission,
            ));
          }
        },
        (dynamic log) {},
        (dynamic statistics) {
          if (_activeExport == null || _activeExport!.isCompleted) return;
          final timeMs = _extractStatisticsTime(statistics);
          final durationMs = (timeline.totalDuration * 1000).toInt();
          final progress = durationMs > 0 ? (timeMs / durationMs).clamp(0.0, 1.0) : 0.0;
          onProgress(progress);
        },
      );
    } catch (error) {
      await _cleanupFailedExport(outputPath);
      _completeExport(ExportResult(
        success: false,
        outputPath: outputPath,
        progress: 0.0,
        errorMessage: error.toString(),
        permission: permission,
      ));
    }

    return _activeExport!.future;
  }

  Future<void> cancelExport() async {
    _cancelled = true;
    await FFmpegKit.cancel();
  }

  Future<Directory> _getExportDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final exportDir = Directory(p.join(base.path, AppConstants.exportsFolder));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir;
  }

  int _extractStatisticsTime(dynamic statistics) {
    if (statistics == null) return 0;
    try {
      final time = statistics.getTime();
      if (time is int) return time;
      if (time is double) return time.toInt();
    } catch (_) {
      return 0;
    }
    return 0;
  }

  Future<void> _cleanupFailedExport(String outputPath) async {
    try {
      final file = File(outputPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  void _completeExport(ExportResult result) {
    if (_activeExport == null || _activeExport!.isCompleted) return;
    _activeExport!.complete(result);
  }
}
