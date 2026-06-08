// lib/features/editor/presentation/widgets/preview/preview_player_widget.dart
// منطقة عرض الفيديو مع أزرار التحكم
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import '../../cubit/editor_cubit.dart';
import '../../../../../core/models/timeline_models.dart';
import '../../../../../shared/theme/app_colors.dart';
class PreviewPlayerWidget extends StatefulWidget {
  final TimelineState timelineState;
  final double currentPosition;
  final bool isPlaying;
  const PreviewPlayerWidget({
    super.key,
    required this.timelineState,
    required this.currentPosition,
    required this.isPlaying,
  });
  @override
  State<PreviewPlayerWidget> createState() => _PreviewPlayerWidgetState();
}
class _PreviewPlayerWidgetState extends State<PreviewPlayerWidget> {
  VideoPlayerController? _videoController;
  bool _isControlsVisible = true;
  // مؤقت لإخفاء أدوات التحكم تلقائياً
  Future<void> _hideControlsAfterDelay() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted && widget.isPlaying) {
      setState(() => _isControlsVisible = false);
    }
  }
  @override
  void didUpdateWidget(PreviewPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // إذا تغيرت حالة التشغيل
    if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        _videoController?.play();
        _hideControlsAfterDelay();
      } else {
        _videoController?.pause();
        setState(() => _isControlsVisible = true);
      }
    }
  }
  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _isControlsVisible = !_isControlsVisible);
        if (_isControlsVisible && widget.isPlaying) {
          _hideControlsAfterDelay();
        }
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ====== عرض الفيديو ======
            _buildVideoDisplay(),
            // ====== تدرج الإضاءة السفلي ======
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: AppColors.previewOverlayGradient,
                ),
              ),
            ),
            // ====== أدوات التحكم ======
            AnimatedOpacity(
              opacity: _isControlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: _buildControls(context),
            ),
            // ====== مؤشر الوقت الحالي ======
            Positioned(
              bottom: 12,
              left: 16,
              child: _buildTimeDisplay(),
            ),
            // ====== أزرار إضافية يمين ======
            Positioned(
              bottom: 8,
              right: 12,
              child: _buildRightActions(context),
            ),
          ],
        ),
      ),
    );
  }
  // عرض الفيديو أو شاشة الانتظار
  Widget _buildVideoDisplay() {
    if (widget.timelineState.videoClips.isEmpty) {
      // شاشة انتظار عند عدم وجود مقاطع
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: 16),
            Text(
              'اضغط على + لإضافة مقطع',
              style: TextStyle(
                color: AppColors.textDisabled,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    // عرض الفيديو المحدد حالياً
    if (_videoController != null && _videoController!.value.isInitialized) {
      return Center(
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
      );
    }
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.accentPrimary,
        strokeWidth: 2,
      ),
    );
  }
  // بناء أدوات التحكم في التشغيل
  Widget _buildControls(BuildContext context) {
    return Positioned.fill(
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // زر الرجوع 5 ثواني
            _buildControlButton(
              icon: Icons.replay_5_rounded,
              size: 36,
              onTap: () {
                final newPos = (widget.currentPosition - 5).clamp(
                    0.0, widget.timelineState.totalDuration);
                context.read<EditorCubit>().seekTo(newPos);
              },
            ),
            const SizedBox(width: 24),
            // زر التشغيل/الإيقاف الرئيسي
            GestureDetector(
              onTap: () => context.read<EditorCubit>().togglePlayPause(),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  widget.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(width: 24),
            // زر التقدم 5 ثواني
            _buildControlButton(
              icon: Icons.forward_5_rounded,
              size: 36,
              onTap: () {
                final newPos = (widget.currentPosition + 5).clamp(
                    0.0, widget.timelineState.totalDuration);
                context.read<EditorCubit>().seekTo(newPos);
              },
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildControlButton({
    required IconData icon,
    required double size,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.6),
      ),
    );
  }
  // عرض الوقت الحالي
  Widget _buildTimeDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${_formatTime(widget.currentPosition)} / '
        '${_formatTime(widget.timelineState.totalDuration)}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  // أزرار إضافية على اليمين
  Widget _buildRightActions(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSmallActionButton(
          icon: Icons.fit_screen_rounded,
          tooltip: 'ملء الشاشة',
          onTap: () {},
        ),
        const SizedBox(height: 8),
        _buildSmallActionButton(
          icon: Icons.screenshot_monitor_rounded,
          tooltip: 'لقطة شاشة',
          onTap: () {},
        ),
      ],
    );
  }
  Widget _buildSmallActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
  String _formatTime(double seconds) {
    final int totalSeconds = seconds.toInt();
    final int minutes = totalSeconds ~/ 60;
    final int secs = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }
}
