// lib/features/editor/presentation/screens/editor_screen.dart
// هذه هي الشاشة الرئيسية للمحرر
// تجمع كل المكونات معاً في تخطيط عمودي احترافي
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../cubit/editor_cubit.dart';
import '../widgets/toolbar/top_toolbar_widget.dart';
import '../widgets/preview/preview_player_widget.dart';
import '../widgets/timeline/timeline_widget.dart';
import '../widgets/toolbar/bottom_toolbar_widget.dart';
import '../widgets/panels/ai_commands_panel.dart';
import '../widgets/panels/audio_panel.dart';
import '../widgets/panels/text_panel.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../ai_commands/presentation/cubit/ai_cubit.dart';
class EditorScreen extends StatefulWidget {
  final String projectId;
  const EditorScreen({
    super.key,
    required this.projectId,
  });
  @override
  State<EditorScreen> createState() => _EditorScreenState();
}
class _EditorScreenState extends State<EditorScreen>
    with TickerProviderStateMixin {
  
  // متحكم الرسوم المتحركة للوحات التحكم الجانبية
  late AnimationController _panelAnimationController;
  late Animation<double> _panelSlideAnimation;
  late Animation<double> _panelFadeAnimation;
  @override
  void initState() {
    super.initState();
    
    // إخفاء شريط الحالة للحصول على شاشة كاملة
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    // تهيئة الرسوم المتحركة للوحات
    _panelAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    
    _panelSlideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _panelAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    _panelFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _panelAnimationController,
        curve: Curves.easeOut,
      ),
    );
  }
  @override
  void dispose() {
    _panelAnimationController.dispose();
    // إعادة شريط الحالة عند الخروج
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EditorCubit(projectId: widget.projectId),
      child: BlocListener<EditorCubit, EditorState>(
        // نستمع للتغييرات لفتح/إغلاق اللوحات
        listenWhen: (previous, current) =>
            previous.isAIPanelOpen != current.isAIPanelOpen ||
            previous.isAudioPanelOpen != current.isAudioPanelOpen ||
            previous.isTextPanelOpen != current.isTextPanelOpen,
        listener: (context, state) {
          // إذا فُتحت أي لوحة، شغّل الأنيميشن
          if (state.isAIPanelOpen || state.isAudioPanelOpen || state.isTextPanelOpen) {
            _panelAnimationController.forward();
          } else {
            _panelAnimationController.reverse();
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          body: BlocBuilder<EditorCubit, EditorState>(
            builder: (context, state) {
              return Stack(
                children: [
                  // ====== التخطيط الرئيسي (Column) ======
                  Column(
                    children: [
                      // 1. الشريط العلوي
                      const TopToolbarWidget(),
                      
                      // 2. منطقة عرض الفيديو
                      Expanded(
                        flex: 5,
                        child: PreviewPlayerWidget(
                          timelineState: state.timelineState,
                          currentPosition: state.currentPlayheadPosition,
                          isPlaying: state.isPlaying,
                        ),
                      ),
                      
                      // 3. التايم لاين
                      Expanded(
                        flex: 4,
                        child: TimelineWidget(
                          timelineState: state.timelineState,
                          currentPosition: state.currentPlayheadPosition,
                          zoom: state.timelineZoom,
                          selectedClipId: state.selectedClipId,
                        ),
                      ),
                      
                      // 4. شريط الأدوات السفلي
                      const BottomToolbarWidget(),
                    ],
                  ),
                  
                  // ====== طبقة اللوحات المنزلقة من الأسفل ======
                  // تُعرض فوق التخطيط الرئيسي عند الحاجة
                  if (state.isAIPanelOpen || state.isAudioPanelOpen || state.isTextPanelOpen)
                    _buildOverlayPanel(state),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
  // بناء اللوحة المنزلقة من الأسفل
  Widget _buildOverlayPanel(EditorState state) {
    return AnimatedBuilder(
      animation: _panelAnimationController,
      builder: (context, child) {
        return Stack(
          children: [
            // طبقة تعتيم الخلفية (Backdrop)
            GestureDetector(
              onTap: () {
                context.read<EditorCubit>().setActiveTool(EditorTool.select);
              },
              child: Container(
                color: Colors.black.withOpacity(0.6 * _panelFadeAnimation.value),
              ),
            ),
            
            // اللوحة نفسها تنزلق من الأسفل
            Align(
              alignment: Alignment.bottomCenter,
              child: Transform.translate(
                offset: Offset(
                  0,
                  MediaQuery.of(context).size.height *
                      0.6 *
                      _panelSlideAnimation.value,
                ),
                child: Opacity(
                  opacity: _panelFadeAnimation.value,
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
      child: _buildActivePanel(state),
    );
  }
  // تحديد اللوحة التي تُعرض
  Widget _buildActivePanel(EditorState state) {
    if (state.isAIPanelOpen) {
      return BlocProvider<AICubit>(
        create: (_) => GetIt.instance.get<AICubit>(),
        child: const AiCommandsPanel(),
      );
    } else if (state.isAudioPanelOpen) {
      return const AudioPanel();
    } else if (state.isTextPanelOpen) {
      return const TextPanel();
    }
    return const SizedBox.shrink();
  }
}
