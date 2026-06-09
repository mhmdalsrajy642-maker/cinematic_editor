// lib/core/models/timeline_models.dart
// هذا الملف يحدد بنية البيانات الكاملة للتايم لاين
// كل عملية تعديل في التطبيق تُحوَّل إلى هذه النماذج وتُحفظ كـ JSON
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

// ====================================================
// نموذج مقطع الفيديو (Video Clip)
// يمثل أي مقطع فيديو أو صورة على التايم لاين
// ====================================================
class VideoClip extends Equatable {
  final String id; // معرف فريد لكل مقطع
  final String originalPath; // مسار الملف الأصلي (4K)
  final String proxyPath; // مسار النسخة الخفيفة (360p)
  final double startTime; // وقت البداية على التايم لاين (بالثانية)
  final double endTime; // وقت النهاية على التايم لاين (بالثانية)
  final double clipStartOffset; // نقطة البداية داخل الملف الأصلي
  final double clipEndOffset; // نقطة النهاية داخل الملف الأصلي
  final int trackIndex; // رقم المسار (0 = مسار الفيديو الرئيسي)
  final double volume; // مستوى الصوت (0.0 إلى 1.0)
  final double speed; // سرعة التشغيل (1.0 = عادي، 2.0 = ضعفين)
  final List<VideoEffect> effects; // قائمة التأثيرات المطبقة
  final VideoTransform transform; // تحويلات الحجم والموضع والدوران
  final String? thumbnailPath; // مسار الصورة المصغرة للتايم لاين
  final bool isMuted; // هل الصوت مكتوم؟
  final ClipType clipType; // نوع المقطع (فيديو، صورة، لون)
  const VideoClip({
    required this.id,
    required this.originalPath,
    required this.proxyPath,
    required this.startTime,
    required this.endTime,
    required this.clipStartOffset,
    required this.clipEndOffset,
    required this.trackIndex,
    this.volume = 1.0,
    this.speed = 1.0,
    this.effects = const [],
    required this.transform,
    this.thumbnailPath,
    this.isMuted = false,
    this.clipType = ClipType.video,
  });
  // دالة المصنع لإنشاء مقطع جديد بقيم افتراضية
  factory VideoClip.create({
    required String originalPath,
    required String proxyPath,
    required double startTime,
    required double duration,
    int trackIndex = 0,
  }) {
    return VideoClip(
      id: const Uuid().v4(),
      originalPath: originalPath,
      proxyPath: proxyPath,
      startTime: startTime,
      endTime: startTime + duration,
      clipStartOffset: 0.0,
      clipEndOffset: duration,
      trackIndex: trackIndex,
      transform: VideoTransform.identity(),
    );
  }
  // مدة المقطع على التايم لاين
  double get duration => endTime - startTime;
  // مدة محتوى المقطع من الملف الأصلي
  double get contentDuration => clipEndOffset - clipStartOffset;
  // نسخ المقطع مع تعديلات
  VideoClip copyWith({
    String? id,
    String? originalPath,
    String? proxyPath,
    double? startTime,
    double? endTime,
    double? clipStartOffset,
    double? clipEndOffset,
    int? trackIndex,
    double? volume,
    double? speed,
    List<VideoEffect>? effects,
    VideoTransform? transform,
    String? thumbnailPath,
    bool? isMuted,
    ClipType? clipType,
  }) {
    return VideoClip(
      id: id ?? this.id,
      originalPath: originalPath ?? this.originalPath,
      proxyPath: proxyPath ?? this.proxyPath,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      clipStartOffset: clipStartOffset ?? this.clipStartOffset,
      clipEndOffset: clipEndOffset ?? this.clipEndOffset,
      trackIndex: trackIndex ?? this.trackIndex,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      effects: effects ?? this.effects,
      transform: transform ?? this.transform,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      isMuted: isMuted ?? this.isMuted,
      clipType: clipType ?? this.clipType,
    );
  }

  // تحويل إلى JSON للحفظ
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalPath': originalPath,
      'proxyPath': proxyPath,
      'startTime': startTime,
      'endTime': endTime,
      'clipStartOffset': clipStartOffset,
      'clipEndOffset': clipEndOffset,
      'trackIndex': trackIndex,
      'volume': volume,
      'speed': speed,
      'effects': effects.map((e) => e.toJson()).toList(),
      'transform': transform.toJson(),
      'thumbnailPath': thumbnailPath,
      'isMuted': isMuted,
      'clipType': clipType.name,
    };
  }

  // إنشاء من JSON
  factory VideoClip.fromJson(Map<String, dynamic> json) {
    return VideoClip(
      id: json['id'] as String,
      originalPath: json['originalPath'] as String,
      proxyPath: json['proxyPath'] as String,
      startTime: (json['startTime'] as num).toDouble(),
      endTime: (json['endTime'] as num).toDouble(),
      clipStartOffset: (json['clipStartOffset'] as num).toDouble(),
      clipEndOffset: (json['clipEndOffset'] as num).toDouble(),
      trackIndex: json['trackIndex'] as int,
      volume: (json['volume'] as num).toDouble(),
      speed: (json['speed'] as num).toDouble(),
      effects: (json['effects'] as List)
          .map((e) => VideoEffect.fromJson(e as Map<String, dynamic>))
          .toList(),
      transform:
          VideoTransform.fromJson(json['transform'] as Map<String, dynamic>),
      thumbnailPath: json['thumbnailPath'] as String?,
      isMuted: json['isMuted'] as bool,
      clipType: ClipType.values.byName(json['clipType'] as String),
    );
  }
  @override
  List<Object?> get props => [
        id,
        originalPath,
        proxyPath,
        startTime,
        endTime,
        clipStartOffset,
        clipEndOffset,
        trackIndex,
        volume,
        speed,
        effects,
        transform,
        thumbnailPath,
        isMuted,
        clipType,
      ];
}

// ====================================================
// نوع المقطع
// ====================================================
enum ClipType { video, image, solidColor }

// ====================================================
// نموذج تحويلات الفيديو (الحجم، الموضع، الدوران)
// ====================================================
class VideoTransform extends Equatable {
  final double x; // الموضع الأفقي
  final double y; // الموضع الرأسي
  final double scaleX; // الحجم الأفقي
  final double scaleY; // الحجم الرأسي
  final double rotation; // الدوران بالدرجات
  final double opacity; // الشفافية (0.0 إلى 1.0)
  const VideoTransform({
    required this.x,
    required this.y,
    required this.scaleX,
    required this.scaleY,
    required this.rotation,
    required this.opacity,
  });
  // قيم محايدة (لا تغيير)
  factory VideoTransform.identity() {
    return const VideoTransform(
      x: 0.0,
      y: 0.0,
      scaleX: 1.0,
      scaleY: 1.0,
      rotation: 0.0,
      opacity: 1.0,
    );
  }
  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'scaleX': scaleX,
        'scaleY': scaleY,
        'rotation': rotation,
        'opacity': opacity,
      };
  factory VideoTransform.fromJson(Map<String, dynamic> json) {
    return VideoTransform(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      scaleX: (json['scaleX'] as num).toDouble(),
      scaleY: (json['scaleY'] as num).toDouble(),
      rotation: (json['rotation'] as num).toDouble(),
      opacity: (json['opacity'] as num).toDouble(),
    );
  }
  VideoTransform copyWith({
    double? x,
    double? y,
    double? scaleX,
    double? scaleY,
    double? rotation,
    double? opacity,
  }) {
    return VideoTransform(
      x: x ?? this.x,
      y: y ?? this.y,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
    );
  }

  @override
  List<Object?> get props => [x, y, scaleX, scaleY, rotation, opacity];
}

// ====================================================
// نموذج التأثيرات (Effects)
// ====================================================
class VideoEffect extends Equatable {
  final String id;
  final EffectType type;
  final Map<String, dynamic> parameters; // معاملات التأثير (مرونة كاملة)
  final bool isEnabled;
  const VideoEffect({
    required this.id,
    required this.type,
    required this.parameters,
    this.isEnabled = true,
  });
  factory VideoEffect.create({
    required EffectType type,
    Map<String, dynamic> parameters = const {},
  }) {
    return VideoEffect(
      id: const Uuid().v4(),
      type: type,
      parameters: parameters,
    );
  }
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'parameters': parameters,
        'isEnabled': isEnabled,
      };
  factory VideoEffect.fromJson(Map<String, dynamic> json) {
    return VideoEffect(
      id: json['id'] as String,
      type: EffectType.values.byName(json['type'] as String),
      parameters: Map<String, dynamic>.from(json['parameters'] as Map),
      isEnabled: json['isEnabled'] as bool,
    );
  }
  VideoEffect copyWith({
    String? id,
    EffectType? type,
    Map<String, dynamic>? parameters,
    bool? isEnabled,
  }) {
    return VideoEffect(
      id: id ?? this.id,
      type: type ?? this.type,
      parameters: parameters ?? this.parameters,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  @override
  List<Object?> get props => [id, type, parameters, isEnabled];
}

// أنواع التأثيرات المتاحة
enum EffectType {
  colorGrade, // تصحيح الألوان
  blur, // ضبابية
  sharpen, // حدة
  brightness, // سطوع
  contrast, // تباين
  saturation, // تشبع
  temperature, // درجة الحرارة اللونية
  vignette, // تعتيم الحواف
  filmGrain, // حبيبات الفيلم
  glitch, // تأثير التشويش
  chromaKey, // إزالة الخلفية بالكروما
  backgroundRemoval, // إزالة الخلفية بالذكاء الاصطناعي
  motionTracking, // تتبع الحركة
  stabilization, // تثبيت الصورة
  speedRamp, // تغيير سرعة ديناميكي
  lumaKey, // مفتاح السطوع
}

// ====================================================
// نموذج مقطع الصوت (Audio Clip)
// ====================================================
class AudioClip extends Equatable {
  final String id;
  final String filePath;
  final double startTime; // وقت البداية على التايم لاين
  final double endTime; // وقت النهاية على التايم لاين
  final double audioOffset; // نقطة البداية داخل الملف الصوتي
  final double volume; // مستوى الصوت
  final double fadeInDuration; // مدة الـ Fade In
  final double fadeOutDuration; // مدة الـ Fade Out
  final int trackIndex; // رقم مسار الصوت
  final bool isMuted;
  final AudioType audioType; // نوع الصوت
  const AudioClip({
    required this.id,
    required this.filePath,
    required this.startTime,
    required this.endTime,
    required this.audioOffset,
    this.volume = 1.0,
    this.fadeInDuration = 0.0,
    this.fadeOutDuration = 0.0,
    required this.trackIndex,
    this.isMuted = false,
    this.audioType = AudioType.music,
  });
  factory AudioClip.create({
    required String filePath,
    required double startTime,
    required double duration,
    int trackIndex = 1,
    AudioType audioType = AudioType.music,
  }) {
    return AudioClip(
      id: const Uuid().v4(),
      filePath: filePath,
      startTime: startTime,
      endTime: startTime + duration,
      audioOffset: 0.0,
      trackIndex: trackIndex,
      audioType: audioType,
    );
  }
  double get duration => endTime - startTime;
  Map<String, dynamic> toJson() => {
        'id': id,
        'filePath': filePath,
        'startTime': startTime,
        'endTime': endTime,
        'audioOffset': audioOffset,
        'volume': volume,
        'fadeInDuration': fadeInDuration,
        'fadeOutDuration': fadeOutDuration,
        'trackIndex': trackIndex,
        'isMuted': isMuted,
        'audioType': audioType.name,
      };
  factory AudioClip.fromJson(Map<String, dynamic> json) {
    return AudioClip(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      startTime: (json['startTime'] as num).toDouble(),
      endTime: (json['endTime'] as num).toDouble(),
      audioOffset: (json['audioOffset'] as num).toDouble(),
      volume: json['volume'] != null ? (json['volume'] as num).toDouble() : 1.0,
      fadeInDuration: json['fadeInDuration'] != null
          ? (json['fadeInDuration'] as num).toDouble()
          : 0.0,
      fadeOutDuration: json['fadeOutDuration'] != null
          ? (json['fadeOutDuration'] as num).toDouble()
          : 0.0,
      trackIndex: json['trackIndex'] as int,
      isMuted: json['isMuted'] as bool? ?? false,
      audioType: json['audioType'] != null
          ? AudioType.values.byName(json['audioType'] as String)
          : AudioType.music,
    );
  }
  AudioClip copyWith({
    String? id,
    String? filePath,
    double? startTime,
    double? endTime,
    double? audioOffset,
    double? volume,
    double? fadeInDuration,
    double? fadeOutDuration,
    int? trackIndex,
    bool? isMuted,
    AudioType? audioType,
  }) {
    return AudioClip(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      audioOffset: audioOffset ?? this.audioOffset,
      volume: volume ?? this.volume,
      fadeInDuration: fadeInDuration ?? this.fadeInDuration,
      fadeOutDuration: fadeOutDuration ?? this.fadeOutDuration,
      trackIndex: trackIndex ?? this.trackIndex,
      isMuted: isMuted ?? this.isMuted,
      audioType: audioType ?? this.audioType,
    );
  }

  @override
  List<Object?> get props => [
        id,
        filePath,
        startTime,
        endTime,
        audioOffset,
        volume,
        fadeInDuration,
        fadeOutDuration,
        trackIndex,
        isMuted,
        audioType,
      ];
}

enum AudioType { music, voiceOver, soundEffect, videoAudio }

// ====================================================
// نموذج تنسيق النص القابل للتسلسل
// هذا النموذج يفصل بيانات النص عن Flutter UI
// ====================================================
class TextStyleDto extends Equatable {
  final int color;
  final double fontSize;
  final int fontWeight;

  const TextStyleDto({
    required this.color,
    required this.fontSize,
    required this.fontWeight,
  });

  factory TextStyleDto.defaultStyle() {
    return const TextStyleDto(
      color: 0xFFFFFFFF,
      fontSize: 24.0,
      fontWeight: 6,
    );
  }

  TextStyleDto copyWith({
    int? color,
    double? fontSize,
    int? fontWeight,
  }) {
    return TextStyleDto(
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
    );
  }

  Map<String, dynamic> toJson() => {
        'color': color,
        'fontSize': fontSize,
        'fontWeight': fontWeight,
      };

  factory TextStyleDto.fromJson(Map<String, dynamic> json) {
    return TextStyleDto(
      color: json['color'] as int,
      fontSize: (json['fontSize'] as num).toDouble(),
      fontWeight: json['fontWeight'] as int,
    );
  }

  @override
  List<Object?> get props => [color, fontSize, fontWeight];
}

// ====================================================
// نموذج طبقة النص (Text Layer)
// ====================================================
class TextLayer extends Equatable {
  final String id;
  final String text;
  final double startTime;
  final double endTime;
  final TextStyleDto style; // تنسيق النص القابل للتسلسل
  final VideoTransform transform; // موضع وحجم النص
  final TextAnimation animation; // حركة دخول وخروج النص
  final bool isSubtitle; // هل هو ترجمة تلقائية؟
  const TextLayer({
    required this.id,
    required this.text,
    required this.startTime,
    required this.endTime,
    required this.style,
    required this.transform,
    required this.animation,
    this.isSubtitle = false,
  });
  factory TextLayer.create({
    required String text,
    required double startTime,
    double duration = 3.0,
  }) {
    return TextLayer(
      id: const Uuid().v4(),
      text: text,
      startTime: startTime,
      endTime: startTime + duration,
      style: TextStyleDto.defaultStyle(),
      transform: VideoTransform(
        x: 0,
        y: 0.8,
        scaleX: 1.0,
        scaleY: 1.0,
        rotation: 0.0,
        opacity: 1.0,
      ),
      animation: TextAnimation.fadeIn,
    );
  }
  double get duration => endTime - startTime;
  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'startTime': startTime,
        'endTime': endTime,
        'style': style.toJson(),
        'styleColor': style.color,
        'styleFontSize': style.fontSize,
        'styleFontWeight': style.fontWeight,
        'transform': transform.toJson(),
        'animation': animation.name,
        'isSubtitle': isSubtitle,
      };
  factory TextLayer.fromJson(Map<String, dynamic> json) {
    final styleJson = json['style'] as Map<String, dynamic>?;
    final style = styleJson != null
        ? TextStyleDto.fromJson(styleJson)
        : TextStyleDto(
            color: json['styleColor'] is int
                ? json['styleColor'] as int
                : 0xFFFFFFFF,
            fontSize: json['styleFontSize'] != null
                ? (json['styleFontSize'] as num).toDouble()
                : 24.0,
            fontWeight: json['styleFontWeight'] is int
                ? json['styleFontWeight'] as int
                : 6,
          );
    return TextLayer(
      id: json['id'] as String,
      text: json['text'] as String,
      startTime: (json['startTime'] as num).toDouble(),
      endTime: (json['endTime'] as num).toDouble(),
      style: style,
      transform:
          VideoTransform.fromJson(json['transform'] as Map<String, dynamic>),
      animation: TextAnimation.values.byName(json['animation'] as String),
      isSubtitle: json['isSubtitle'] as bool,
    );
  }
  TextLayer copyWith({
    String? id,
    String? text,
    double? startTime,
    double? endTime,
    TextStyleDto? style,
    VideoTransform? transform,
    TextAnimation? animation,
    bool? isSubtitle,
  }) {
    return TextLayer(
      id: id ?? this.id,
      text: text ?? this.text,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      style: style ?? this.style,
      transform: transform ?? this.transform,
      animation: animation ?? this.animation,
      isSubtitle: isSubtitle ?? this.isSubtitle,
    );
  }

  @override
  List<Object?> get props => [
        id,
        text,
        startTime,
        endTime,
        style,
        transform,
        animation,
        isSubtitle,
      ];
}

enum TextAnimation {
  none,
  fadeIn,
  fadeOut,
  fadeInOut,
  slideIn,
  typewriter,
  pop
}

// ====================================================
// نموذج حالة التايم لاين (Timeline State)
// هذا هو الـ JSON الذي يُحفظ لكل عملية Undo/Redo
// ====================================================
class TimelineState extends Equatable {
  final String projectId;
  final List<VideoClip> videoClips;
  final List<AudioClip> audioClips;
  final List<TextLayer> textLayers;
  final double totalDuration;
  final int videoTrackCount; // عدد مسارات الفيديو
  final int audioTrackCount; // عدد مسارات الصوت
  final ProjectSettings settings;
  const TimelineState({
    required this.projectId,
    required this.videoClips,
    required this.audioClips,
    required this.textLayers,
    required this.totalDuration,
    required this.videoTrackCount,
    required this.audioTrackCount,
    required this.settings,
  });
  factory TimelineState.empty(String projectId) {
    return TimelineState(
      projectId: projectId,
      videoClips: const [],
      audioClips: const [],
      textLayers: const [],
      totalDuration: 0.0,
      videoTrackCount: 2,
      audioTrackCount: 3,
      settings: ProjectSettings.defaultSettings(),
    );
  }
  // حساب المدة الإجمالية تلقائياً من المقاطع
  double get calculatedDuration {
    double maxTime = 0;
    for (final clip in videoClips) {
      if (clip.endTime > maxTime) maxTime = clip.endTime;
    }
    for (final clip in audioClips) {
      if (clip.endTime > maxTime) maxTime = clip.endTime;
    }
    return maxTime;
  }

  Map<String, dynamic> toJson() => {
        'projectId': projectId,
        'videoClips': videoClips.map((c) => c.toJson()).toList(),
        'audioClips': audioClips.map((c) => c.toJson()).toList(),
        'textLayers': textLayers.map((t) => t.toJson()).toList(),
        'totalDuration': totalDuration,
        'videoTrackCount': videoTrackCount,
        'audioTrackCount': audioTrackCount,
        'settings': settings.toJson(),
      };
  factory TimelineState.fromJson(Map<String, dynamic> json) {
    return TimelineState(
      projectId: json['projectId'] as String,
      videoClips: (json['videoClips'] as List? ?? const [])
          .map((c) => VideoClip.fromJson(c as Map<String, dynamic>))
          .toList(),
      audioClips: (json['audioClips'] as List? ?? const [])
          .map((c) => AudioClip.fromJson(c as Map<String, dynamic>))
          .toList(),
      textLayers: (json['textLayers'] as List? ?? const [])
          .map((t) => TextLayer.fromJson(t as Map<String, dynamic>))
          .toList(),
      totalDuration: json['totalDuration'] != null
          ? (json['totalDuration'] as num).toDouble()
          : 0.0,
      videoTrackCount: json['videoTrackCount'] as int? ?? 2,
      audioTrackCount: json['audioTrackCount'] as int? ?? 3,
      settings: json['settings'] != null
          ? ProjectSettings.fromJson(json['settings'] as Map<String, dynamic>)
          : ProjectSettings.defaultSettings(),
    );
  }
  TimelineState copyWith({
    String? projectId,
    List<VideoClip>? videoClips,
    List<AudioClip>? audioClips,
    List<TextLayer>? textLayers,
    double? totalDuration,
    int? videoTrackCount,
    int? audioTrackCount,
    ProjectSettings? settings,
  }) {
    return TimelineState(
      projectId: projectId ?? this.projectId,
      videoClips: videoClips ?? this.videoClips,
      audioClips: audioClips ?? this.audioClips,
      textLayers: textLayers ?? this.textLayers,
      totalDuration: totalDuration ?? this.totalDuration,
      videoTrackCount: videoTrackCount ?? this.videoTrackCount,
      audioTrackCount: audioTrackCount ?? this.audioTrackCount,
      settings: settings ?? this.settings,
    );
  }

  @override
  List<Object?> get props => [
        projectId,
        videoClips,
        audioClips,
        textLayers,
        totalDuration,
        videoTrackCount,
        audioTrackCount,
        settings,
      ];
}

// ====================================================
// إعدادات المشروع
// ====================================================
class ProjectSettings extends Equatable {
  final String resolution; // "4K", "1080p", "720p"
  final double frameRate; // 24, 30, 60
  final String aspectRatio; // "16:9", "9:16", "1:1", "4:3"
  final String colorProfile; // "sRGB", "HDR10", "Rec.2020"
  const ProjectSettings({
    required this.resolution,
    required this.frameRate,
    required this.aspectRatio,
    required this.colorProfile,
  });
  factory ProjectSettings.defaultSettings() {
    return const ProjectSettings(
      resolution: '1080p',
      frameRate: 30.0,
      aspectRatio: '9:16', // الوضع الرأسي للهاتف افتراضياً
      colorProfile: 'sRGB',
    );
  }
  Map<String, dynamic> toJson() => {
        'resolution': resolution,
        'frameRate': frameRate,
        'aspectRatio': aspectRatio,
        'colorProfile': colorProfile,
      };
  factory ProjectSettings.fromJson(Map<String, dynamic> json) {
    return ProjectSettings(
      resolution: json['resolution'] as String,
      frameRate: (json['frameRate'] as num).toDouble(),
      aspectRatio: json['aspectRatio'] as String,
      colorProfile: json['colorProfile'] as String,
    );
  }
  @override
  List<Object?> get props => [resolution, frameRate, aspectRatio, colorProfile];
}
