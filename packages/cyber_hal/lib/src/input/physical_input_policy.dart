import 'package:cyber_hal/src/linux/board_helper.dart';
import 'package:cyber_hal/src/linux/key_value_conf.dart';
import 'package:flutter/foundation.dart';

/// Key in [/var/lib/hal/input.conf] for physical keyboard policy.
const kPhysicalKeyboardEnabledKey = 'physical_keyboard_enabled';

/// Key in [/var/lib/hal/input.conf] for physical mouse policy.
const kPhysicalMouseEnabledKey = 'physical_mouse_enabled';

/// Parse enable flag from conf value; missing → [defaultEnabled].
bool parsePhysicalInputEnabled(String? raw, {bool defaultEnabled = true}) {
  if (raw == null || raw.isEmpty) {
    return defaultEnabled;
  }
  switch (raw.trim().toLowerCase()) {
    case '0':
    case 'false':
    case 'no':
    case 'off':
      return false;
    case '1':
    case 'true':
    case 'yes':
    case 'on':
      return true;
    default:
      return defaultEnabled;
  }
}

/// Encode enable flag for input.conf.
String encodePhysicalInputEnabled(bool enabled) => enabled ? '1' : '0';

/// Read enable flags from a parsed conf map.
PhysicalInputFlags physicalInputFlagsFromMap(
  Map<String, String> map, {
  bool defaultEnabled = true,
}) {
  return PhysicalInputFlags(
    keyboardEnabled: parsePhysicalInputEnabled(
      map[kPhysicalKeyboardEnabledKey],
      defaultEnabled: defaultEnabled,
    ),
    mouseEnabled: parsePhysicalInputEnabled(
      map[kPhysicalMouseEnabledKey],
      defaultEnabled: defaultEnabled,
    ),
  );
}

/// Immutable physical keyboard/mouse enable flags from [input.conf].
@immutable
final class PhysicalInputFlags {
  const PhysicalInputFlags({
    required this.keyboardEnabled,
    required this.mouseEnabled,
  });

  final bool keyboardEnabled;
  final bool mouseEnabled;

  static const enabled = PhysicalInputFlags(
    keyboardEnabled: true,
    mouseEnabled: true,
  );

  PhysicalInputFlags copyWith({
    bool? keyboardEnabled,
    bool? mouseEnabled,
  }) {
    return PhysicalInputFlags(
      keyboardEnabled: keyboardEnabled ?? this.keyboardEnabled,
      mouseEnabled: mouseEnabled ?? this.mouseEnabled,
    );
  }
}

/// Runtime policy for physical HID keyboard/mouse (OEM default + OS Settings).
final class PhysicalInputPolicy {
  PhysicalInputPolicy({
    this.preferencePath = '/var/lib/hal/input.conf',
    this.applyPolicyCommand = const <String>[],
    this.runHelper = defaultBoardHelperRunner,
  });

  final String preferencePath;
  final List<String> applyPolicyCommand;
  final Future<int> Function(String executable, List<String> arguments)
      runHelper;

  Future<PhysicalInputFlags> readFlags() async {
    final map = await readKeyValueConfFile(preferencePath);
    return physicalInputFlagsFromMap(map);
  }

  PhysicalInputFlags readFlagsSync() {
    final map = readKeyValueConfFileSync(preferencePath);
    return physicalInputFlagsFromMap(map);
  }

  Future<bool> isPhysicalKeyboardEnabled() async {
    return (await readFlags()).keyboardEnabled;
  }

  Future<bool> isPhysicalMouseEnabled() async {
    return (await readFlags()).mouseEnabled;
  }

  Future<void> writeFlags(PhysicalInputFlags flags) async {
    await upsertKeyValueConfFile(preferencePath, {
      kPhysicalKeyboardEnabledKey:
          encodePhysicalInputEnabled(flags.keyboardEnabled),
      kPhysicalMouseEnabledKey: encodePhysicalInputEnabled(flags.mouseEnabled),
    });
  }

  /// Persist [flags] and invoke board helper (udev + Weston refresh).
  Future<void> applyFlags(PhysicalInputFlags flags) async {
    await writeFlags(flags);
    if (applyPolicyCommand.isEmpty) {
      return;
    }
    final exe = applyPolicyCommand.first;
    final args = applyPolicyCommand.sublist(1);
    try {
      final code = await runHelper(exe, args);
      if (code != 0) {
        debugPrint('physical-input-policy: helper exit $code');
      }
    } catch (e) {
      debugPrint('physical-input-policy: helper failed: $e');
    }
  }
}
