import 'dart:async';

import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';

/// Shared Feed/Retract pointer protocol for Quick and Engineer panels.
///
/// Short press → 500ms pulse. Hold ≥500ms starts continuous motion; Feed
/// latches after 3s total and stops on the next tap; Retract runs only while
/// pressed.
final class ManualWireGesture {
  ManualWireGesture({
    required this.controller,
    required this.retract,
    required this.isEnabled,
    required this.isActive,
    required this.onMessage,
    required this.onVisualChanged,
  });

  final DeviceControlController controller;
  final bool retract;
  final bool Function() isEnabled;
  final bool Function() isActive;
  final void Function(String message) onMessage;
  final void Function() onVisualChanged;

  Timer? _holdTimer;
  Timer? _latchTimer;
  Timer? _pulseTimer;
  bool pressed = false;
  bool _runningFromHold = false;
  bool _latchedFeed = false;

  void dispose() {
    _holdTimer?.cancel();
    _latchTimer?.cancel();
    _pulseTimer?.cancel();
    if (_runningFromHold && !_latchedFeed) {
      unawaited(controller.stopWire());
    }
  }

  void pointerDown() {
    if (!isEnabled()) {
      return;
    }
    if (!retract && isActive()) {
      pressed = true;
      onVisualChanged();
      return;
    }
    pressed = true;
    _runningFromHold = false;
    _latchedFeed = false;
    _holdTimer = Timer(DeviceControlTiming.wireHoldToRun, () async {
      if (!pressed) {
        return;
      }
      final error = await controller.startWire(retract: retract);
      if (error != null) {
        onMessage(controller.lastError ?? error.message);
        return;
      }
      _runningFromHold = true;
      if (!retract) {
        _latchTimer = Timer(
          DeviceControlTiming.wireFeedLatchDelay -
              DeviceControlTiming.wireHoldToRun,
          () {
            if (pressed) {
              _latchedFeed = true;
              onMessage('Continuous feed');
            }
          },
        );
      }
      onVisualChanged();
    });
    onVisualChanged();
  }

  void pointerUp() {
    if (!pressed) {
      return;
    }
    pressed = false;
    _holdTimer?.cancel();
    _holdTimer = null;
    _latchTimer?.cancel();
    _latchTimer = null;

    if (!isEnabled()) {
      onVisualChanged();
      return;
    }

    if (!retract && isActive()) {
      unawaited(_stopWithMessage('Feed stopped'));
    } else if (_runningFromHold) {
      if (!_latchedFeed || retract) {
        unawaited(
          _stopWithMessage(retract ? 'Retract stopped' : 'Feed stopped'),
        );
      }
    } else {
      unawaited(_pulse());
    }
    onVisualChanged();
  }

  Future<void> _pulse() async {
    final error = await controller.startWire(retract: retract);
    if (error != null) {
      onMessage(controller.lastError ?? error.message);
      return;
    }
    _pulseTimer?.cancel();
    _pulseTimer = Timer(DeviceControlTiming.wirePulseDuration, () {
      unawaited(controller.stopWire());
    });
  }

  Future<void> _stopWithMessage(String message) async {
    final error = await controller.stopWire();
    if (error != null) {
      onMessage(controller.lastError ?? error.message);
      return;
    }
    onMessage(message);
  }
}
