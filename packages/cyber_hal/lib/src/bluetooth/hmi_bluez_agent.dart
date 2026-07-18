import 'dart:async';
import 'dart:io';

import 'package:bluez/bluez.dart';
import 'package:flutter/foundation.dart';
import 'package:cyber_hal/src/bluetooth/bluetooth_models.dart';

typedef HmiBluezAgentAutoPolicy = bool Function();
typedef HmiBluezAgentEmit = void Function(BluetoothPairingChallenge? challenge);

/// BlueZ Agent1 owned by the HMI while the adapter is on.
class HmiBluezAgent extends BlueZAgent {
  HmiBluezAgent({
    required this.shouldAutoConfirm,
    required this.onChallenge,
  });

  final HmiBluezAgentAutoPolicy shouldAutoConfirm;
  final HmiBluezAgentEmit onChallenge;

  String? _activeId;
  Completer<bool>? _decision;
  Completer<int>? _passkey;
  Completer<String>? _pin;

  BluetoothPairingChallenge? get activeChallenge {
    final id = _activeId;
    if (id == null) {
      return null;
    }
    // Reconstruct is not stored; controller keeps snapshot.
    return null;
  }

  Future<void> respond({
    required String challengeId,
    required bool accept,
    int? passkey,
    String? pinCode,
  }) async {
    if (_activeId != challengeId) {
      throw BluetoothOperationException(
        'Stale or unmatched pairing challenge',
        address: challengeId,
      );
    }
    if (_passkey != null && !_passkey!.isCompleted) {
      if (!accept || passkey == null) {
        _passkey!.completeError(StateError('rejected'));
      } else {
        _passkey!.complete(passkey);
      }
      return;
    }
    if (_pin != null && !_pin!.isCompleted) {
      if (!accept || pinCode == null || pinCode.isEmpty) {
        _pin!.completeError(StateError('rejected'));
      } else {
        _pin!.complete(pinCode);
      }
      return;
    }
    if (_decision != null && !_decision!.isCompleted) {
      _decision!.complete(accept);
    }
  }

  void _clear() {
    _activeId = null;
    _decision = null;
    _passkey = null;
    _pin = null;
    onChallenge(null);
  }

  BluetoothPairingChallenge _make({
    required BlueZDevice device,
    required BluetoothPairingChallengeKind kind,
    int? passkey,
    String? pinCode,
    String? serviceUuid,
    int? enteredDigits,
  }) {
    final id =
        '${device.address}-${kind.name}-${DateTime.now().microsecondsSinceEpoch}';
    _activeId = id;
    return BluetoothPairingChallenge(
      id: id,
      address: device.address.toUpperCase(),
      name: device.alias.isNotEmpty ? device.alias : device.name,
      kind: kind,
      passkey: passkey,
      pinCode: pinCode,
      serviceUuid: serviceUuid,
      enteredDigits: enteredDigits,
    );
  }

  Future<BlueZAgentResponse> _awaitDecision(
    BluetoothPairingChallenge challenge,
  ) async {
    onChallenge(challenge);
    _decision = Completer<bool>();
    try {
      final accept = await _decision!.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () => false,
      );
      return accept
          ? BlueZAgentResponse.success()
          : BlueZAgentResponse.rejected();
    } catch (_) {
      return BlueZAgentResponse.rejected();
    } finally {
      _clear();
    }
  }

  @override
  Future<void> displayPasskey(
    BlueZDevice device,
    int passkey,
    int entered,
  ) async {
    debugPrint(
      'bt-agent: DisplayPasskey ${device.address} passkey=$passkey entered=$entered',
    );
    stderr.writeln(
      'bt-agent: DisplayPasskey ${device.address} passkey=$passkey entered=$entered',
    );
    // Same bonding session — update digits in place so the UI stays on one card.
    final existing = _activeId;
    final challenge = BluetoothPairingChallenge(
      id: existing ??
          '${device.address}-displayPasskey-${DateTime.now().microsecondsSinceEpoch}',
      address: device.address.toUpperCase(),
      name: device.alias.isNotEmpty ? device.alias : device.name,
      kind: BluetoothPairingChallengeKind.displayPasskey,
      passkey: passkey,
      enteredDigits: entered,
    );
    _activeId = challenge.id;
    onChallenge(challenge);
    // Keyboard types the code; empty D-Bus reply already sent by AgentObject.
  }

  @override
  Future<BlueZAgentResponse> displayPinCode(
    BlueZDevice device,
    String pinCode,
  ) async {
    debugPrint('bt-agent: DisplayPinCode ${device.address}');
    final challenge = _make(
      device: device,
      kind: BluetoothPairingChallengeKind.displayPinCode,
      pinCode: pinCode,
    );
    onChallenge(challenge);
    return BlueZAgentResponse.success();
  }

  @override
  Future<BlueZAgentResponse> requestConfirmation(
    BlueZDevice device,
    int passkey,
  ) async {
    debugPrint(
      'bt-agent: RequestConfirmation ${device.address} passkey=$passkey '
      'auto=${shouldAutoConfirm()}',
    );
    stderr.writeln(
      'bt-agent: RequestConfirmation ${device.address} passkey=$passkey '
      'auto=${shouldAutoConfirm()}',
    );
    if (shouldAutoConfirm()) {
      return BlueZAgentResponse.success();
    }
    return _awaitDecision(
      _make(
        device: device,
        kind: BluetoothPairingChallengeKind.confirm,
        passkey: passkey,
      ),
    );
  }

  @override
  Future<BlueZAgentResponse> requestAuthorization(BlueZDevice device) async {
    debugPrint(
      'bt-agent: RequestAuthorization ${device.address} auto=${shouldAutoConfirm()}',
    );
    stderr.writeln(
      'bt-agent: RequestAuthorization ${device.address} auto=${shouldAutoConfirm()}',
    );
    if (shouldAutoConfirm()) {
      return BlueZAgentResponse.success();
    }
    return _awaitDecision(
      _make(
        device: device,
        kind: BluetoothPairingChallengeKind.requestAuthorization,
      ),
    );
  }

  @override
  Future<BlueZAgentResponse> authorizeService(
    BlueZDevice device,
    BlueZUUID uuid,
  ) async {
    final u = uuid.toString().toLowerCase();
    final hid = u.contains('1812') || u.contains('1124');
    debugPrint(
      'bt-agent: AuthorizeService ${device.address} $uuid auto=${shouldAutoConfirm() || hid}',
    );
    // HOGP/HID profiles must not block behind a Demo confirm dialog mid-pair.
    if (shouldAutoConfirm() || hid) {
      return BlueZAgentResponse.success();
    }
    return _awaitDecision(
      _make(
        device: device,
        kind: BluetoothPairingChallengeKind.authorizeService,
        serviceUuid: uuid.toString(),
      ),
    );
  }

  @override
  Future<BlueZAgentPasskeyResponse> requestPasskey(BlueZDevice device) async {
    debugPrint('bt-agent: RequestPasskey ${device.address}');
    final challenge = _make(
      device: device,
      kind: BluetoothPairingChallengeKind.requestPasskey,
    );
    onChallenge(challenge);
    _passkey = Completer<int>();
    try {
      final value = await _passkey!.future.timeout(
        const Duration(seconds: 60),
      );
      return BlueZAgentPasskeyResponse.success(value);
    } catch (_) {
      return BlueZAgentPasskeyResponse.rejected();
    } finally {
      _clear();
    }
  }

  @override
  Future<BlueZAgentPinCodeResponse> requestPinCode(BlueZDevice device) async {
    debugPrint('bt-agent: RequestPinCode ${device.address}');
    final challenge = _make(
      device: device,
      kind: BluetoothPairingChallengeKind.requestPinCode,
    );
    onChallenge(challenge);
    _pin = Completer<String>();
    try {
      final value = await _pin!.future.timeout(const Duration(seconds: 60));
      return BlueZAgentPinCodeResponse.success(value);
    } catch (_) {
      return BlueZAgentPinCodeResponse.rejected();
    } finally {
      _clear();
    }
  }

  @override
  Future<void> cancel() async {
    if (_decision != null && !_decision!.isCompleted) {
      _decision!.complete(false);
    }
    if (_passkey != null && !_passkey!.isCompleted) {
      _passkey!.completeError(StateError('canceled'));
    }
    if (_pin != null && !_pin!.isCompleted) {
      _pin!.completeError(StateError('canceled'));
    }
    _clear();
  }

  @override
  Future<void> release() async {
    await cancel();
  }
}
