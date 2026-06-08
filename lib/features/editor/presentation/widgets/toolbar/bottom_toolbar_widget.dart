// lib/features/editor/presentation/widgets/toolbar/bottom_toolbar_widget.dart
// شريط الأدوات السفلي: زر AI المتوهج في المنتصف + الأدوات الأخرى
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../cubit/editor_cubit.dart';
import '../../../../../shared/theme/app_colors.dart';
class BottomToolbarWidget extends StatefulWidget {
  const BottomToolbarWidget({super.key});
  @override
  State<BottomToolbarWidget> createState() => _BottomToolbarWidgetState();
}
class _BottomToolbarWidgetState extends State<BottomToolbarWidget>
    with SingleTickerProviderStateMixin {
  // متحكم الرسوم المتحركة لتوهج زر الذكاء الاصطناعي
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  @override
  void initState() {
    super.initState();
    // رسوم متحركة متكررة لتوهج زر الذكاء الاصطناعي
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );
  }
  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditorCubit, EditorState>(
      builder: (context, state) {
        return Container(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 12,
            bottom: 12 + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            gradient: AppColors.toolbarGradient,
            border: const Border(
              top: BorderSide(color: AppColors.backgroundElevated, width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ====== الأداة: القص ======
              _buildToolButton(
                context: context,
                icon: Icons.content_cut_rounded,
                label: 'قص',
                tool: EditorTool.cut,
                activeTool: state.activeTool,
              ),
              // ====== الأداة: الصوت ======
              _buildToolButton(
                context: context,
                icon: Icons.music_note_rounded,
                label: 'صوت',
                tool: EditorTool.audio,
                activeTool: state.activeTool,
              ),
              // ====== زر الذكاء الاصطناعي المتوهج (المنتصف) ======
              _buildAIButton(context, state),
              // ====== الأداة: النصوص ======
              _buildToolButton(
                context: context,
                icon: Icons.text_fields_rounded,
                label: 'نصوص',
                tool: EditorTool.text,
                activeTool: state.activeTool,
              ),
              // ====== الأداة: القوالب ======
              _buildToolButton(
                context: context,
                icon: Icons.auto_awesome_mosaic_outlined,
                label: 'قوالب',
                tool: EditorTool.templates,
                activeTool: state.activeTool,
              ),
            ],
          ),
        );
      },
    );
  }
  // بناء زر أداة عادي
  Widget _buildToolButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required EditorTool tool,
    required EditorTool activeTool,
  }) {
    final isActive = activeTool == tool;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact(); // اهتزاز خفيف عند الضغط
        context.read<EditorCubit>().setActiveTool(
          isActive ? EditorTool.select : tool,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.accentPrimary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                color: isActive ? AppColors.accentPrimary : AppColors.textTertiary,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isActive ? AppColors.accentPrimary : AppColors.textTertiary,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
  // بناء زر الذكاء الاصطناعي المتوهج
  Widget _buildAIButton(BuildContext context, EditorState state) {
    final isActive = state.activeTool == EditorTool.aiCommands;
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        context.read<EditorCubit>().setActiveTool(
          isActive ? EditorTool.select : EditorTool.aiCommands,
        );
      },
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF9D4EDD),
                  Color(0xFF6C63FF),
                  Color(0xFF00D4FF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9D4EDD)
                      .withOpacity(0.5 * _glowAnimation.value),
                  blurRadius: 20 * _glowAnimation.value,
                  spreadRadius: 2 * _glowAnimation.value,
                ),
                BoxShadow(
                  color: const Color(0xFF6C63FF)
                      .withOpacity(0.3 * _glowAnimation.value),
                  blurRadius: 40 * _glowAnimation.value,
                  spreadRadius: 4 * _glowAnimation.value,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // حلقة خارجية نابضة
            if (!isActive)
              Animate(
                effects: const [
                  ScaleEffect(
                    begin: Offset(0.9, 0.9),
                    end: Offset(1.1, 1.1),
                    duration: Duration(milliseconds: 2000),
                    curve: Curves.easeInOut,
                  ),
                  FadeEffect(
                    begin: 0.5,
                    end: 0.0,
                    duration: Duration(milliseconds: 2000),
                  ),
                ],
                onPlay: (controller) => controller.repeat(),
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accentAI.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                ),
              ),
            // أيقونة الميكروفون أو AI
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? Icons.close_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                if (!isActive)
                  const Text(
                    'AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
