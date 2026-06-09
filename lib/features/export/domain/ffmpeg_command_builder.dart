import '../../../core/models/timeline_models.dart';

enum ExportProfile {
  p720,
  p1080,
  p4k,
}

extension ExportProfileExtension on ExportProfile {
  String get resolutionName {
    switch (this) {
      case ExportProfile.p720:
        return '720p';
      case ExportProfile.p1080:
        return '1080p';
      case ExportProfile.p4k:
        return '4K';
    }
  }

  int get width {
    switch (this) {
      case ExportProfile.p720:
        return 1280;
      case ExportProfile.p1080:
        return 1920;
      case ExportProfile.p4k:
        return 3840;
    }
  }

  int get height {
    switch (this) {
      case ExportProfile.p720:
        return 720;
      case ExportProfile.p1080:
        return 1080;
      case ExportProfile.p4k:
        return 2160;
    }
  }

  String get ffmpegScale => '${width}x$height';

  String get codecPreset {
    switch (this) {
      case ExportProfile.p720:
      case ExportProfile.p1080:
        return 'fast';
      case ExportProfile.p4k:
        return 'medium';
    }
  }

  int get targetBitrateKbps {
    switch (this) {
      case ExportProfile.p720:
        return 3000;
      case ExportProfile.p1080:
        return 6000;
      case ExportProfile.p4k:
        return 12000;
    }
  }
}

class FFmpegCommandBuilder {
  const FFmpegCommandBuilder();

  String buildExportCommand(
    TimelineState timeline,
    ExportProfile profile,
    String outputPath,
  ) {
    final validVideoClips = timeline.videoClips.where(
      (clip) => clip.clipType == ClipType.video || clip.clipType == ClipType.image,
    );
    final videoInputs = _buildInputSources(validVideoClips);
    final audioInputs = _buildAudioInputs(timeline.audioClips);

    final filterComplex = <String>[];
    final videoLabels = _buildVideoFilters(validVideoClips, profile, filterComplex);
    final audioOutputLabel = _buildAudioFilters(timeline.audioClips, videoInputs.length, filterComplex);
    final finalVideoLabel = _buildTextFilters(timeline.textLayers, profile, filterComplex, videoLabels);

    final mapping = <String>[];
    if (finalVideoLabel != null) {
      mapping.add('-map [$finalVideoLabel]');
    }
    if (audioOutputLabel != null) {
      mapping.add('-map [$audioOutputLabel]');
    }

    final codec = '-c:v libx264 -preset ${profile.codecPreset} -b:v ${profile.targetBitrateKbps}k -crf 18 -c:a aac -b:a 192k';
    const overwrite = '-y';
    final filterArgument = filterComplex.isNotEmpty
        ? ['-filter_complex', '"${filterComplex.join(';')}"']
        : <String>[];

    return <String>[overwrite, ...videoInputs, ...audioInputs, ...filterArgument, ...mapping, codec, '"$outputPath"']
        .join(' ');
  }

  List<String> _buildInputSources(Iterable<VideoClip> clips) {
    final inputs = <String>[];
    for (final clip in clips) {
      final path = clip.proxyPath.isNotEmpty ? clip.proxyPath : clip.originalPath;
      if (clip.clipType == ClipType.image) {
        inputs.add('-loop 1 -t ${clip.duration} -i ${_escapePath(path)}');
      } else {
        inputs.add('-i ${_escapePath(path)}');
      }
    }
    return inputs;
  }

  List<String> _buildAudioInputs(Iterable<AudioClip> clips) {
    final inputs = <String>[];
    for (final clip in clips) {
      inputs.add('-i ${_escapePath(clip.filePath)}');
    }
    return inputs;
  }

  String? _buildVideoFilters(
    Iterable<VideoClip> clips,
    ExportProfile profile,
    List<String> filterComplex,
  ) {
    final sortedClips = clips.toList()
      ..sort((a, b) {
        final trackCompare = a.trackIndex.compareTo(b.trackIndex);
        if (trackCompare != 0) return trackCompare;
        return a.startTime.compareTo(b.startTime);
      });

    if (sortedClips.isEmpty) {
      filterComplex.add('nullsrc=size=${profile.ffmpegScale}:duration=${timelineDuration(clips)} [baseVideo]');
      return 'baseVideo';
    }

    final labels = <String>[];
    var inputIndex = 0;
    for (final clip in sortedClips) {
      final sourceLabel = '[$inputIndex:v]';
      final outputLabel = '[v$inputIndex]';
      final filter = <String>[sourceLabel, 'setpts=PTS-STARTPTS', 'scale=$profile.ffmpegScale', 'format=rgba'];
      final effectFilter = _buildEffectFilter(clip.effects);
      if (effectFilter.isNotEmpty) {
        filter.add(effectFilter);
      }
      filter.add(outputLabel);
      filterComplex.add(filter.join(','));
      labels.add(outputLabel);
      inputIndex += 1;
    }

    if (labels.length == 1) {
      return labels.first.substring(1, labels.first.length - 1);
    }

    var currentLabel = labels.first;
    for (var i = 1; i < labels.length; i += 1) {
      final nextLabel = labels[i];
      final overlayLabel = '[ov$i]';
      final clip = sortedClips[i];
      final x = (clip.transform.x * profile.width).toInt();
      final y = (clip.transform.y * profile.height).toInt();
      final enable = "between(t,${clip.startTime},${clip.endTime})";
      filterComplex.add('$currentLabel$nextLabel overlay=x=$x:y=$y:enable=\'$enable\'$overlayLabel');
      currentLabel = overlayLabel;
    }

    return currentLabel.substring(1, currentLabel.length - 1);
  }

  String _buildEffectFilter(List<VideoEffect> effects) {
    if (effects.isEmpty) return '';
    final eqParts = <String>[];
    for (final effect in effects) {
      if (!effect.isEnabled) continue;
      switch (effect.type) {
        case EffectType.brightness:
          final value = effect.parameters['value'] ?? 0.0;
          eqParts.add('brightness=$value');
          break;
        case EffectType.contrast:
          final value = effect.parameters['value'] ?? 1.0;
          eqParts.add('contrast=$value');
          break;
        case EffectType.saturation:
          final value = effect.parameters['value'] ?? 1.0;
          eqParts.add('saturation=$value');
          break;
        case EffectType.temperature:
          final value = effect.parameters['value'] ?? 0.0;
          eqParts.add('temperature=$value');
          break;
        default:
          break;
      }
    }
    if (eqParts.isEmpty) return '';
    return 'eq=${eqParts.join(':')}';
  }

  String? _buildAudioFilters(
    Iterable<AudioClip> clips,
    int videoInputCount,
    List<String> filterComplex,
  ) {
    if (clips.isEmpty) return null;

    final audioLabels = <String>[];
    var inputOffset = 0;
    for (final clip in clips) {
      final delayMs = (clip.startTime * 1000).toInt();
      final label = '[a$inputOffset]';
      final filter = <String>[
        '[${videoInputCount + inputOffset}:a]',
        'adelay=$delayMs|$delayMs',
        'volume=$clip.volume',
      ];
      if (clip.fadeInDuration > 0) {
        filter.add('afade=t=in:st=0:d=$clip.fadeInDuration');
      }
      if (clip.fadeOutDuration > 0) {
        final fadeStart = clip.duration - clip.fadeOutDuration;
        filter.add('afade=t=out:st=$fadeStart:d=$clip.fadeOutDuration');
      }
      filter.add(label);
      filterComplex.add(filter.join(','));
      audioLabels.add(label);
      inputOffset += 1;
    }

    if (audioLabels.length == 1) {
      return audioLabels.first.substring(1, audioLabels.first.length - 1);
    }

    const amixLabel = '[aout]';
    filterComplex.add('${audioLabels.join('')}'
        'amix=inputs=${audioLabels.length}:duration=longest:dropout_transition=2$amixLabel');
    return 'aout';
  }

  String? _buildTextFilters(
    Iterable<TextLayer> textLayers,
    ExportProfile profile,
    List<String> filterComplex,
    String? currentVideoLabel,
  ) {
    if (currentVideoLabel == null) return null;
    var activeLabel = '[$currentVideoLabel]';
    var index = 0;
    for (final text in textLayers) {
      final nextLabel = '[vt$index]';
      final x = (text.transform.x * profile.width).toInt();
      final y = (text.transform.y * profile.height).toInt();
      final fontSize = text.style.fontSize.toInt();
      final fontColor = _colorToHex(text.style.color);
      final escapedText = _escapeDrawText(text.text);
      final enable = "between(t,$text.startTime,$text.endTime)";
      final drawText =
          'drawtext=text=\'$escapedText\':x=$x:y=$y:fontsize=$fontSize:fontcolor=$fontColor:alpha=$text.transform.opacity:enable=\'$enable\'';
      filterComplex.add('$activeLabel$drawText$nextLabel');
      activeLabel = nextLabel;
      index += 1;
    }
    return activeLabel.substring(1, activeLabel.length - 1);
  }

  double timelineDuration(Iterable<VideoClip> clips) {
    double maxTime = 0.0;
    for (final clip in clips) {
      if (clip.endTime > maxTime) maxTime = clip.endTime;
    }
    return maxTime > 0 ? maxTime : 1.0;
  }

  String _escapePath(String path) {
    return "'${path.replaceAll("'", "'\\''")}'";
  }

  String _escapeDrawText(String text) {
    return text.replaceAll("'", "\\'").replaceAll(':', '\\:');
  }

  String _colorToHex(int color) {
    final hex = color.toRadixString(16).padLeft(8, '0');
    return '#${hex.substring(2)}';
  }
}
