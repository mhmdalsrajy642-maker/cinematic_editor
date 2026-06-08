// lib/features/editor/presentation/widgets/panels/audio_panel.dart
// لوحة الصوت الكاملة: ميكساج، عزل الصوت، مستويات التشغيل
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubit/editor_cubit.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../../../core/models/timeline_models.dart';
class AudioPanel extends StatefulWidget {
  const AudioPanel({super.key});
  @override
  State<AudioPanel> createState() => _AudioPanelState();
}
class _AudioPanelState extends State<AudioPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // مستويات صوت المسارات (سيتم ربطها بالـ Cubit لاحقاً)
  double _videoAudioVolume = 1.0;
  double _musicVolume = 0.6;
  double _voiceOverVolume = 1.0;
  double _sfxVolume = 0.8;
  // معاملات معالجة الصوت
  double _noiseReductionStrength = 0.0;
  double _bassBoost = 0.0;
  double _trebleBoost = 0.0;
  double _compressionRatio = 1.0;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
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
          // ====== العنوان + التبويبات ======
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.timelineTrackAudio.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.equalizer_rounded,
                    color: AppColors.accentSuccess,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'محرر الصوت',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          // تبويبات: الميكسر / المعالجة / عزل الصوت
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.accentSuccess,
              labelColor: AppColors.accentSuccess,
              unselectedLabelColor: AppColors.textTertiary,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'الميكسر'),
                Tab(text: 'معالجة'),
                Tab(text: 'عزل الصوت'),
              ],
            ),
          ),
          // ====== محتوى التبويبات ======
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMixerTab(),
                _buildProcessingTab(),
                _buildIsolationTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // ====== تبويب الميكسر ======
  Widget _buildMixerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildVolumeSlider(
            label: 'صوت الفيديو',
            icon: Icons.videocam_outlined,
            color: AppColors.timelineTrackVideo,
            value: _videoAudioVolume,
            onChanged: (v) => setState(() => _videoAudioVolume = v),
          ),
          const SizedBox(height: 16),
          _buildVolumeSlider(
            label: 'الموسيقى',
            icon: Icons.music_note_rounded,
            color: AppColors.accentSuccess,
            value: _musicVolume,
            onChanged: (v) => setState(() => _musicVolume = v),
          ),
          const SizedBox(height: 16),
          _buildVolumeSlider(
            label: 'التعليق الصوتي',
            icon: Icons.mic_rounded,
            color: AppColors.accentPrimary,
            value: _voiceOverVolume,
            onChanged: (v) => setState(() => _voiceOverVolume = v),
          ),
          const SizedBox(height: 16),
          _buildVolumeSlider(
            label: 'المؤثرات الصوتية',
            icon: Icons.surround_sound_outlined,
            color: AppColors.accentWarning,
            value: _sfxVolume,
            onChanged: (v) => setState(() => _sfxVolume = v),
          ),
          const SizedBox(height: 24),
          // زر مزامنة الصوت مع الإيقاع
          _buildActionButton(
            icon: Icons.sync_rounded,
            label: 'مزامنة مع الإيقاع',
            color: AppColors.accentPrimary,
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            icon: Icons.auto_fix_high_rounded,
            label: 'مطابقة صوت مرجعي (AI)',
            color: AppColors.accentAI,
            isPremium: true,
            onTap: () {},
          ),
        ],
      ),
    );
  }
  // ====== تبويب المعالجة ======
  Widget _buildProcessingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildEffectSlider(
            label: 'تقليل الضوضاء',
            icon: Icons.noise_aware_rounded,
            value: _noiseReductionStrength,
            onChanged: (v) => setState(() => _noiseReductionStrength = v),
          ),
          const SizedBox(height: 16),
          _buildEffectSlider(
            label: 'تعزيز الجهير (Bass)',
            icon: Icons.graphic_eq_rounded,
            value: _bassBoost,
            min: -1.0, max: 1.0,
            onChanged: (v) => setState(() => _bassBoost = v),
          ),
          const SizedBox(height: 16),
          _buildEffectSlider(
            label: 'تعزيز الحاد (Treble)',
            icon: Icons.equalizer_rounded,
            value: _trebleBoost,
            min: -1.0, max: 1.0,
            onChanged: (v) => setState(() => _trebleBoost = v),
          ),
          const SizedBox(height: 16),
          _buildEffectSlider(
            label: 'ضغط الصوت (Compressor)',
            icon: Icons.compress_rounded,
            value: _compressionRatio,
            min: 1.0, max: 10.0,
            onChanged: (v) => setState(() => _compressionRatio = v),
          ),
          const SizedBox(height: 24),
          // تطبيق المعالجة
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('معاينة التأثيرات'),
            ),
          ),
        ],
      ),
    );
  }
  // ====== تبويب عزل الصوت ======
  Widget _buildIsolationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'عزل الصوت بالذكاء الاصطناعي',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'يفصل هذا الخيار صوت الأشخاص عن الموسيقى الخلفية',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          _buildIsolationOption(
            title: 'عزل صوت الكلام',
            subtitle: 'استخراج أصوات الأشخاص فقط',
            icon: Icons.record_voice_over_rounded,
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _buildIsolationOption(
            title: 'عزل الموسيقى',
            subtitle: 'استخراج الموسيقى الخلفية فقط',
            icon: Icons.library_music_rounded,
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _buildIsolationOption(
            title: 'إزالة الكلام',
            subtitle: 'الإبقاء على الموسيقى وحذف الكلام',
            icon: Icons.voice_over_off_rounded,
            onTap: () {},
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentWarning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.accentWarning.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.accentWarning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'عزل الصوت يتطلب معالجة محلية قد تستغرق دقيقة واحدة.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.accentWarning,
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
  // ====== عناصر الواجهة المساعدة ======
  Widget _buildVolumeSlider({
    required String label,
    required IconData icon,
    required Color color,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style: Theme.of(context).textTheme.bodyMedium),
                  Text('${(value * 100).toInt()}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                      )),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  activeTrackColor: color,
                  inactiveTrackColor: color.withOpacity(0.2),
                  thumbColor: color,
                  overlayColor: color.withOpacity(0.2),
                ),
                child: Slider(
                  value: value,
                  min: 0.0,
                  max: 1.0,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildEffectSlider({
    required String label,
    required IconData icon,
    required double value,
    required ValueChanged<double> onChanged,
    double min = 0.0,
    double max = 1.0,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 16),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Text(
              value.toStringAsFixed(2),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.accentPrimary,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            activeTrackColor: AppColors.accentPrimary,
            inactiveTrackColor: AppColors.backgroundElevated,
            thumbColor: AppColors.accentPrimary,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isPremium = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TextStyle(color: color, fontSize: 14)),
            ),
            if (isPremium)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: AppColors.aiButtonGradient,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Pro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  Widget _buildIsolationOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.backgroundTertiary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentSuccess.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.accentSuccess, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textTertiary,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}
