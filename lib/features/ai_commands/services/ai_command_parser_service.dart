// lib/features/ai_commands/services/ai_command_parser_service.dart
// هذه الخدمة تأخذ الأمر النصي وتحوله إلى قائمة JSON Actions
// تستخدم API الذكاء الاصطناعي لفهم الأمر المركب
import 'package:dio/dio.dart';
import '../../../core/models/timeline_models.dart';
import '../../../shared/constants/app_constants.dart';
class AiCommandParserService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
  ));
  // ====================================================
  // تحليل الأمر النصي إلى قائمة Actions قابلة للتنفيذ
  // ====================================================
  Future<List<Map<String, dynamic>>> parseCommand({
    required String command,
    required TimelineState timelineState,
  }) async {
    // بناء سياق التايم لاين للإرسال للذكاء الاصطناعي
    final timelineContext = _buildTimelineContext(timelineState);
    try {
      final response = await _dio.post(
        '/ai/parse-command',
        data: {
          'command': command,
          'language': 'ar',           // اللغة العربية
          'timeline_context': timelineContext,
          'available_effects': _getAvailableEffects(),
        },
      );
      final data = response.data as Map<String, dynamic>;
      final actionsList = data['actions'] as List<dynamic>;
      
      return actionsList
          .map((action) => action as Map<String, dynamic>)
          .toList();
    } on DioException catch (_) {
      // إذا فشل الاتصال بالسيرفر، استخدم المعالجة المحلية
      return await _parseCommandLocally(command, timelineState);
    }
  }
  // ====================================================
  // المعالجة المحلية (fallback عند عدم الاتصال)
  // تحلل الأوامر الشائعة بدون إنترنت
  // ====================================================
  Future<List<Map<String, dynamic>>> _parseCommandLocally(
      String command, TimelineState timelineState) async {
    
    final List<Map<String, dynamic>> actions = [];
    final lowerCommand = command.toLowerCase();
    // ====== كشف أوامر تصحيح الألوان ======
    if (lowerCommand.contains('سينمائي') ||
        lowerCommand.contains('ليلي') ||
        lowerCommand.contains('أزرق') ||
        lowerCommand.contains('لون')) {
      actions.add({
        'type': 'apply_color_grade',
        'target': 'all_clips',
        'parameters': _detectColorGradeParameters(lowerCommand),
      });
    }
    // ====== كشف أوامر إزالة الخلفية ======
    if (lowerCommand.contains('أزل الخلفية') ||
        lowerCommand.contains('إزالة الخلفية') ||
        lowerCommand.contains('ازل الخلفية')) {
      actions.add({
        'type': 'remove_background',
        'clipId': _getFirstVideoClipId(timelineState),
        'parameters': {
          'method': 'ai_segmentation',
          'model': 'mediapipe_selfie',
        },
      });
    }
    // ====== كشف أوامر الترجمة التلقائية ======
    if (lowerCommand.contains('ترجمة') ||
        lowerCommand.contains('subtitle') ||
        lowerCommand.contains('caption') ||
        lowerCommand.contains('توليد تسميات') ||
        lowerCommand.contains('ترجمة تلقائية')) {
      actions.add({
        'type': 'generate_captions',
        'target': 'all_clips',
        'parameters': {
          'language': 'auto_detect',
          'model': 'whisper_tiny',
        },
      });
    }
    // ====== كشف أوامر تقليل الضوضاء ======
    if (lowerCommand.contains('ضوضاء') ||
        lowerCommand.contains('noise') ||
        lowerCommand.contains('صوت')) {
      actions.add({
        'type': 'reduce_noise',
        'target': 'all_audio',
        'parameters': {
          'strength': 0.7,
        },
      });
    }
    // ====== كشف أوامر تتبع الحركة ======
    if (lowerCommand.contains('تتبع') ||
        lowerCommand.contains('motion tracking') ||
        lowerCommand.contains('تتبع الحركة')) {
      actions.add({
        'type': 'apply_motion_tracking',
        'clipId': _getFirstVideoClipId(timelineState) ?? '',
        'parameters': {
          'target': 'person',
          'tracking_type': 'face',
        },
      });
    }
    // ====== كشف أوامر إضافة التسميات النصية ======
    if (lowerCommand.contains('أضف نص') ||
        lowerCommand.contains('أضف تعليق') ||
        lowerCommand.contains('نص توضيحي') ||
        lowerCommand.contains('text caption') ||
        lowerCommand.contains('أضف تسمية')) {
      actions.add({
        'type': 'add_text_caption',
        'text': 'Caption',
        'startTime': 0.0,
        'duration': 3.0,
      });
    }
    // ====== كشف أوامر إضافة الموسيقى ======
    if (lowerCommand.contains('موسيقى') ||
        lowerCommand.contains('music') ||
        lowerCommand.contains('مقطوعة')) {
      actions.add({
        'type': 'add_music',
        'parameters': {
          'mood': _detectMusicMood(lowerCommand),
          'volume': 0.4,
          'fade_in': 1.0,
          'fade_out': 2.0,
        },
      });
    }
    // إذا لم يُكتشف أي أمر معروف
    if (actions.isEmpty) {
      throw Exception('لم أفهم هذا الأمر. حاول صياغته بشكل أبسط.');
    }
    return actions;
  }
  // ====================================================
  // كشف معاملات تصحيح الألوان من النص
  // ====================================================
  Map<String, dynamic> _detectColorGradeParameters(String command) {
    // الأنماط الشائعة
    if (command.contains('ليلي') || command.contains('أزرق')) {
      return {
        'temperature': -0.3,      // برودة لونية (أزرق)
        'tint': 0.05,
        'brightness': -0.15,      // تعتيم طفيف
        'contrast': 0.25,         // زيادة التباين
        'saturation': -0.1,       // تقليل التشبع قليلاً
        'shadows': 0.1,           // رفع الظلال
        'highlights': -0.2,       // خفض الإضاءة العالية
        'preset_name': 'night_cinematic',
      };
    } else if (command.contains('دافئ') || command.contains('ذهبي')) {
      return {
        'temperature': 0.3,       // دفء (برتقالي/أصفر)
        'tint': -0.05,
        'brightness': 0.05,
        'contrast': 0.15,
        'saturation': 0.1,
        'shadows': -0.1,
        'highlights': 0.1,
        'preset_name': 'golden_warm',
      };
    } else if (command.contains('أبيض وأسود') || command.contains('بلاك')) {
      return {
        'saturation': -1.0,       // إزالة الألوان كلياً
        'contrast': 0.3,
        'brightness': 0.05,
        'preset_name': 'black_white',
      };
    }
    // افتراضي: تصحيح سينمائي عام
    return {
      'temperature': -0.1,
      'contrast': 0.2,
      'saturation': -0.05,
      'shadows': 0.15,
      'highlights': -0.1,
      'preset_name': 'cinematic_default',
    };
  }
  // كشف مزاج الموسيقى
  String _detectMusicMood(String command) {
    if (command.contains('هادئ') || command.contains('رخيم')) return 'calm';
    if (command.contains('حزين')) return 'sad';
    if (command.contains('حماسي') || command.contains('نشيط')) return 'energetic';
    if (command.contains('رومانسي')) return 'romantic';
    return 'calm';
  }
  // الحصول على أول مقطع فيديو
  String? _getFirstVideoClipId(TimelineState state) {
    if (state.videoClips.isEmpty) return null;
    return state.videoClips.first.id;
  }
  // بناء ملخص التايم لاين للإرسال للـ API
  Map<String, dynamic> _buildTimelineContext(TimelineState state) {
    return {
      'total_duration': state.totalDuration,
      'video_clips_count': state.videoClips.length,
      'audio_clips_count': state.audioClips.length,
      'video_clip_ids': state.videoClips.map((c) => c.id).toList(),
      'has_audio': state.audioClips.isNotEmpty,
      'resolution': state.settings.resolution,
    };
  }
  // قائمة التأثيرات المتاحة
  List<String> _getAvailableEffects() {
    return [
      'color_grade', 'background_removal', 'motion_tracking',
      'auto_captions', 'noise_reduction', 'stabilization',
      'speed_ramp', 'blur', 'vignette', 'film_grain',
    ];
  }
}
