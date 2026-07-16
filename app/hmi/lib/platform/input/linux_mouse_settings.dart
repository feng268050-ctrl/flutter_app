import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/input/mouse_settings.dart';
import 'package:lws_hmi/platform/percent.dart';

/// Linux: write `/var/lib/lws-hmi/mouse.conf` only.
///
/// flutter-pi polls mtime and reloads (do **not** SIGHUP — that exits the
/// process and leaves `hmi.service` stopped with Restart=on-failure).
class LinuxMouseSettingsController implements MouseSettingsController {
  LinuxMouseSettingsController({
    this.preferencePath = '/var/lib/lws-hmi/mouse.conf',
  });

  final String preferencePath;

  @override
  Future<MouseSettings> getSettings() async {
    try {
      final file = File(preferencePath);
      if (!await file.exists()) {
        return MouseSettings.defaults();
      }
      return parseMouseConf(await file.readAsString());
    } catch (e) {
      debugPrint('mouse: get failed: $e');
      return MouseSettings.defaults();
    }
  }

  @override
  Future<void> setSettings(MouseSettings settings) async {
    final normalized = MouseSettings(
      naturalScroll: settings.naturalScroll,
      scrollSpeedPercent: clampPercent(settings.scrollSpeedPercent),
      pointerSpeedPercent: clampPercent(settings.pointerSpeedPercent),
      pointerSizePercent: clampPercent(settings.pointerSizePercent),
      primaryButton: settings.primaryButton,
    );
    try {
      final file = File(preferencePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(encodeMouseConf(normalized), flush: true);
      debugPrint('mouse: persisted $preferencePath');
    } catch (e) {
      debugPrint('mouse: persist failed: $e');
    }
  }

  @override
  Future<void> dispose() async {}
}

/// Parse key=value mouse.conf (unknown keys ignored).
@visibleForTesting
MouseSettings parseMouseConf(String raw) {
  var natural = false;
  var scroll = 50;
  var pointer = 50;
  var size = 20;
  var primary = MousePrimaryButton.left;

  for (final line in raw.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }
    final eq = trimmed.indexOf('=');
    if (eq <= 0) {
      continue;
    }
    final key = trimmed.substring(0, eq).trim();
    final value = trimmed.substring(eq + 1).trim();
    switch (key) {
      case 'natural_scroll':
        natural = value == '1' || value.toLowerCase() == 'true';
      case 'scroll_speed':
        scroll = clampPercent(int.tryParse(value) ?? 50);
      case 'pointer_speed':
        pointer = clampPercent(int.tryParse(value) ?? 50);
      case 'pointer_size':
        size = clampPercent(int.tryParse(value) ?? 20);
      case 'primary_button':
        primary = value == 'right'
            ? MousePrimaryButton.right
            : MousePrimaryButton.left;
    }
  }

  return MouseSettings(
    naturalScroll: natural,
    scrollSpeedPercent: scroll,
    pointerSpeedPercent: pointer,
    pointerSizePercent: size,
    primaryButton: primary,
  );
}

@visibleForTesting
String encodeMouseConf(MouseSettings s) {
  final primary =
      s.primaryButton == MousePrimaryButton.right ? 'right' : 'left';
  return 'natural_scroll=${s.naturalScroll ? 1 : 0}\n'
      'scroll_speed=${clampPercent(s.scrollSpeedPercent)}\n'
      'pointer_speed=${clampPercent(s.pointerSpeedPercent)}\n'
      'pointer_size=${clampPercent(s.pointerSizePercent)}\n'
      'primary_button=$primary\n';
}
