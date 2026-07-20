/// Fixed-order boot self-check items (lws-ui `BootSelfCheckItem`).
enum BootSelfCheckItem {
  controllerComm,
  pumpComm,
  gunComm,
  motorDriverTemp,
  gunMotorTemp,
  protectionMirrorTemp,
  collimatorTemp,
  wireFeederComm,
  cameraComm;

  /// English labels aligned with Monitor → Alarm Information tiles.
  String get label {
    switch (this) {
      case BootSelfCheckItem.controllerComm:
        return 'Controller Comm';
      case BootSelfCheckItem.pumpComm:
        return 'Pump Comm';
      case BootSelfCheckItem.gunComm:
        return 'Gun Head Comm';
      case BootSelfCheckItem.motorDriverTemp:
        return 'Motor Driver Temp';
      case BootSelfCheckItem.gunMotorTemp:
        return 'Gun Motor Temp';
      case BootSelfCheckItem.protectionMirrorTemp:
        return 'Protective Mirror Temp';
      case BootSelfCheckItem.collimatorTemp:
        return 'Collimator Temp';
      case BootSelfCheckItem.wireFeederComm:
        return 'Wire Feeder Comm';
      case BootSelfCheckItem.cameraComm:
        return 'Camera Comm';
    }
  }

  bool get isCamera => this == BootSelfCheckItem.cameraComm;

  bool get requiresControllerReady => !isCamera;
}

/// Terminal / in-progress status for one self-check row.
enum BootSelfCheckStatus {
  checking,
  pass,
  fail,
  skipped;

  String get label {
    switch (this) {
      case BootSelfCheckStatus.checking:
        return 'Checking…';
      case BootSelfCheckStatus.pass:
        return 'OK';
      case BootSelfCheckStatus.fail:
        return 'Fault';
      case BootSelfCheckStatus.skipped:
        return 'Skipped';
    }
  }

  bool get isTerminal =>
      this == BootSelfCheckStatus.pass ||
      this == BootSelfCheckStatus.fail ||
      this == BootSelfCheckStatus.skipped;
}
