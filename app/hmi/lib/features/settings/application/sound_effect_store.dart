import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// Persisted UI click sound-effect index (lws-ui `SoundEffectSettings`).
///
/// File: `/var/lib/hmi/sound-effect` — single integer `0..2` (default `0`).
final class SoundEffectStore {
  SoundEffectStore({
    String? preferencePath,
  }) : preferencePath = preferencePath ?? '${OsPaths.varHmi}/sound-effect';

  static const effectCount = 3;
  static const defaultIndex = 0;

  /// Asset keys aligned with lws-ui `GlobalSoundManager.CLICK_RAW` order.
  static const assetKeys = <String>[
    'assets/audio/click_effect_1.mp3', // click_mp3_2 → Effect 1
    'assets/audio/click_effect_2.mp3', // click_mp3 → Effect 2
    'assets/audio/click_effect_3.mp3', // click_mp3_1 → Effect 3
  ];

  static const labels = <String>['Effect 1', 'Effect 2', 'Effect 3'];

  final String preferencePath;

  int _index = defaultIndex;
  bool _warmed = false;

  int get index => _index;

  String get activeAssetKey => assetKeys[_index];

  static int clampIndex(int? value) {
    if (value == null || value < 0 || value >= effectCount) {
      return defaultIndex;
    }
    return value;
  }

  /// Synchronous warm-read for bootstrap (mirror `SoundEffectSettings.warmCache`).
  int warmRead() {
    if (_warmed) {
      return _index;
    }
    try {
      final f = File(preferencePath);
      if (f.existsSync()) {
        final raw = f.readAsStringSync().trim();
        _index = clampIndex(int.tryParse(raw));
      }
    } catch (e) {
      debugPrint('sound-effect: warmRead failed: $e');
      _index = defaultIndex;
    }
    _warmed = true;
    return _index;
  }

  Future<int> read() async {
    if (_warmed) {
      return _index;
    }
    try {
      final f = File(preferencePath);
      if (await f.exists()) {
        final raw = (await f.readAsString()).trim();
        _index = clampIndex(int.tryParse(raw));
      }
    } catch (e) {
      debugPrint('sound-effect: read failed: $e');
      _index = defaultIndex;
    }
    _warmed = true;
    return _index;
  }

  Future<void> write(int index) async {
    _index = clampIndex(index);
    _warmed = true;
    try {
      final f = File(preferencePath);
      await f.parent.create(recursive: true);
      await f.writeAsString('$_index\n');
    } catch (e) {
      debugPrint('sound-effect: write failed: $e');
    }
  }
}
