import 'dart:math';

import '../../../core/models/timeline_models.dart';

class VolumeAutomationPoint {
  final double time;
  final double volume;

  const VolumeAutomationPoint({required this.time, required this.volume});
}

class AudioMixerService {
  const AudioMixerService();

  List<AudioClip> applyTrackVolume(
    List<AudioClip> clips,
    AudioType trackType,
    double volume,
  ) {
    return clips.map((clip) {
      if (clip.audioType != trackType) return clip;
      return clip.copyWith(volume: volume.clamp(0.0, 1.0));
    }).toList();
  }

  AudioClip applyFadeInOut(
    AudioClip clip, {
    required double fadeInDuration,
    required double fadeOutDuration,
  }) {
    return clip.copyWith(
      fadeInDuration: fadeInDuration.clamp(0.0, clip.duration),
      fadeOutDuration: fadeOutDuration.clamp(0.0, clip.duration),
    );
  }

  List<AudioClip> applyVolumeAutomation(
    List<AudioClip> clips,
    AudioType trackType,
    List<VolumeAutomationPoint> automationCurve,
  ) {
    if (automationCurve.isEmpty) return clips;

    final sortedCurve = List<VolumeAutomationPoint>.from(automationCurve)
      ..sort((a, b) => a.time.compareTo(b.time));

    return clips.map((clip) {
      if (clip.audioType != trackType) return clip;

      final midpoint = clip.startTime + clip.duration / 2;
      final volume = _interpolateVolume(midpoint, sortedCurve).clamp(0.0, 1.0);
      return clip.copyWith(volume: volume);
    }).toList();
  }

  double _interpolateVolume(
    double time,
    List<VolumeAutomationPoint> curve,
  ) {
    if (curve.isEmpty) return 1.0;
    if (time <= curve.first.time) return curve.first.volume;
    if (time >= curve.last.time) return curve.last.volume;

    for (var index = 1; index < curve.length; index++) {
      final previous = curve[index - 1];
      final current = curve[index];
      if (time <= current.time) {
        final position = (time - previous.time) /
            (current.time - previous.time);
        return previous.volume +
            (current.volume - previous.volume) * position;
      }
    }
    return curve.last.volume;
  }

  Map<AudioType, double> computeTrackLevels(List<AudioClip> clips) {
    final levels = <AudioType, double>{};
    for (final clip in clips) {
      final existing = levels[clip.audioType] ?? 0.0;
      levels[clip.audioType] = max(existing, clip.volume);
    }
    return levels;
  }
}
