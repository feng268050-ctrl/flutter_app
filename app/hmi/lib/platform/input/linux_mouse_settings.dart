import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/board_helper.dart';
import 'package:lws_hmi/platform/input/mouse_settings.dart';
import 'package:lws_hmi/platform/percent.dart';

/// Linux: persist via `apply-mouse-settings` (flutter-pi reloads on mtime).
class LinuxMouseSettingsController implements MouseSettingsController {
  LinuxMouseSettingsController({
    this.preferencePath = '/var/lib/hmi/mouse.conf',
    this.applyMouseSettingsCommand = const <String>['apply-mouse-settings'],
    this.runHelperWithStdin = defaultBoardHelperRunnerWithStdin,
  });

  final String preferencePath;
  final List<String> applyMouseSettingsCommand;
  final Future<int> Function(String executable, List<String> arguments, String stdin)
      runHelperWithStdin;

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
      pointerAxes: settings.pointerAxes,
    );
    if (applyMouseSettingsCommand.isEmpty) {
      debugPrint('mouse: set skipped (no apply-mouse-settings command)');
      return;
    }
    final conf = encodeMouseConf(normalized);
    final exe = applyMouseSettingsCommand.first;
    final args = applyMouseSettingsCommand.sublist(1);
    try {
      final code = await runHelperWithStdin(exe, args, conf);
      if (code != 0) {
        debugPrint('mouse: apply-mouse-settings exit $code');
        return;
      }
      debugPrint('mouse: persisted via helper → $preferencePath');
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
  var axes = MousePointerAxes.auto;

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
      case 'pointer_axes':
        axes = switch (value.toLowerCase()) {
          'normal' || 'native' || '0' => MousePointerAxes.normal,
          'swap' || 'swap_xy' || '2' => MousePointerAxes.swap,
          _ => MousePointerAxes.auto,
        };
    }
  }

  return MouseSettings(
    naturalScroll: natural,
    scrollSpeedPercent: scroll,
    pointerSpeedPercent: pointer,
    pointerSizePercent: size,
    primaryButton: primary,
    pointerAxes: axes,
  );
}

@visibleForTesting
String encodeMouseConf(MouseSettings s) {
  final primary =
      s.primaryButton == MousePrimaryButton.right ? 'right' : 'left';
  final axes = switch (s.pointerAxes) {
    MousePointerAxes.normal => 'normal',
    MousePointerAxes.swap => 'swap',
    MousePointerAxes.auto => 'auto',
  };
  return 'natural_scroll=${s.naturalScroll ? 1 : 0}\n'
      'scroll_speed=${clampPercent(s.scrollSpeedPercent)}\n'
      'pointer_speed=${clampPercent(s.pointerSpeedPercent)}\n'
      'pointer_size=${clampPercent(s.pointerSizePercent)}\n'
      'primary_button=$primary\n'
      'pointer_axes=$axes\n';
}
