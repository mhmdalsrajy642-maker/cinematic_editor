import '../../../core/models/timeline_models.dart';

enum AudioEffectType {
  noiseReduction,
  compressor,
  equalizer,
}

class AudioEffectsService {
  const AudioEffectsService();

  AudioClip applyEffect(
    AudioClip clip,
    AudioEffectType effect,
    {
    double intensity = 0.5,
    double bass = 0.0,
    double treble = 0.0,
  }
  ) {
    switch (effect) {
      case AudioEffectType.noiseReduction:
        return applyNoiseReduction(clip, intensity);
      case AudioEffectType.compressor:
        return applyCompression(clip, intensity);
      case AudioEffectType.equalizer:
        return applyEqualizer(clip, bass: bass, treble: treble);
    }
  }

  AudioClip applyNoiseReduction(AudioClip clip, double strength) {
    final adjustment = 1.0 - (strength.clamp(0.0, 1.0) * 0.15);
    return clip.copyWith(volume: (clip.volume * adjustment).clamp(0.0, 1.0));
  }

  AudioClip applyCompression(AudioClip clip, double ratio) {
    final normalized = ratio.clamp(1.0, 10.0);
    final gain = 1.0 - ((normalized - 1.0) / 20.0);
    return clip.copyWith(volume: (clip.volume * gain).clamp(0.0, 1.0));
  }

  AudioClip applyEqualizer(
    AudioClip clip, {
    double bass = 0.0,
    double treble = 0.0,
  }) {
    final bassAdjustment = (bass.clamp(-1.0, 1.0) * 0.05) + 1.0;
    final trebleAdjustment = (treble.clamp(-1.0, 1.0) * 0.03) + 1.0;
    return clip.copyWith(
      volume: (clip.volume * bassAdjustment * trebleAdjustment).clamp(0.0, 1.0),
    );
  }
}
