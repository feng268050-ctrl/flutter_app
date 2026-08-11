import 'dart:io';
import 'dart:typed_data';

import 'package:cyber_hal/output/sound/button_feedback.dart';
import 'package:cyber_hal/src/linux/key_value_conf.dart';
import 'package:cyber_hal/src/output/output_prefs.dart';
import 'package:cyber_hal/src/output/sound/media_audio_controller.dart';
import 'package:flutter/foundation.dart';

/// Linux ButtonFeedback: install click sample next to [OutputPrefs.soundConf]
/// and play via media (filesystem path — not Flutter rootBundle).
final class LinuxButtonFeedback implements ButtonFeedback {
  LinuxButtonFeedback({
    required MediaAudioController mediaAudio,
    this.preferencePath = OutputPrefs.soundConf,
    String initialAssetKey = '',
  })  : _mediaAudio = mediaAudio,
        _assetKey = initialAssetKey;

  final MediaAudioController _mediaAudio;
  final String preferencePath;

  String _assetKey;
  bool _warmed = false;

  @override
  String get assetKey => _assetKey;

  @override
  String get samplesDirectory => File(preferencePath).parent.path;

  @override
  String warmRead() {
    if (_warmed) {
      return _assetKey;
    }
    try {
      final map = readKeyValueConfFileSync(preferencePath);
      _assetKey = (map[OutputPrefs.keyButtonFeedback] ?? '').trim();
    } catch (e) {
      debugPrint('button-feedback: warmRead failed: $e');
    }
    _warmed = true;
    return _assetKey;
  }

  @override
  Future<String> getAssetKey() async {
    if (_warmed) {
      return _assetKey;
    }
    try {
      final map = await readKeyValueConfFile(preferencePath);
      _assetKey = (map[OutputPrefs.keyButtonFeedback] ?? '').trim();
    } catch (e) {
      debugPrint('button-feedback: read failed: $e');
    }
    _warmed = true;
    return _assetKey;
  }

  @override
  Future<void> setAssetKey(String assetKey) async {
    _assetKey = assetKey.trim();
    _warmed = true;
    await upsertKeyValueConfFile(preferencePath, {
      OutputPrefs.keyButtonFeedback: _assetKey,
    });
  }

  @override
  Future<String> installAndSelect(
    Uint8List bytes, {
    required String fileName,
  }) async {
    final path = await _writeSample(bytes, fileName: fileName);
    await setAssetKey(path);
    return path;
  }

  @override
  Future<String> installSample(
    Uint8List bytes, {
    required String fileName,
  }) async {
    final path = await _writeSample(bytes, fileName: fileName);
    if (_assetKey.trim().isEmpty) {
      await setAssetKey(path);
    }
    return path;
  }

  @override
  Future<List<String>> listInstalledSamples() async {
    final dir = Directory(samplesDirectory);
    if (!await dir.exists()) {
      return const <String>[];
    }
    final out = <String>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.isEmpty
          ? entity.path.split(Platform.pathSeparator).last
          : entity.uri.pathSegments.last;
      if (!name.toLowerCase().endsWith('.mp3')) continue;
      if (name == File(preferencePath).uri.pathSegments.last) continue;
      out.add(entity.path);
    }
    out.sort();
    return out;
  }

  Future<String> _writeSample(
    Uint8List bytes, {
    required String fileName,
  }) async {
    final name = sanitizeClickSampleFileName(fileName);
    final dir = Directory(samplesDirectory);
    await dir.create(recursive: true);
    final out = File('${dir.path}/$name');
    await out.writeAsBytes(bytes, flush: true);
    return out.path;
  }

  @override
  Future<void> play() async {
    final key = _assetKey;
    if (key.isEmpty) {
      return;
    }
    try {
      await _mediaAudio.playOneShotAsset(key);
    } catch (e) {
      debugPrint('button-feedback: play failed: $e');
    }
  }

  @override
  Future<void> dispose() async {}
}

/// Basename only; reject path separators / odd characters.
String sanitizeClickSampleFileName(String fileName) {
  final trimmed = fileName.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError('click sample fileName is empty');
  }
  if (trimmed.contains('/') ||
      trimmed.contains(r'\') ||
      trimmed.contains('..')) {
    throw ArgumentError('invalid click sample fileName: $fileName');
  }
  var name = trimmed;
  if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(name)) {
    throw ArgumentError('invalid click sample fileName: $fileName');
  }
  if (!name.toLowerCase().endsWith('.mp3')) {
    name = '$name.mp3';
  }
  return name;
}
