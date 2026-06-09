import 'dart:typed_data';

import 'render_graph.dart';

/// Represents the composed preview frame returned by the compositor.
class RenderFrame {
  final double timestamp;
  final int width;
  final int height;
  final Uint8List? pixelData;
  final List<CompositedLayer> layers;

  const RenderFrame({
    required this.timestamp,
    required this.width,
    required this.height,
    required this.layers,
    this.pixelData,
  });
}

/// Metadata for a single composited layer within a preview frame.
class CompositedLayer {
  final String id;
  final RenderLayerKind kind;
  final int zIndex;
  final double opacity;
  final Map<String, dynamic> metadata;

  const CompositedLayer({
    required this.id,
    required this.kind,
    required this.zIndex,
    required this.opacity,
    required this.metadata,
  });
}

/// Defines the public frame compositor interface for preview rendering.
abstract class FrameCompositor {
  Future<RenderFrame> composeFrame(
    PreviewRenderPlan plan,
    double timestamp,
    int width,
    int height,
  );
}

/// A placeholder compositor for Dart-only preview simulation.
class DefaultFrameCompositor implements FrameCompositor {
  const DefaultFrameCompositor();

  @override
  Future<RenderFrame> composeFrame(
    PreviewRenderPlan plan,
    double timestamp,
    int width,
    int height,
  ) async {
    final layers = <CompositedLayer>[];

    for (var i = 0; i < plan.videoLayers.length; i++) {
      final node = plan.videoLayers[i];
      if (timestamp < node.startTime || timestamp > node.endTime) continue;
      layers.add(CompositedLayer(
        id: node.id,
        kind: RenderLayerKind.video,
        zIndex: node.trackIndex,
        opacity: node.opacity,
        metadata: {
          'proxyPath': node.proxyPath,
          'originalPath': node.originalPath,
          'transform': node.transform.toJson(),
          'effects': node.effects.map((e) => e.type).toList(),
        },
      ));
    }

    for (var i = 0; i < plan.textLayers.length; i++) {
      final node = plan.textLayers[i];
      if (timestamp < node.startTime || timestamp > node.endTime) continue;
      layers.add(CompositedLayer(
        id: node.id,
        kind: RenderLayerKind.text,
        zIndex: node.trackIndex,
        opacity: node.opacity,
        metadata: {
          'text': node.text,
          'style': node.style.toJson(),
          'transform': node.transform.toJson(),
          'isSubtitle': node.isSubtitle,
        },
      ));
    }

    for (var i = 0; i < plan.audioLayers.length; i++) {
      final node = plan.audioLayers[i];
      if (timestamp < node.startTime || timestamp > node.endTime) continue;
      layers.add(CompositedLayer(
        id: node.id,
        kind: RenderLayerKind.audio,
        zIndex: node.trackIndex,
        opacity: node.opacity,
        metadata: {
          'filePath': node.filePath,
          'volume': node.volume,
          'fadeInDuration': node.fadeInDuration,
          'fadeOutDuration': node.fadeOutDuration,
          'audioType': node.audioType.name,
          'isMuted': node.isMuted,
        },
      ));
    }

    return RenderFrame(
      timestamp: timestamp,
      width: width,
      height: height,
      layers: layers,
      pixelData: null,
    );
  }
}

/// Future native accelerated compositor surface.
abstract class NativeAcceleratedFrameCompositor extends FrameCompositor {}
