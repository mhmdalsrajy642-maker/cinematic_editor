import '../models/timeline_models.dart';
import 'frame_compositor.dart';
import 'render_graph.dart';
import 'render_scheduler.dart';

/// Coordinates preview frame rendering separately from export rendering.
class PreviewRenderer {
  final FrameCompositor compositor;
  final RenderScheduler scheduler;
  final RenderGraph renderGraph;

  PreviewRenderer({
    required this.compositor,
    required this.scheduler,
    RenderGraph? renderGraph,
  }) : renderGraph = renderGraph ?? const RenderGraph();

  Future<RenderFrame> renderPreviewFrame(
    TimelineState timelineState,
    double timestamp,
    int width,
    int height,
  ) {
    final plan = renderGraph.buildPlan(timelineState);
    return scheduler.scheduleRender(() {
      return compositor.composeFrame(plan, timestamp, width, height);
    });
  }

  Future<void> dispose() async {
    await scheduler.cancelAll();
  }
}
