import 'package:cyber_hal/output/load_profile.dart';
import 'package:cyber_hal/src/linux/board_helper.dart';
import 'package:cyber_hal/src/linux/key_value_conf.dart';
import 'package:cyber_hal/src/output/output_prefs.dart';
import 'package:flutter/foundation.dart';

/// Linux [LoadProfile]: read `power.conf`; set via `set-power-mode` helper.
final class LinuxLoadProfile implements LoadProfile {
  LinuxLoadProfile({
    this.preferencePath = OutputPrefs.powerConf,
    this.setPowerModeCommand = const <String>['set-power-mode'],
    BoardHelperRunner? runHelper,
  }) : runHelper = runHelper ?? defaultBoardHelperRunner;

  final String preferencePath;
  final List<String> setPowerModeCommand;
  final BoardHelperRunner runHelper;

  LoadProfileMode _mode = LoadProfileMode.performance;
  bool _warmed = false;

  @override
  Future<LoadProfileMode> getMode() async {
    await _ensureWarmed();
    return _mode;
  }

  @override
  Future<void> setMode(LoadProfileMode mode) async {
    final token = mode.wireName;
    if (setPowerModeCommand.isEmpty) {
      // Host/test path: persist conf only.
      await upsertKeyValueConfFile(preferencePath, {
        OutputPrefs.keyPowerMode: token,
      });
      _mode = mode;
      _warmed = true;
      return;
    }
    final exe = setPowerModeCommand.first;
    final args = <String>[
      ...setPowerModeCommand.sublist(1),
      token,
    ];
    final code = await runHelper(exe, args);
    if (code != 0) {
      debugPrint('load-profile: set-power-mode exit $code');
      return;
    }
    _mode = mode;
    _warmed = true;
    debugPrint('load-profile: applied $token');
  }

  Future<void> _ensureWarmed() async {
    if (_warmed) {
      return;
    }
    try {
      final map = await readKeyValueConfFile(preferencePath);
      final raw = map[OutputPrefs.keyPowerMode];
      _mode = LoadProfileMode.parse(raw);
    } catch (e) {
      debugPrint('load-profile: read failed: $e');
    }
    _warmed = true;
  }

  @override
  Future<void> dispose() async {}
}
