import 'dart:io';

import 'package:cyber_hal/input/keyboard.dart';
import 'package:cyber_hal/src/linux/board_helper.dart';
import 'package:flutter/foundation.dart';

/// Restarts HMI so flutter-pi re-reads XKB; injectable for tests.
typedef HmiRestartRunner = Future<int> Function();

Future<int> defaultHmiRestartRunner() async {
  return defaultBoardHelperRunner('systemctl', const <String>['restart', 'hmi']);
}

/// Linux keyboard: HID presence + XKB pref + HMI restart (D15 v1).
class LinuxKeyboard implements Keyboard {
  LinuxKeyboard({
    this.preferencePath = '/var/lib/hmi/keyboard.conf',
    this.etcDefaultKeyboardPath = '/etc/default/keyboard',
    this.probe = const UsbHidKeyboardProbe(),
    this.restartHmi = defaultHmiRestartRunner,
    this.syncEtcDefault = true,
    this.applyRestart = true,
  });

  final String preferencePath;
  final String etcDefaultKeyboardPath;
  final UsbHidKeyboardProbe probe;
  final HmiRestartRunner restartHmi;

  /// Also write Debian-style `/etc/default/keyboard` when possible.
  final bool syncEtcDefault;

  /// When false, [setLayout] only persists (tests / dry-run).
  final bool applyRestart;

  static const us = KeyboardLayout(
    id: 'us',
    model: 'pc105',
    displayName: 'ANSI US (QWERTY)',
  );
  static const de = KeyboardLayout(
    id: 'de',
    model: 'pc105',
    displayName: 'ISO DE (QWERTZ)',
  );
  static const fr = KeyboardLayout(
    id: 'fr',
    model: 'pc105',
    displayName: 'ISO FR (AZERTY)',
  );
  static const jp = KeyboardLayout(
    id: 'jp',
    model: 'jp106',
    displayName: 'JIS JP',
  );

  /// Demo-only; excluded from product Settings Segment.
  static const ru = KeyboardLayout(id: 'ru', displayName: 'Russian');

  @override
  Future<bool> isPresent() async {
    final line = await probe.statusLine();
    return line.startsWith('detected:');
  }

  @override
  Future<List<KeyboardLayout>> listLayouts() async =>
      const <KeyboardLayout>[us, de, fr, jp, ru];

  @override
  Future<KeyboardLayout> getLayout() async {
    try {
      final pref = File(preferencePath);
      if (await pref.exists()) {
        return parseKeyboardConf(await pref.readAsString());
      }
    } catch (e) {
      debugPrint('keyboard: read pref failed: $e');
    }
    try {
      final etc = File(etcDefaultKeyboardPath);
      if (await etc.exists()) {
        return parseEtcDefaultKeyboard(await etc.readAsString());
      }
    } catch (e) {
      debugPrint('keyboard: read /etc/default/keyboard failed: $e');
    }
    return us;
  }

  @override
  Future<void> setLayout(KeyboardLayout layout, {bool restart = true}) async {
    final normalized = KeyboardLayout(
      id: layout.id.trim().isEmpty ? 'us' : layout.id.trim(),
      variant: layout.variant,
      options: layout.options,
      model: layout.model.trim().isEmpty
          ? _defaultModelFor(layout.id)
          : layout.model.trim(),
      displayName: layout.displayName ?? _displayNameFor(layout.id),
      softProfile: layout.softProfile.trim(),
    );
    final conf = encodeKeyboardConf(normalized);
    try {
      final f = File(preferencePath);
      await f.parent.create(recursive: true);
      await f.writeAsString(conf, flush: true);
      debugPrint('keyboard: persisted → $preferencePath');
    } catch (e) {
      debugPrint('keyboard: persist failed: $e');
      rethrow;
    }

    if (syncEtcDefault) {
      await _tryWriteEtcDefault(normalized);
    }

    if (restart && applyRestart) {
      await restartToApply();
    }
  }

  @override
  Future<void> restartToApply() async {
    final code = await restartHmi();
    if (code != 0) {
      debugPrint('keyboard: hmi restart exit $code');
    }
  }

  Future<void> _tryWriteEtcDefault(KeyboardLayout layout) async {
    final body = encodeEtcDefaultKeyboard(layout);
    try {
      final f = File(etcDefaultKeyboardPath);
      await f.writeAsString(body, flush: true);
      debugPrint('keyboard: synced → $etcDefaultKeyboardPath');
    } catch (e) {
      // Often read-only without privilege; pref alone is enough for restore/hmi-launch.
      debugPrint('keyboard: /etc/default/keyboard write soft-fail: $e');
    }
  }

  @override
  Future<void> dispose() async {}
}

/// Parse `layout=` / `variant=` / `options=` / `model=` keyboard.conf.
@visibleForTesting
KeyboardLayout parseKeyboardConf(String raw) {
  var layout = 'us';
  var variant = '';
  var options = '';
  var model = 'pc105';
  var softProfile = '';

  for (final line in raw.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }
    final eq = trimmed.indexOf('=');
    if (eq <= 0) {
      continue;
    }
    final key = trimmed.substring(0, eq).trim().toLowerCase();
    final value = trimmed.substring(eq + 1).trim();
    switch (key) {
      case 'layout':
      case 'xkblayout':
        layout = value.isEmpty ? 'us' : value;
      case 'variant':
      case 'xkbvariant':
        variant = value;
      case 'options':
      case 'xkboptions':
        options = value;
      case 'model':
      case 'xkbmodel':
        model = value.isEmpty ? 'pc105' : value;
      case 'profile':
      case 'soft':
      case 'softprofile':
        softProfile = value;
    }
  }

  return KeyboardLayout(
    id: layout,
    variant: variant,
    options: options,
    model: model,
    displayName: _displayNameFor(layout),
    softProfile: softProfile,
  );
}

@visibleForTesting
String encodeKeyboardConf(KeyboardLayout layout) {
  final buf = StringBuffer()
    ..write('layout=${layout.id}\n')
    ..write('variant=${layout.variant}\n')
    ..write('options=${layout.options}\n')
    ..write('model=${layout.model}\n');
  if (layout.softProfile.trim().isNotEmpty) {
    buf.write('profile=${layout.softProfile.trim()}\n');
  }
  return buf.toString();
}

@visibleForTesting
KeyboardLayout parseEtcDefaultKeyboard(String raw) {
  var layout = 'us';
  var variant = '';
  var options = '';
  var model = 'pc105';

  for (final line in raw.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }
    final eq = trimmed.indexOf('=');
    if (eq <= 0) {
      continue;
    }
    final key = trimmed.substring(0, eq).trim().toUpperCase();
    var value = trimmed.substring(eq + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    switch (key) {
      case 'XKBLAYOUT':
        layout = value.isEmpty ? 'us' : value;
      case 'XKBVARIANT':
        variant = value;
      case 'XKBOPTIONS':
        options = value;
      case 'XKBMODEL':
        model = value.isEmpty ? 'pc105' : value;
    }
  }

  return KeyboardLayout(
    id: layout,
    variant: variant,
    options: options,
    model: model,
    displayName: _displayNameFor(layout),
  );
}

@visibleForTesting
String encodeEtcDefaultKeyboard(KeyboardLayout layout) {
  return 'XKBMODEL="${layout.model}"\n'
      'XKBLAYOUT="${layout.id}"\n'
      'XKBVARIANT="${layout.variant}"\n'
      'XKBOPTIONS="${layout.options}"\n'
      'BACKSPACE="guess"\n';
}

String _defaultModelFor(String id) {
  final primary = id.split(',').first.trim().toLowerCase();
  return primary == 'jp' ? 'jp106' : 'pc105';
}

String? _displayNameFor(String id) {
  final primary = id.split(',').first.trim();
  return switch (primary) {
    'us' => 'ANSI US (QWERTY)',
    'de' => 'ISO DE (QWERTZ)',
    'fr' => 'ISO FR (AZERTY)',
    'jp' => 'JIS JP',
    'ru' => 'Russian',
    _ => null,
  };
}
