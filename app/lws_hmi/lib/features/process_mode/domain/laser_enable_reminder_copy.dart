import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Which work-mode shell opened the laser-enable Important Reminder.
enum LaserEnableReminderSession { quick, engineer }

/// Process-lifetime suppress for the laser-enable reminder (not persisted).
///
/// Matches lws-ui `ReminderExactBuilder` keyed by Quick vs Engineer session.
abstract final class LaserEnableReminderGate {
  static bool _quickSuppressed = false;
  static bool _engineerSuppressed = false;

  static bool isSuppressed(LaserEnableReminderSession session) {
    return switch (session) {
      LaserEnableReminderSession.quick => _quickSuppressed,
      LaserEnableReminderSession.engineer => _engineerSuppressed,
    };
  }

  static void suppress(LaserEnableReminderSession session) {
    switch (session) {
      case LaserEnableReminderSession.quick:
        _quickSuppressed = true;
      case LaserEnableReminderSession.engineer:
        _engineerSuppressed = true;
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _quickSuppressed = false;
    _engineerSuppressed = false;
  }
}

/// Mode-specific copy + illustrations for the Important Reminder dialog.
abstract final class LaserEnableReminderCopy {
  /// Card 2 tip (lws-ui `LaserEnableReminderCopy.nozzleTipResId`).
  static String nozzleTip(ProcessType processType, AppLocalizations l10n) {
    return switch (processType) {
      ProcessType.handCutting || ProcessType.cncCutting =>
        l10n.laserEnableReminderNozzleCut,
      ProcessType.weldCleaning || ProcessType.wideCleaning =>
        l10n.laserEnableReminderNozzleClean,
      _ => l10n.laserEnableReminderNozzleWeld,
    };
  }

  static String nozzleAsset(ProcessType processType) {
    return switch (processType) {
      ProcessType.handCutting || ProcessType.cncCutting =>
        ProcessModeAssets.laserReminderNozzleCut,
      ProcessType.weldCleaning =>
        ProcessModeAssets.laserReminderNozzleWeldPathClean,
      ProcessType.wideCleaning =>
        ProcessModeAssets.laserReminderNozzleUltraWideClean,
      _ => ProcessModeAssets.laserReminderNozzleWeld,
    };
  }

  /// Third card (focus scale) is shown only for continuous / spot weld.
  ///
  /// Cleaning and hand cutting leave it blank; CNC is out of Quick laser UI.
  static bool showsFocusScale(ProcessType processType) {
    return processType == ProcessType.continuousWelding ||
        processType == ProcessType.spotWelding;
  }

  static int parseFocusScaleRef(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 0;
    }
    return int.tryParse(raw.trim()) ?? 0;
  }
}
