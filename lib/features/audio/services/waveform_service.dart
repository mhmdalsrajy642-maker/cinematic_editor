import 'dart:math';

class WaveformData {
  final String source;
  final double duration;
  final List<double> peaks;

  const WaveformData({
    required this.source,
    required this.duration,
    required this.peaks,
  });
}

class WaveformService {
  const WaveformService();

  Future<WaveformData> extractWaveform(
    String filePath, {
    int sampleCount = 120,
    double duration = 0.0,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final peaks = _generatePlaceholderPeaks(filePath, sampleCount);
    return WaveformData(
      source: filePath,
      duration: duration,
      peaks: peaks,
    );
  }

  List<double> _generatePlaceholderPeaks(String source, int sampleCount) {
    final seed = source.hashCode;
    final random = Random(seed);
    return List<double>.generate(sampleCount, (index) {
      final base = sin((index / sampleCount) * pi * 2) * 0.5 + 0.5;
      final variance = random.nextDouble() * 0.35;
      return (base * 0.7 + variance).clamp(0.0, 1.0);
    });
  }
}
