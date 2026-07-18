import 'dart:async';
import 'dart:io';

import 'package:bluez/bluez.dart';
import 'package:cyber_hal/src/linux/lws_trace.dart';

/// Board-specific Bluetooth stack / A2DP / agent (D22).
///
/// Portable HAL uses BlueZ D-Bus for devices + in-controller HOGP/evdev heal;
/// this port owns Process bring-up and optional A2DP helpers.
abstract class BtStack {
  Future<void> startStack();
  Future<void> stopStack();
  Future<void> startA2dpSink();
  Future<void> stopA2dpSink();
  Future<void> ensureAgent();
  Future<void> stopAgent();
  Future<void> setAlias();
}

/// Optional combo-module / UART HCI firmware before BlueZ adapter exists.
///
/// Default [NoopBtModemPort] assumes HCI is already up. Inject [BtModemPort]
/// (`helpers.bt_modem`) when UART/SDIO combo must attach before HCI — same
/// class of requirement as Wi‑Fi modem; see `docs/network-stack.md` and
/// `docs/hal-portability.md`.
abstract class BtModemPort {
  Future<void> ensureRadioHardware();
}

final class NoopBtModemPort implements BtModemPort {
  const NoopBtModemPort();

  @override
  Future<void> ensureRadioHardware() async {}
}

final class ProcessBtModemPort implements BtModemPort {
  ProcessBtModemPort({
    this.command = const <String>[],
    Future<ProcessResult> Function(String exe, List<String> args)? run,
  }) : _run = run ?? ((exe, args) => Process.run(exe, args));

  final List<String> command;
  final Future<ProcessResult> Function(String exe, List<String> args) _run;

  @override
  Future<void> ensureRadioHardware() async {
    if (command.isEmpty) {
      return;
    }
    lwsTrace('bt-modem: ${command.join(' ')}');
    final r = await _run(command.first, command.sublist(1));
    if (r.exitCode != 0) {
      // Soft-fail like overlay bt-stack-up (Wi‑Fi side may already own bring-up).
      lwsTrace('bt-modem soft-fail: ${r.stderr}');
    }
  }
}

/// Portable BT stack: systemd bluetooth.service + BlueZ Adapter D-Bus.
///
/// Does **not** call `/usr/libexec/bluetooth/bt-stack-*.sh`. Optional [modem]
/// covers combo firmware only. A2DP / agent remain no-op unless board helpers
/// are injected via [ScriptBtStack] or subclass. HOGP/evdev heal lives in
/// [LinuxBluezBluetoothController].
final class SystemdBluezStack implements BtStack {
  SystemdBluezStack({
    this.bluetoothUnit = 'bluetooth.service',
    this.alias = 'lws-hmi',
    this.aliasFilePath = '/var/lib/bluetooth/adapter-alias',
    this.a2dpUp = const <String>[],
    this.a2dpDown = const <String>[],
    BtModemPort? modem,
    BlueZClient Function()? clientFactory,
    Future<ProcessResult> Function(String exe, List<String> args)? run,
  })  : modem = modem ?? const NoopBtModemPort(),
        _clientFactory = clientFactory,
        _run = run ?? ((exe, args) => Process.run(exe, args));

  final String bluetoothUnit;
  final String alias;
  final String aliasFilePath;
  final List<String> a2dpUp;
  final List<String> a2dpDown;
  final BtModemPort modem;
  final BlueZClient Function()? _clientFactory;
  final Future<ProcessResult> Function(String exe, List<String> args) _run;

  @override
  Future<void> startStack() async {
    await modem.ensureRadioHardware();
    await _run('systemctl', <String>['reset-failed', bluetoothUnit]);
    final active = await _run('systemctl', <String>['is-active', bluetoothUnit]);
    if ('${active.stdout}'.trim() != 'active') {
      final start = await _run('systemctl', <String>['start', bluetoothUnit]);
      if (start.exitCode != 0) {
        final restart =
            await _run('systemctl', <String>['restart', bluetoothUnit]);
        if (restart.exitCode != 0) {
          throw StateError(
            '$bluetoothUnit failed: ${restart.stderr}',
          );
        }
      }
    }
    await _waitAdapter();
    await setAlias();
    // Pairable on; discoverable stays off until user enters pairing.
    await _withAdapter((a) async {
      if (!a.pairable) {
        await a.setPairable(true);
      }
    });
  }

  @override
  Future<void> stopStack() async {
    await stopA2dpSink();
    await _run('systemctl', <String>['stop', bluetoothUnit]);
  }

  @override
  Future<void> startA2dpSink() async {
    if (a2dpUp.isEmpty) {
      return;
    }
    final r = await _run(a2dpUp.first, a2dpUp.sublist(1));
    if (r.exitCode != 0) {
      throw StateError('a2dp up failed: ${r.stderr}');
    }
  }

  @override
  Future<void> stopA2dpSink() async {
    if (a2dpDown.isEmpty) {
      return;
    }
    await _run(a2dpDown.first, a2dpDown.sublist(1));
  }

  @override
  Future<void> ensureAgent() async {
    // HMI registers its own BlueZ agent over D-Bus.
  }

  @override
  Future<void> stopAgent() async {}

  @override
  Future<void> setAlias() async {
    var name = alias;
    try {
      final f = File(aliasFilePath);
      if (await f.exists()) {
        final v = (await f.readAsString()).trim();
        if (v.isNotEmpty) {
          name = v;
        }
      }
    } catch (_) {}
    await _withAdapter((a) async {
      await a.setAlias(name);
    });
  }

  Future<void> _waitAdapter() async {
    for (var i = 0; i < 60; i++) {
      try {
        final ok = await _withAdapter((_) async => true);
        if (ok) {
          return;
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  Future<T> _withAdapter<T>(Future<T> Function(BlueZAdapter a) fn) async {
    final owned = _clientFactory == null;
    final client = _clientFactory?.call() ?? BlueZClient();
    try {
      if (owned) {
        await client.connect();
      }
      if (client.adapters.isEmpty) {
        throw StateError('No BlueZ adapter');
      }
      return await fn(client.adapters.first);
    } finally {
      if (owned) {
        try {
          await client.close();
        } catch (_) {}
      }
    }
  }
}

/// Legacy ynh960 adapter: `/usr/libexec/bluetooth/bt-*` scripts.
///
/// Retained for transition; **not** the HAL default ([SystemdBluezStack] is).
final class ScriptBtStack implements BtStack {
  ScriptBtStack({
    this.stackUp = const <String>[],
    this.stackDown = const <String>[],
    this.a2dpUp = const <String>[],
    this.a2dpDown = const <String>[],
    this.ensureAgentCmd = const <String>[],
    this.stopAgentCmd = const <String>[],
    this.setAliasCmd = const <String>[],
    Future<ProcessResult> Function(String exe, List<String> args)? run,
  }) : _run = run ?? ((exe, args) => Process.run(exe, args));

  final List<String> stackUp;
  final List<String> stackDown;
  final List<String> a2dpUp;
  final List<String> a2dpDown;
  final List<String> ensureAgentCmd;
  final List<String> stopAgentCmd;
  final List<String> setAliasCmd;
  final Future<ProcessResult> Function(String exe, List<String> args) _run;

  Future<void> _exec(List<String> cmd) async {
    if (cmd.isEmpty) {
      return;
    }
    final r = await _run(cmd.first, cmd.sublist(1));
    if (r.exitCode != 0) {
      throw StateError('${cmd.first} failed: ${r.stderr}');
    }
  }

  @override
  Future<void> startStack() => _exec(stackUp);

  @override
  Future<void> stopStack() => _exec(stackDown);

  @override
  Future<void> startA2dpSink() => _exec(a2dpUp);

  @override
  Future<void> stopA2dpSink() => _exec(a2dpDown);

  @override
  Future<void> ensureAgent() => _exec(ensureAgentCmd);

  @override
  Future<void> stopAgent() => _exec(stopAgentCmd);

  @override
  Future<void> setAlias() => _exec(setAliasCmd);
}
