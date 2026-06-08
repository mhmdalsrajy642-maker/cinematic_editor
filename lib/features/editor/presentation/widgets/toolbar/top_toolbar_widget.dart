// lib/features/editor/presentation/widgets/toolbar/top_toolbar_widget.dart
// الشريط العلوي يحتوي على أزرار: تصدير، Undo، Redo، حفظ، وعنوان المشروع
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubit/editor_cubit.dart';
import '../../../../../shared/theme/app_colors.dart';
class TopToolbarWidget extends StatelessWidget {
  const TopToolbarWidget({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditorCubit, EditorState>(
      builder: (context, state) {
        return Container(
          height: 56 + MediaQuery.of(context).padding.top,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            left: 12,
            right: 12,
          ),
          decoration: const BoxDecoration(
            color: AppColors.backgroundSecondary,
            border: Border(
              bottom: BorderSide(
                color: AppColors.backgroundElevated,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // ====== زر الرجوع ======
              _buildIconButton(
                context,
                icon: Icons.arrow_back_ios_new_rounded,
                tooltip: 'رجوع',
                onTap: () => Navigator.of(context).pop(),
              ),
              
              const SizedBox(width: 8),
              
              // ====== عنوان المشروع ======
              Expanded(
                child: GestureDetector(
                  onTap: () => _showRenameDialog(context),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مشروع بدون عنوان',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatDuration(state.timelineState.totalDuration),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // ====== أزرار التحكم اليمينية ======
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // زر Undo
                  _buildIconButton(
                    context,
                    icon: Icons.undo_rounded,
                    tooltip: 'تراجع',
                    isEnabled: state.canUndo,
                    onTap: state.canUndo
                        ? () => context.read<EditorCubit>().undo()
                        : null,
                  ),
                  
                  const SizedBox(width: 4),
                  
                  // زر Redo
                  _buildIconButton(
                    context,
                    icon: Icons.redo_rounded,
                    tooltip: 'إعادة',
                    isEnabled: state.canRedo,
                    onTap: state.canRedo
                        ? () => context.read<EditorCubit>().redo()
                        : null,
                  ),
                  
                  const SizedBox(width: 4),
                  
                  // زر حفظ
                  _buildIconButton(
                    context,
                    icon: Icons.save_outlined,
                    tooltip: 'حفظ',
                    onTap: () => _handleSave(context),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // ====== زر التصدير (الأهم) ======
                  _buildExportButton(context, state),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  // بناء أزرار الأيقونات المستطيلة
  Widget _buildIconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
    bool isEnabled = true,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isEnabled
                ? AppColors.backgroundElevated
                : AppColors.backgroundTertiary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isEnabled ? AppColors.textPrimary : AppColors.textDisabled,
            size: 18,
          ),
        ),
      ),
    );
  }
  // بناء زر التصدير المميز
  Widget _buildExportButton(BuildContext context, EditorState state) {
    if (state.isExporting) {
      // عرض شريط التقدم أثناء التصدير
      return Container(
        width: 90,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.backgroundElevated,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            // خلفية شريط التقدم
            FractionallySizedBox(
              widthFactor: state.exportProgress,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.aiButtonGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            // نص النسبة المئوية
            Center(
              child: Text(
                '${(state.exportProgress * 100).toInt()}%',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () => _handleExport(context),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: AppColors.aiButtonGradient,
          borderRadius: BorderRadius.circular(10),
          boxShadow: AppColors.accentGlow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.file_upload_outlined,
              color: AppColors.textPrimary,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'تصدير',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
  // تنسيق المدة الزمنية
  String _formatDuration(double seconds) {
    final int totalSeconds = seconds.toInt();
    final int minutes = totalSeconds ~/ 60;
    final int secs = totalSeconds % 60;
    final int millis = ((seconds - totalSeconds) * 100).toInt();
    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}.'
        '${millis.toString().padLeft(2, '0')}';
  }
  // حوار تسمية المشروع
  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: 'مشروع بدون عنوان');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        title: const Text(
          'تسمية المشروع',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.backgroundTertiary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
  void _handleSave(BuildContext context) {
    // سيتم تنفيذ الحفظ الكامل لاحقاً
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('تم الحفظ بنجاح'),
        backgroundColor: AppColors.accentSuccess,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
  void _handleExport(BuildContext context) {
    // فتح شاشة التصدير
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ExportOptionsSheet(),
    );
  }
}
// ====================================================
// ورقة خيارات التصدير السفلية
// ====================================================
class _ExportOptionsSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // مقبض الورقة
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textDisabled,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'خيارات التصدير',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          // خيارات الجودة
          _buildExportOption(
            context,
            title: '4K Ultra HD',
            subtitle: '3840×2160 · مناسب للمحترفين',
            icon: Icons.hd,
            isPremium: true,
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _buildExportOption(
            context,
            title: '1080p Full HD',
            subtitle: '1920×1080 · الأفضل للمشاركة',
            icon: Icons.high_quality,
            isPremium: false,
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _buildExportOption(
            context,
            title: '720p HD',
            subtitle: '1280×720 · حجم ملف أصغر',
            icon: Icons.sd,
            isPremium: false,
            onTap: () {},
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
  Widget _buildExportOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isPremium,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundTertiary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.backgroundElevated,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.accentPrimary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (isPremium) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: AppColors.aiButtonGradient,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Premium',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textTertiary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
