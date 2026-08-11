/// UI button / click sound feedback (shared sample file + play via audio HAL).
///
/// Backend kind: OS preference file + media/audio controller.
/// Concrete Linux type: [LinuxButtonFeedback] (exported from `hal/output/sound.dart`).
///
/// Product Apps own the Flutter asset **catalog**; selecting an effect MUST
/// [installAndSelect] bytes next to [sound.conf] so every App sharing that
/// conf can play without shipping the same assets. Conf key `button_feedback`
/// stores the **absolute filesystem path** of the installed sample.
library;

import 'dart:typed_data';

/// Portable button-feedback API.
abstract class ButtonFeedback {
  /// Active sample path (absolute file under the sound.conf directory), or
  /// empty when unset. Legacy Flutter asset keys may still appear until the
  /// product App re-installs the catalog.
  String get assetKey;

  /// Directory that holds [sound.conf] and installed click samples.
  String get samplesDirectory;

  /// Synchronous warm-read for App bootstrap.
  String warmRead();

  Future<String> getAssetKey();

  /// Persist an absolute (or legacy) path without copying bytes.
  ///
  /// Prefer [installAndSelect] when the sample comes from an App asset bundle.
  Future<void> setAssetKey(String assetKey);

  /// Write [bytes] as [fileName] next to sound.conf and persist that absolute
  /// path as the active click sample.
  Future<String> installAndSelect(
    Uint8List bytes, {
    required String fileName,
  });

  /// Write [bytes] as [fileName] next to sound.conf without changing the
  /// active selection (unless the active path is empty — then selects).
  Future<String> installSample(
    Uint8List bytes, {
    required String fileName,
  });

  /// Absolute paths of installed `*.mp3` samples next to sound.conf.
  Future<List<String>> listInstalledSamples();

  /// Play the active sample via the injected media/audio HAL.
  Future<void> play();

  Future<void> dispose();
}
