// lib/features/editor/presentation/widgets/timeline/timeline_playhead_widget.dart
import 'package:flutter/material.dart';
import '../../../../../shared/theme/app_colors.dart';

class TimelinePlayheadWidget extends StatelessWidget {
  final double position;
  final double trackHeight;

  const TimelinePlayheadWidget({
    super.key,
    required this.position,
    required this.trackHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position,
      top: 0,
      child: Container(
        width: 2,
        height: trackHeight,
        color: AppColors.timelinePlayhead,
      ),
    );
  }
}
