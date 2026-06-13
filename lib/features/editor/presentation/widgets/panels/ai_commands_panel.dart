// lib/features/editor/presentation/widgets/panels/ai_commands_panel.dart
// لوحة إدخال الأوامر النصية والصوتية للذكاء الاصطناعي
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubit/editor_cubit.dart';
import '../../../../../core/models/timeline_models.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../../../features/ai_commands/presentation/cubit/ai_cubit.dart';
class AiCommandsPanel extends StatefulWidget {
  const AiCommandsPanel({super.key});
  @override
  State<AiCommandsPanel> createState() => _AiCommandsPanelState();
}
class _AiCommandsPanelState extends State<AiCommandsPanel> {
  final TextEditingController _commandController = TextEditingController();
  bool _isListening = false;
  List<String> _commandHistory = [];
  // أمثلة على الأوامر للمستخدم
  final List<String> _exampleCommands = [
    'غيّر لون الفيديو إلى سينمائي ليلي أزرق',
    'أضف ترجمة تلقائية للفيديو',
    'أزل الخلفية واستبدلها بشاطئ',
    'قلل الضوضاء وأضف موسيقى هادئة',
    'أضف تتبع حركة على الشخص',
    'اجعل الفيديو بجودة سينمائية 24fps',
  ];
  @override
  void dispose() {
    _commandController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AICubit, AIState>(
      listener: (context, state) {
        if (state is AIError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('خطأ: ${state.errorMessage}'),
                backgroundColor: AppColors.accentDanger,
              ),
            );
          }
        }
        if (state is AICompleted) {
          _handleAICompleted(context, state.results);
        }
      },
      builder: (context, state) {
        final isProcessing = state is AIProcessing;
        final statusMessage = state is AIError
            ? 'فشل تنفيذ الأمر: ${state.errorMessage}'
            : state is AICompleted
                ? 'اكتمل تنفيذ الأمر بنجاح'
                : state is AIModelDownloading
                    ? 'تحميل النموذج...'
                    : state is AIProcessing
                        ? state.detail
                        : null;

        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
          // ====== المقبض ======
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textDisabled,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ====== العنوان ======
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppColors.aiButtonGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الأوامر الذكية',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'اكتب أو قل ما تريد تطبيقه',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (statusMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      statusMessage,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: state is AIError
                                ? AppColors.accentDanger
                                : AppColors.accentSuccess,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          if (statusMessage != null) const SizedBox(height: 12),
          // ====== أمثلة الأوامر (قابلة للنقر) ======
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _exampleCommands.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    _commandController.text = _exampleCommands[index];
                    setState(() {});
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accentAI.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.accentAI.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _exampleCommands[index],
                      style: const TextStyle(
                        color: AppColors.accentAI,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // ====== تاريخ الأوامر ======
          if (_commandHistory.isNotEmpty) ...[
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _commandHistory.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundTertiary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          size: 16,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _commandHistory[index],
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: AppColors.accentSuccess,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ] else
            const Spacer(),
          // ====== حقل إدخال الأمر + زر الإرسال ======
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                // حقل النص
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.backgroundTertiary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.accentAI.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commandController,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'اكتب أمرك هنا...',
                              hintStyle: TextStyle(
                                color: AppColors.textDisabled,
                                fontSize: 14,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              border: InputBorder.none,
                            ),
                            maxLines: 2,
                            minLines: 1,
                            textDirection: TextDirection.rtl,
                            onChanged: (value) => setState(() {}),
                          ),
                        ),
                        // زر الميكروفون
                        GestureDetector(
                          onTap: _toggleListening,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isListening
                                  ? AppColors.accentDanger.withOpacity(0.2)
                                  : AppColors.backgroundElevated,
                            ),
                            child: Icon(
                              _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                              size: 18,
                              color: _isListening
                                  ? AppColors.accentDanger
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // زر الإرسال
                GestureDetector(
                  onTap: (!isProcessing && _commandController.text.isNotEmpty)
                      ? _executeCommand
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: _commandController.text.isEmpty
                          ? null
                          : AppColors.aiButtonGradient,
                      color: _commandController.text.isEmpty
                          ? AppColors.backgroundElevated
                          : null,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _commandController.text.isEmpty
                          ? null
                          : AppColors.aiButtonGlow,
                    ),
                    child: isProcessing
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: _commandController.text.isEmpty
                                ? AppColors.textDisabled
                                : Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // تنفيذ أمر الذكاء الاصطناعي
  Future<void> _executeCommand() async {
    final command = _commandController.text.trim();
    if (command.isEmpty) return;

    await context.read<AICubit>().executeCommand(
          command,
          timelineState: context.read<EditorCubit>().state.timelineState,
        );
  }
  void _toggleListening() {
    setState(() => _isListening = !_isListening);
    // سيتم ربط التعرف على الكلام هنا
  }

  Future<void> _handleAICompleted(
    BuildContext context,
    List<AIInferenceResult> results,
  ) async {
    final actions = results
        .map(_aiResultToAction)
        .where((action) => action != null)
        .cast<Map<String, dynamic>>()
        .toList();

    if (actions.isNotEmpty) {
      await context.read<EditorCubit>().applyAIActions(actions);
    }

    if (!mounted) return;

    setState(() {
      _commandHistory.insert(0, _commandController.text.trim());
      _commandController.clear();
    });
  }

  Map<String, dynamic>? _aiResultToAction(AIInferenceResult result) {
    final effectParameters = result.effect?.parameters ?? {};
    switch (result.actionType) {
      case AIActionType.applyColorGrade:
        return {
          'type': 'apply_color_grade',
          'target': result.targetClipId ?? 'all_clips',
          'parameters': effectParameters,
        };
      case AIActionType.removeBackground:
        return {
          'type': 'remove_background',
          if (result.targetClipId != null) 'clipId': result.targetClipId,
          'parameters': effectParameters,
        };
      case AIActionType.addMusic:
        return {
          'type': 'add_music',
          'parameters': {
            'audioPath': result.audioClip?.filePath,
            'startTime': result.audioClip?.startTime,
            'duration': result.audioClip?.duration,
          },
        };
      case AIActionType.addTextCaption:
        if (result.textLayers != null && result.textLayers!.isNotEmpty) {
          final caption = result.textLayers!.first;
          return {
            'type': 'add_text_caption',
            'text': caption.text,
            'startTime': caption.startTime,
            'duration': caption.duration,
          };
        }
        return null;
      case AIActionType.generateCaptions:
        if (result.textLayers != null && result.textLayers!.isNotEmpty) {
          return {
            'type': 'generate_captions',
            'captions': result.textLayers!
                .map((textLayer) => {
                      'text': textLayer.text,
                      'startTime': textLayer.startTime,
                      'duration': textLayer.duration,
                    })
                .toList(),
          };
        }
        return null;
      case AIActionType.applyMotionTracking:
        return {
          'type': 'apply_motion_tracking',
          if (result.targetClipId != null) 'clipId': result.targetClipId,
          'parameters': effectParameters,
        };
      case AIActionType.stabilize:
        return {
          'type': 'stabilize',
          if (result.targetClipId != null) 'clipId': result.targetClipId,
          'parameters': effectParameters,
        };
      case AIActionType.speedRamp:
        return {
          'type': 'speed_ramp',
          'parameters': effectParameters,
        };
      default:
        return null;
    }
  }
}
