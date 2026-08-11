import 'dart:async';
import 'dart:typed_data';

import 'package:cyber_hal/output.dart';
import 'package:flutter/services.dart';

/// App catalog + façade for HAL [ButtonFeedback] click samples.
///
/// Effect labels/assets stay product-owned. Selecting an effect copies the
/// sample next to `/var/lib/hal/sound.conf` and persists the absolute path so
/// OS Settings / other Apps play the same file without bundling product audio.
final class SoundEffectStore {
  SoundEffectStore({
    required this.feedback,
    Future<Uint8List> Function(String assetKey)? loadAsset,
  }) : _loadAsset = loadAsset ?? _loadRootBundleAsset;

  static const effectCount = 3;
  static const defaultIndex = 0;

  /// Asset keys aligned with lws-ui `GlobalSoundManager.CLICK_RAW` order.
  static const assetKeys = <String>[
    'assets/audio/click_effect_1.mp3', // click_mp3_2 → Effect 1
    'assets/audio/click_effect_2.mp3', // click_mp3 → Effect 2
    'assets/audio/click_effect_3.mp3', // click_mp3_1 → Effect 3
  ];

  static const labels = <String>['Effect 1', 'Effect 2', 'Effect 3'];

  final ButtonFeedback feedback;
  final Future<Uint8List> Function(String assetKey) _loadAsset;

  static String fileNameForIndex(int index) {
    final key = assetKeys[clampIndex(index)];
    return key.split('/').last;
  }

  int get index {
    final stored = feedback.assetKey.trim();
    if (stored.isEmpty) {
      return defaultIndex;
    }
    final base = stored.split('/').last;
    for (var i = 0; i < assetKeys.length; i++) {
      final key = assetKeys[i];
      if (stored == key || base == key.split('/').last) {
        return i;
      }
    }
    return defaultIndex;
  }

  String get activeAssetKey {
    final key = feedback.assetKey;
    return key.isNotEmpty ? key : assetKeys[defaultIndex];
  }

  static int clampIndex(int? value) {
    if (value == null || value < 0 || value >= effectCount) {
      return defaultIndex;
    }
    return value;
  }

  /// Warm-read conf; migrate legacy Flutter asset keys; seed default sample.
  int warmRead() {
    feedback.warmRead();
    final stored = feedback.assetKey.trim();
    if (stored.isEmpty) {
      unawaited(selectIndex(defaultIndex));
      return defaultIndex;
    }
    if (!_looksLikeFilesystemPath(stored)) {
      // Legacy `assets/audio/…` key — re-install from this App's catalog.
      final i = assetKeys.indexOf(stored);
      unawaited(selectIndex(i >= 0 ? i : defaultIndex));
      return i >= 0 ? i : defaultIndex;
    }
    // Ensure the full product catalog is on disk for HAL playback (OS Settings
    // has no effect picker; it uses the path persisted here).
    unawaited(publishCatalog());
    return index;
  }

  /// Copy every catalog sample next to sound.conf (selection unchanged unless
  /// conf was empty — see [ButtonFeedback.installSample]).
  Future<void> publishCatalog() async {
    for (var i = 0; i < assetKeys.length; i++) {
      final bytes = await _loadAsset(assetKeys[i]);
      await feedback.installSample(
        bytes,
        fileName: fileNameForIndex(i),
      );
    }
  }

  Future<void> selectIndex(int index) async {
    final i = clampIndex(index);
    final bytes = await _loadAsset(assetKeys[i]);
    await feedback.installAndSelect(
      bytes,
      fileName: fileNameForIndex(i),
    );
  }

  Future<void> previewIndex(int index) async {
    await selectIndex(index);
    await feedback.play();
  }

  static Future<Uint8List> _loadRootBundleAsset(String assetKey) async {
    final data = await rootBundle.load(assetKey);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  static bool _looksLikeFilesystemPath(String key) {
    return key.startsWith('/');
  }
}
