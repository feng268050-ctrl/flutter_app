import 'package:lws_hmi/l10n/app_localizations.dart';

/// Fixed-order boot self-check items (Modbus alarm-information aligned).
/// Camera Comm is owned by the async IP-camera product session, not self-check.
enum BootSelfCheckItem {
  controllerComm,
  pumpComm,
  gunComm,
  motorDriverTemp,
  gunMotorTemp,
  protectionMirrorTemp,
  collimatorTemp,
  wireFeederComm;

  String labelFor(AppLocalizations l10n) {
    switch (this) {
      case BootSelfCheckItem.controllerComm:
        return l10n.bootSelfCheckControllerComm;
      case BootSelfCheckItem.pumpComm:
        return l10n.pumpStatusText;
      case BootSelfCheckItem.gunComm:
        return l10n.gunHeadCommunicationText;
      case BootSelfCheckItem.motorDriverTemp:
        return l10n.motorDriverTempLabel;
      case BootSelfCheckItem.gunMotorTemp:
        return l10n.motorTempLabel;
      case BootSelfCheckItem.protectionMirrorTemp:
        return l10n.protectiveMirrorTempLabel;
      case BootSelfCheckItem.collimatorTemp:
        return l10n.collimatorTempLabel;
      case BootSelfCheckItem.wireFeederComm:
        return l10n.wireFeedingMachineCommunicationText;
    }
  }

  bool get requiresControllerReady => true;
}

/// Terminal / in-progress status for one self-check row.
enum BootSelfCheckStatus {
  checking,
  pass,
  fail,
  skipped;

  String labelFor(AppLocalizations l10n) {
    switch (this) {
      case BootSelfCheckStatus.checking:
        return l10n.bootSelfCheckStatusChecking;
      case BootSelfCheckStatus.pass:
        return l10n.bootSelfCheckStatusPass;
      case BootSelfCheckStatus.fail:
        return l10n.bootSelfCheckStatusFail;
      case BootSelfCheckStatus.skipped:
        return l10n.bootSelfCheckStatusSkipped;
    }
  }

  bool get isTerminal =>
      this == BootSelfCheckStatus.pass ||
      this == BootSelfCheckStatus.fail ||
      this == BootSelfCheckStatus.skipped;
}
