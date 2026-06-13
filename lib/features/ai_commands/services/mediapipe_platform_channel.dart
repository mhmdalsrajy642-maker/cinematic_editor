import 'package:flutter/services.dart';

class MediaPipePlatformChannel {
  static const MethodChannel _channel = MethodChannel(
    'com.example.cinematic_editor/mediapipe',
  );

  static Future<Map<String, dynamic>> initializeSegmentation({
    Map<String, dynamic>? options,
  }) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'initializeSegmentation',
      {'options': options},
    );
    return result ?? <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> segmentImage({
    required String imagePath,
    String format = 'rgba',
  }) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'segmentImage',
      {
        'imagePath': imagePath,
        'format': format,
      },
    );
    return result ?? <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> segmentVideo({
    required String videoPath,
    required String outputPath,
  }) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'segmentVideo',
      {
        'videoPath': videoPath,
        'outputPath': outputPath,
      },
    );
    return result ?? <String, dynamic>{};
  }

  static Future<bool> release() async {
    final result = await _channel.invokeMethod<bool>('release');
    return result ?? true;
  }
}
