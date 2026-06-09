import '../models/timeline_models.dart';

/// The type of layer included in the preview render plan.
enum RenderLayerKind { video, audio, text }

/// Represents a renderable effect payload extracted from timeline metadata.
class RenderEffectMetadata {
  final String id;
  final String type;
  final Map<String, dynamic> parameters;
  final bool isEnabled;

  const RenderEffectMetadata({
    required this.id,
    required this.type,
    required this.parameters,
    required this.isEnabled,
  });

  factory RenderEffectMetadata.fromVideoEffect(VideoEffect effect) {
    return RenderEffectMetadata(
      id: effect.id,
      type: effect.type.name,
      parameters: effect.parameters,
      isEnabled: effect.isEnabled,
    );
  }
}

/// Base render node that contains timing and layer ordering metadata.
abstract class RenderNode {
  final String id;
  final double startTime;
  final double endTime;
  final int trackIndex;
  final double opacity;
  final List<RenderEffectMetadata> effects;

  const RenderNode({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.trackIndex,
    required this.opacity,
    required this.effects,
  });

  bool get isActive => startTime < endTime;
}

/// A video layer node in the preview render plan.
class VideoRenderNode extends RenderNode {
  final String originalPath;
  final String proxyPath;
  final VideoTransform transform;
  final ClipType clipType;

  const VideoRenderNode({
    required String id,
    required double startTime,
    required double endTime,
    required int trackIndex,
    required double opacity,
    required List<RenderEffectMetadata> effects,
    required this.originalPath,
    required this.proxyPath,
    required this.transform,
    required this.clipType,
  }) : super(
          id: id,
          startTime: startTime,
          endTime: endTime,
          trackIndex: trackIndex,
          opacity: opacity,
          effects: effects,
        );
}

/// An audio layer node in the preview render plan.
class AudioRenderNode extends RenderNode {
  final String filePath;
  final double volume;
  final double fadeInDuration;
  final double fadeOutDuration;
  final bool isMuted;
  final AudioType audioType;

  const AudioRenderNode({
    required String id,
    required double startTime,
    required double endTime,
    required int trackIndex,
    required double opacity,
    required List<RenderEffectMetadata> effects,
    required this.filePath,
    required this.volume,
    required this.fadeInDuration,
    required this.fadeOutDuration,
    required this.isMuted,
    required this.audioType,
  }) : super(
          id: id,
          startTime: startTime,
          endTime: endTime,
          trackIndex: trackIndex,
          opacity: opacity,
          effects: effects,
        );
}

/// A text overlay node in the preview render plan.
class TextRenderNode extends RenderNode {
  final String text;
  final TextStyleDto style;
  final VideoTransform transform;
  final bool isSubtitle;

  const TextRenderNode({
    required String id,
    required double startTime,
    required double endTime,
    required int trackIndex,
    required double opacity,
    required List<RenderEffectMetadata> effects,
    required this.text,
    required this.style,
    required this.transform,
    required this.isSubtitle,
  }) : super(
          id: id,
          startTime: startTime,
          endTime: endTime,
          trackIndex: trackIndex,
          opacity: opacity,
          effects: effects,
        );
}

/// The render plan produced from a timeline state for preview playback.
class PreviewRenderPlan {
  final List<VideoRenderNode> videoLayers;
  final List<AudioRenderNode> audioLayers;
  final List<TextRenderNode> textLayers;
  final double totalDuration;

  const PreviewRenderPlan({
    required this.videoLayers,
    required this.audioLayers,
    required this.textLayers,
    required this.totalDuration,
  });
}

/// Builds a preview render graph from a timeline state.
class RenderGraph {
  const RenderGraph();

  PreviewRenderPlan buildPlan(TimelineState timelineState) {
    final videoLayers = timelineState.videoClips
        .where((clip) => clip.clipType == ClipType.video || clip.clipType == ClipType.image)
        .map((clip) => VideoRenderNode(
              id: clip.id,
              startTime: clip.startTime,
              endTime: clip.endTime,
              trackIndex: clip.trackIndex,
              opacity: clip.transform.opacity,
              effects: clip.effects
                  .where((effect) => effect.isEnabled)
                  .map(RenderEffectMetadata.fromVideoEffect)
                  .toList(),
              originalPath: clip.originalPath,
              proxyPath: clip.proxyPath,
              transform: clip.transform,
              clipType: clip.clipType,
            ))
        .toList();

    final audioLayers = timelineState.audioClips
        .map((audio) => AudioRenderNode(
              id: audio.id,
              startTime: audio.startTime,
              endTime: audio.endTime,
              trackIndex: audio.trackIndex,
              opacity: audio.isMuted ? 0.0 : 1.0,
              effects: const [],
              filePath: audio.filePath,
              volume: audio.volume,
              fadeInDuration: audio.fadeInDuration,
              fadeOutDuration: audio.fadeOutDuration,
              isMuted: audio.isMuted,
              audioType: audio.audioType,
            ))
        .toList();

    final textLayers = timelineState.textLayers
        .map((textLayer) => TextRenderNode(
              id: textLayer.id,
              startTime: textLayer.startTime,
              endTime: textLayer.endTime,
              trackIndex: textLayer.transform.y.round(),
              opacity: textLayer.style.color == 0 ? 0.0 : 1.0,
              effects: const [],
              text: textLayer.text,
              style: textLayer.style,
              transform: textLayer.transform,
              isSubtitle: textLayer.isSubtitle,
            ))
        .toList();

    return PreviewRenderPlan(
      videoLayers: _sortVideoLayers(videoLayers),
      audioLayers: audioLayers,
      textLayers: textLayers,
      totalDuration: timelineState.totalDuration,
    );
  }

  List<VideoRenderNode> _sortVideoLayers(List<VideoRenderNode> layers) {
    final sorted = [...layers];
    sorted.sort((a, b) {
      final trackComparison = a.trackIndex.compareTo(b.trackIndex);
      if (trackComparison != 0) return trackComparison;
      return a.startTime.compareTo(b.startTime);
    });
    return sorted;
  }
}
