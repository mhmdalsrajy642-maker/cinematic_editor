// lib/features/editor/presentation/widgets/timeline/timeline_ruler_widget.dart
import 'package:flutter/material.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../../../shared/constants/app_constants.dart';

class TimelineRulerWidget extends StatelessWidget {
  final double totalDuration;
  final double pixelsPerSecond;
  final double currentPosition;

  const TimelineRulerWidget({
    super.key,
    required this.totalDuration,
    required this.pixelsPerSecond,
    required this.currentPosition,
  });

  @override
  Widget build(BuildContext context) {
    final ticks = (totalDuration / 5).ceil();
    return Container(
      height: AppConstants.timelineHeaderHeight,
      color: AppColors.backgroundSecondary,
      child: Stack(
        children: [
          Positioned.fill(
            child: Row(
              children: List.generate(ticks, (index) {
                return Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: AppColors.backgroundElevated,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4, top: 4),
                        child: Text(
                          '${index * 5}s',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Positioned(
            left: (currentPosition * pixelsPerSecond).clamp(0.0, double.infinity),
            top: 0,
            bottom: 0,
            child: Container(
              width: 2,
              color: AppColors.timelinePlayhead,
            ),
          ),
        ],
      ),
    );
  }
}
