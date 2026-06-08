// lib/features/editor/presentation/widgets/timeline/timeline_clip_widget.dart
import 'package:flutter/material.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../../../core/models/timeline_models.dart';

class TimelineClipWidget extends StatelessWidget {
  final VideoClip clip;
  final double pixelsPerSecond;
  final double trackHeight;
  final bool isSelected;
  final VoidCallback? onTap;
  final ValueChanged<double> onDragEnd;
  final ValueChanged<double> onTrimLeft;
  final ValueChanged<double> onTrimRight;

  const TimelineClipWidget({
    super.key,
    required this.clip,
    required this.pixelsPerSecond,
    required this.trackHeight,
    required this.isSelected,
    required this.onTap,
    required this.onDragEnd,
    required this.onTrimLeft,
    required this.onTrimRight,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: clip.duration * pixelsPerSecond,
        height: trackHeight,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentPrimary.withOpacity(0.8)
              : AppColors.timelineTrackVideo.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.accentPrimary
                : AppColors.timelineClipBorder,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          clip.originalPath.split('/').last,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            overflow: TextOverflow.ellipsis,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
