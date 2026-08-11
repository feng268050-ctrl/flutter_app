import 'dart:typed_data';

import 'package:cyber_hal/output/sound/button_feedback.dart';
import 'package:cyber_hal/src/output/sound/media_audio_controller.dart';

/// In-memory ButtonFeedback for host tests / sim.
final class StubButtonFeedback implements ButtonFeedback {
  StubButtonFeedback({
    MediaAudioController? mediaAudio,
    String initialAssetKey = '',
    this.samplesDirectory = '/var/lib/hal',
  })  : _mediaAudio = mediaAudio,
        _assetKey = initialAssetKey;

  final MediaAudioController? _mediaAudio;
  String _assetKey;
  final Map<String, Uint8List> installed = <String, Uint8List>{};
  int playCount = 0;
  String? lastPlayedAsset;

  @override
  final String samplesDirectory;

  @override
  String get assetKey => _assetKey;

  @override
  String warmRead() => _assetKey;

  @override
  Future<String> getAssetKey() async => _assetKey;

  @override
  Future<void> setAssetKey(String assetKey) async {
    _assetKey = assetKey.trim();
  }

  @override
  Future<String> installAndSelect(
    Uint8List bytes, {
    required String fileName,
  }) async {
    final path = await installSample(bytes, fileName: fileName);
    _assetKey = path;
    return path;
  }

  @override
  Future<String> installSample(
    Uint8List bytes, {
    required String fileName,
  }) async {
    final name = fileName.trim().split('/').last;
    final path = '$samplesDirectory/$name';
    installed[path] = Uint8List.fromList(bytes);
    if (_assetKey.trim().isEmpty) {
      _assetKey = path;
    }
    return path;
  }

  @override
  Future<List<String>> listInstalledSamples() async {
    final keys = installed.keys.toList()..sort();
    return keys;
  }

  @override
  Future<void> play() async {
    playCount++;
    lastPlayedAsset = _assetKey;
    final audio = _mediaAudio;
    if (audio != null && _assetKey.isNotEmpty) {
      await audio.playOneShotAsset(_assetKey);
    }
  }

  @override
  Future<void> dispose() async {}
}
