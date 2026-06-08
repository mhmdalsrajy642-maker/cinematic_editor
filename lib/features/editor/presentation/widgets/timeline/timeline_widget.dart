// lib/features/editor/presentation/widgets/timeline/timeline_widget.dart
// التايم لاين الرئيسي مع مسارات الفيديو والصوت والنص
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubit/editor_cubit.dart';
import '../../../../../core/models/timeline_models.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../../../shared/constants/app_constants.dart';
import 'timeline_ruler_widget.dart';
import 'timeline_track_widget.dart';
import 'timeline_playhead_widget.dart';
import 'timeline_clip_widget.dart';
class TimelineWidget extends StatefulWidget {
  final TimelineState timelineState;
  final double currentPosition;
  final double zoom;
  final String? selectedClipId;
  const TimelineWidget({
    super.key,
    required this.timelineState,
    required this.currentPosition,
    required this.zoom,
    this.selectedClipId,
  });
  @override
  State<TimelineWidget> createState() => _TimelineWidgetState();
}
class _TimelineWidgetState extends State<TimelineWidget> {
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  // حساب عرض البكسل لكل ثانية بناءً على مستوى التكبير
  double get pixelsPerSecond =>
      AppConstants.pixelsPerSecond * widget.zoom;
  // إجمالي عرض التايم لاين
  double get totalWidth =>
      (widget.timelineState.totalDuration + 30) * pixelsPerSecond;
  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.timelineBackground,
      child: Column(
        children: [
          // ====== شريط أدوات التايم لاين ======
          _buildTimelineToolbar(context),
          // ====== منطقة التايم لاين الرئيسية ======
          Expanded(
            child: Row(
              children: [
                // ====== لوحة المسارات (أسماء المسارات على اليسار) ======
                _buildTrackLabelsPanel(),
                // ====== منطقة التمرير الرئيسية ======
                Expanded(
                  child: _buildScrollableTimeline(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // شريط أدوات التايم لاين
  Widget _buildTimelineToolbar(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border(
          bottom: BorderSide(color: AppColors.backgroundElevated, width: 1),
        ),
      ),
      child: Row(
        children: [
          // زر إضافة مقطع
          _buildTimelineToolButton(
            icon: Icons.add_rounded,
            label: 'إضافة',
            onTap: () => _showAddMediaDialog(context),
          ),
          const SizedBox(width: 8),
          // زر القص
          _buildTimelineToolButton(
            icon: Icons.content_cut_rounded,
            label: 'قص',
            onTap: () => _splitAtPlayhead(context),
          ),
          const SizedBox(width: 8),
          // زر الحذف
          _buildTimelineToolButton(
            icon: Icons.delete_outline_rounded,
            label: 'حذف',
            onTap: widget.selectedClipId != null
                ? () => context.read<EditorCubit>()
                    .deleteVideoClip(widget.selectedClipId!)
                : null,
          ),
          const Spacer(),
          // تحكم في التكبير
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  context.read<EditorCubit>().setTimelineZoom(
                      (widget.zoom - 0.25).clamp(
                          AppConstants.minTimelineZoom,
                          AppConstants.maxTimelineZoom));
                },
                child: const Icon(
                  Icons.remove_circle_outline,
                  color: AppColors.textTertiary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${(widget.zoom * 100).toInt()}%',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  context.read<EditorCubit>().setTimelineZoom(
                      (widget.zoom + 0.25).clamp(
                          AppConstants.minTimelineZoom,
                          AppConstants.maxTimelineZoom));
                },
                child: const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.textTertiary,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  // لوحة أسماء المسارات على اليسار
  Widget _buildTrackLabelsPanel() {
    return Container(
      width: 56,
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border(
          right: BorderSide(color: AppColors.backgroundElevated, width: 1),
        ),
      ),
      child: Column(
        children: [
          // مساحة شريط القياس
          const SizedBox(height: AppConstants.timelineHeaderHeight),
          // مسارات الفيديو
          ...List.generate(
            widget.timelineState.videoTrackCount,
            (index) => _buildTrackLabel(
              icon: Icons.videocam_outlined,
              color: AppColors.timelineTrackVideo,
              index: index,
              height: AppConstants.trackHeight,
            ),
          ),
          // مسارات الصوت
          ...List.generate(
            widget.timelineState.audioTrackCount,
            (index) => _buildTrackLabel(
              icon: Icons.music_note_outlined,
              color: AppColors.timelineTrackAudio,
              index: index,
              height: AppConstants.audioTrackHeight,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildTrackLabel({
    required IconData icon,
    required Color color,
    required int index,
    required double height,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.backgroundElevated,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color.withOpacity(0.8)),
          const SizedBox(height: 2),
          Text(
            '${index + 1}',
            style: TextStyle(
              color: color.withOpacity(0.6),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  // منطقة التمرير الرئيسية
  Widget _buildScrollableTimeline() {
    return Listener(
      // دعم Pinch to Zoom على الشاشة
      onPointerSignal: (signal) {
        if (signal is PointerScrollEvent) {
          if (signal.kind == PointerDeviceKind.mouse) {
            // التمرير العادي مع عجلة الماوس
            _horizontalScrollController.animateTo(
              (_horizontalScrollController.offset + signal.scrollDelta.dy * 2)
                  .clamp(0, _horizontalScrollController.position.maxScrollExtent),
              duration: const Duration(milliseconds: 100),
              curve: Curves.linear,
            );
          }
        }
      },
      child: SingleChildScrollView(
        controller: _verticalScrollController,
        child: SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ====== شريط القياس الزمني ======
                  TimelineRulerWidget(
                    totalDuration: widget.timelineState.totalDuration + 30,
                    pixelsPerSecond: pixelsPerSecond,
                    currentPosition: widget.currentPosition,
                  ),
                  // ====== مسارات الفيديو ======
                  ...List.generate(
                    widget.timelineState.videoTrackCount,
                    (trackIndex) => _buildVideoTrack(trackIndex),
                  ),
                  // ====== فاصل بين الفيديو والصوت ======
                  Container(
                    height: 2,
                    color: AppColors.backgroundElevated,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                  ),
                  // ====== مسارات الصوت ======
                  ...List.generate(
                    widget.timelineState.audioTrackCount,
                    (trackIndex) => _buildAudioTrack(trackIndex),
                  ),
                  // ====== مسار النصوص ======
                  _buildTextTrack(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  // بناء مسار فيديو
  Widget _buildVideoTrack(int trackIndex) {
    final clipsOnTrack = widget.timelineState.videoClips
        .where((clip) => clip.trackIndex == trackIndex)
        .toList();
    return GestureDetector(
      onTapDown: (details) {
        // النقر على منطقة فارغة يرفع التحديد
        context.read<EditorCubit>().selectClip(null);
        // تحريك مؤشر التشغيل
        final tappedPosition = details.localPosition.dx / pixelsPerSecond;
        context.read<EditorCubit>().seekTo(tappedPosition);
      },
      child: Stack(
        children: [
          // خلفية المسار
          Container(
            height: AppConstants.trackHeight,
            decoration: BoxDecoration(
              color: AppColors.timelineTrackVideo.withOpacity(0.1),
              border: const Border(
                bottom: BorderSide(
                  color: AppColors.backgroundElevated,
                  width: 0.5,
                ),
              ),
            ),
          ),
          // المقاطع على هذا المسار
          ...clipsOnTrack.map(
            (clip) => Positioned(
              left: clip.startTime * pixelsPerSecond,
              top: 4,
              child: TimelineClipWidget(
                clip: clip,
                pixelsPerSecond: pixelsPerSecond,
                trackHeight: AppConstants.trackHeight - 8,
                isSelected: widget.selectedClipId == clip.id,
                onTap: () =>
                    context.read<EditorCubit>().selectClip(clip.id),
                onDragEnd: (newStartTime) {
                  context.read<EditorCubit>().moveVideoClip(
                    clipId: clip.id,
                    newStartTime: newStartTime,
                    newTrackIndex: trackIndex,
                  );
                },
                onTrimLeft: (newOffset) {
                  context.read<EditorCubit>().trimVideoClip(
                    clipId: clip.id,
                    newStartTime: clip.startTime +
                        (newOffset - clip.clipStartOffset),
                    newClipStartOffset: newOffset,
                  );
                },
                onTrimRight: (newOffset) {
                  context.read<EditorCubit>().trimVideoClip(
                    clipId: clip.id,
                    newEndTime: clip.startTime +
                        (newOffset - clip.clipStartOffset),
                    newClipEndOffset: newOffset,
                  );
                },
              ),
            ),
          ),
          // مؤشر التشغيل (Playhead) - يظهر فوق المسارات
          TimelinePlayheadWidget(
            position: widget.currentPosition * pixelsPerSecond,
            trackHeight: AppConstants.trackHeight,
          ),
        ],
      ),
    );
  }
  // بناء مسار صوت
  Widget _buildAudioTrack(int trackIndex) {
    final clipsOnTrack = widget.timelineState.audioClips
        .where((clip) => clip.trackIndex == (trackIndex + 10))
        .toList();
    return Stack(
      children: [
        Container(
          height: AppConstants.audioTrackHeight,
          decoration: BoxDecoration(
            color: AppColors.timelineTrackAudio.withOpacity(0.08),
            border: const Border(
              bottom: BorderSide(
                color: AppColors.backgroundElevated,
                width: 0.5,
              ),
            ),
          ),
        ),
        ...clipsOnTrack.map(
          (clip) => Positioned(
            left: clip.startTime * pixelsPerSecond,
            top: 4,
            child: _buildAudioClipWidget(clip),
          ),
        ),
      ],
    );
  }
  // بناء مقطع صوتي
  Widget _buildAudioClipWidget(AudioClip clip) {
    final width = clip.duration * pixelsPerSecond;
    return GestureDetector(
      onTap: () {
        // تحديد مقطع الصوت
      },
      child: Container(
        width: width,
        height: AppConstants.audioTrackHeight - 8,
        decoration: BoxDecoration(
          color: AppColors.timelineTrackAudio.withOpacity(0.7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppColors.accentSuccess.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 6),
            const Icon(Icons.music_note, size: 12, color: Colors.white70),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                clip.filePath.split('/').last,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // مسار النصوص
  Widget _buildTextTrack() {
    return Stack(
      children: [
        Container(
          height: AppConstants.audioTrackHeight,
          decoration: BoxDecoration(
            color: AppColors.timelineTrackText.withOpacity(0.08),
            border: const Border(
              bottom: BorderSide(
                color: AppColors.backgroundElevated,
                width: 0.5,
              ),
            ),
          ),
        ),
        ...widget.timelineState.textLayers.map(
          (layer) => Positioned(
            left: layer.startTime * pixelsPerSecond,
            top: 4,
            child: Container(
              width: layer.duration * pixelsPerSecond,
              height: AppConstants.audioTrackHeight - 8,
              decoration: BoxDecoration(
                color: AppColors.timelineTrackText.withOpacity(0.7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.accentWarning.withOpacity(0.5),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Center(
                child: Text(
                  layer.text,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  // تقسيم المقطع عند موضع مؤشر التشغيل
  void _splitAtPlayhead(BuildContext context) {
    if (widget.selectedClipId == null) return;
    final playheadPosition = widget.currentPosition;
    
    final clipIndex = widget.timelineState.videoClips
        .indexWhere((c) => c.id == widget.selectedClipId);
    if (clipIndex == -1) return;
    final clip = widget.timelineState.videoClips[clipIndex];
    
    // تأكد أن مؤشر التشغيل داخل المقطع
    if (playheadPosition <= clip.startTime ||
        playheadPosition >= clip.endTime) return;
    // الوقت النسبي داخل الملف الأصلي
    final relativeTime = playheadPosition - clip.startTime;
    final splitContentTime = clip.clipStartOffset + relativeTime;
    // المقطع الأول (من البداية حتى مؤشر التشغيل)
    final firstClip = clip.copyWith(
      endTime: playheadPosition,
      clipEndOffset: splitContentTime,
    );
    // المقطع الثاني (من مؤشر التشغيل حتى النهاية)
    final secondClip = clip.copyWith(
      id: null, // سيُنشأ ID جديد
      startTime: playheadPosition,
      clipStartOffset: splitContentTime,
    );
    // تطبيق التقسيم على الـ Cubit
    // (سيتم تنفيذ هذا عبر إضافة دالة splitClip في الـ Cubit)
  }
  Widget _buildTimelineToolButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isEnabled ? AppColors.textSecondary : AppColors.textDisabled,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isEnabled ? AppColors.textSecondary : AppColors.textDisabled,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  void _showAddMediaDialog(BuildContext context) {
    // سيفتح اختيار الملفات
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddMediaSheet(
        onVideoAdded: (path) {
          // إضافة المقطع للتايم لاين
          final clip = VideoClip.create(
            originalPath: path,
            proxyPath: path, // سيتم إنشاء الـ Proxy لاحقاً
            startTime: widget.timelineState.totalDuration,
            duration: 10.0,
          );
          context.read<EditorCubit>().addVideoClip(clip);
        },
      ),
    );
  }
}
// ====================================================
// ورقة إضافة الوسائط
// ====================================================
class _AddMediaSheet extends StatelessWidget {
  final Function(String path) onVideoAdded;
  const _AddMediaSheet({required this.onVideoAdded});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textDisabled,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('إضافة وسائط',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMediaOption(
                  context,
                  icon: Icons.video_library_outlined,
                  label: 'فيديو',
                  color: AppColors.timelineTrackVideo,
                  onTap: () {
                    Navigator.pop(context);
                    // فتح مكتبة الفيديو
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMediaOption(
                  context,
                  icon: Icons.image_outlined,
                  label: 'صورة',
                  color: AppColors.accentWarning,
                  onTap: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMediaOption(
                  context,
                  icon: Icons.music_note_outlined,
                  label: 'صوت',
                  color: AppColors.timelineTrackAudio,
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
  Widget _buildMediaOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
