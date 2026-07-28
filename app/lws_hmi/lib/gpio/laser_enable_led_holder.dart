import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';

/// Work-screen Laser Enable + process type for RGB green rules
/// (lws-ui `LaserEnableStateHolder`).
///
/// [workModelWireValue] uses [ProcessType.wireValue] (CNC Cut = 5), not Modbus
/// `control.process_type` (CNC = 4).
final class LaserEnableLedHolder extends ChangeNotifier {
  LaserEnableLedHolder._();

  static final LaserEnableLedHolder instance = LaserEnableLedHolder._();

  bool _laserEnableActive = false;
  int _workModelWireValue = ProcessType.continuousWelding.wireValue;

  bool get laserEnableActive => _laserEnableActive;

  int get workModelWireValue => _workModelWireValue;

  bool get isCncCut =>
      _workModelWireValue == ProcessType.cncCutting.wireValue;

  void setWorkModel(ProcessType type) {
    setWorkModelWireValue(type.wireValue);
  }

  void setWorkModelWireValue(int wireValue) {
    if (_workModelWireValue == wireValue) {
      return;
    }
    _workModelWireValue = wireValue;
    notifyListeners();
  }

  void setActive(bool active, {ProcessType? workModel}) {
    final nextModel = workModel?.wireValue ?? _workModelWireValue;
    if (_laserEnableActive == active && _workModelWireValue == nextModel) {
      return;
    }
    _laserEnableActive = active;
    _workModelWireValue = nextModel;
    notifyListeners();
  }

  /// Clears enable only; work model stays (lws-ui `clearLaserEnable`).
  void clearLaserEnable() {
    if (!_laserEnableActive) {
      return;
    }
    _laserEnableActive = false;
    notifyListeners();
  }

  void clear() {
    if (!_laserEnableActive &&
        _workModelWireValue == ProcessType.continuousWelding.wireValue) {
      return;
    }
    _laserEnableActive = false;
    _workModelWireValue = ProcessType.continuousWelding.wireValue;
    notifyListeners();
  }
}
