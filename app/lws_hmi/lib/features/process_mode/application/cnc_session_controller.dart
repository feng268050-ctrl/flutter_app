import 'dart:async';

import 'package:cyber_hal/modbus.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';

/// CNC link status shown on step 1 of the connection guide (lws-ui
/// `communicationStatus`: 1 connecting, 2 success, 3 failed).
enum CncLinkStatus {
  connecting,
  success,
  failed,
}

/// Quick-mode CNC session: write process type, watch `machine.cnc_connected`,
/// open running overlay, exit back to continuous welding.
final class CncSessionController extends ChangeNotifier {
  CncSessionController(this.services);

  final AppServices services;

  static const Duration connectionTimeout = Duration(seconds: 10);
  static const String cncConnectedId = 'machine.cnc_connected';
  static const String processTypeId = 'control.process_type';

  bool active = false;
  bool runningOverlay = false;
  bool sessionDismissed = false;
  CncLinkStatus linkStatus = CncLinkStatus.connecting;
  String? lastMessage;
  bool busy = false;

  StreamSubscription<List<ModbusAttributeChange>>? _sub;
  Timer? _timeout;
  bool _started = false;

  /// Blocks Home/Back while the running overlay is up or CNC reports connected.
  bool get blocksNavigation =>
      active && (runningOverlay || linkStatus == CncLinkStatus.success);

  Future<void> enter() async {
    if (active) {
      return;
    }
    active = true;
    runningOverlay = false;
    sessionDismissed = false;
    linkStatus = CncLinkStatus.connecting;
    lastMessage = 'Checking connection…';
    notifyListeners();

    busy = true;
    notifyListeners();
    try {
      await services.ensureModbusLive();
      final ok = await services.modbus.writeAttribute(
        processTypeId,
        ProcessType.cncCutting.modbusProcessType,
      );
      if (!ok) {
        linkStatus = CncLinkStatus.failed;
        lastMessage = 'CNC connection failed';
        return;
      }
    } catch (e) {
      debugPrint('cnc-session: write CNC mode failed: $e');
      linkStatus = CncLinkStatus.failed;
      lastMessage = 'CNC connection failed';
      return;
    } finally {
      busy = false;
      notifyListeners();
    }

    await _ensureWatch();
    await _refreshConnectedBit();
    if (linkStatus == CncLinkStatus.success) {
      return;
    }
    _timeout?.cancel();
    _timeout = Timer(connectionTimeout, _onTimeout);
  }

  Future<void> leaveWithoutExitWrite() async {
    _cancelTimeout();
    await _cancelWatch();
    active = false;
    runningOverlay = false;
    sessionDismissed = false;
    linkStatus = CncLinkStatus.connecting;
    lastMessage = null;
    notifyListeners();
  }

  /// Close running overlay and return to the guide.
  ///
  /// [writeContinuous] matches Android: user exit writes continuous welding;
  /// device disconnect does not.
  Future<bool> exitToGuide({required bool writeContinuous}) async {
    sessionDismissed = true;
    runningOverlay = false;
    _cancelTimeout();
    linkStatus = CncLinkStatus.failed;
    lastMessage = null;
    notifyListeners();

    if (!writeContinuous) {
      return true;
    }

    busy = true;
    notifyListeners();
    try {
      final ok = await services.modbus.writeAttribute(
        processTypeId,
        ProcessType.continuousWelding.modbusProcessType,
      );
      if (!ok) {
        lastMessage = 'CNC connection failed';
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('cnc-session: exit write failed: $e');
      lastMessage = 'CNC connection failed';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _ensureWatch() async {
    if (_started) {
      return;
    }
    _started = true;
    try {
      final stream = await services.modbus.watchAttributes(
        ids: const [cncConnectedId],
      );
      _sub = stream.listen(_onChanges);
    } catch (e) {
      debugPrint('cnc-session: watch failed: $e');
    }
  }

  Future<void> _cancelWatch() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }

  void _cancelTimeout() {
    _timeout?.cancel();
    _timeout = null;
  }

  Future<void> _refreshConnectedBit() async {
    try {
      final status = await services.modbus.readGroup('status');
      _applyConnected(_isOn(status[cncConnectedId]));
    } catch (e) {
      debugPrint('cnc-session: status read failed: $e');
    }
  }

  void _onChanges(List<ModbusAttributeChange> changes) {
    for (final c in changes) {
      if (c.id != cncConnectedId) {
        continue;
      }
      _applyConnected(_isOn(c.value));
    }
  }

  void _applyConnected(bool connected) {
    if (!active) {
      return;
    }
    if (!connected) {
      sessionDismissed = false;
      if (runningOverlay) {
        unawaited(exitToGuide(writeContinuous: false));
      }
      return;
    }
    if (sessionDismissed) {
      return;
    }
    _cancelTimeout();
    if (linkStatus != CncLinkStatus.success || !runningOverlay) {
      linkStatus = CncLinkStatus.success;
      lastMessage = 'CNC connected';
      runningOverlay = true;
      notifyListeners();
    }
  }

  void _onTimeout() {
    _timeout = null;
    if (!active || runningOverlay || linkStatus == CncLinkStatus.success) {
      return;
    }
    linkStatus = CncLinkStatus.failed;
    lastMessage = 'CNC connection failed';
    notifyListeners();
  }

  static bool _isOn(Object? value) => value == true || value == 1;

  @visibleForTesting
  void applyConnectedForTest(bool connected) => _applyConnected(connected);

  @override
  void dispose() {
    _cancelTimeout();
    unawaited(_cancelWatch());
    super.dispose();
  }
}
