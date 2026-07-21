import 'dart:async';

import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/monitor/domain/active_alarm.dart';
import 'package:lws_hmi/features/warn_alarm/application/alarm_monitor_state.dart';
import 'package:lws_hmi/features/warn_alarm/catalog/product_alarm_catalog.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/boot_self_check_warn_gate.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/demo_alarm_command_watcher.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/file_alarm_log_repository.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/modbus_alarm_attribute_adapter.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/warn_alarm_sound.dart';
import 'package:lws_hmi/features/warn_alarm/presentation/cyber_ui_warn_presentation.dart';

/// Owns [WarnAlarmCoordinator] + App adapters for the process lifetime.
final class WarnAlarmController {
  WarnAlarmController({
    required this.services,
    required GlobalKey<NavigatorState> navigatorKey,
    AlarmCodeCatalog? catalog,
    AlarmLogRepository? logRepository,
    WarnGate? gate,
    WarnAlarmSound? sound,
  })  : catalog = catalog ?? ProductAlarmCatalog.seed(),
        log = logRepository ?? FileAlarmLogRepository(),
        _sound = sound ?? WarnAlarmSound(services.audio) {
    _presentation = CyberUiWarnPresentation(
      navigatorKey: navigatorKey,
      stopWarnSound: () => _sound.stop(),
    );
    _adapter = ModbusAlarmAttributeAdapter(
      modbus: services.modbus,
      ensureLive: services.ensureModbusLive,
    );
    coordinator = WarnAlarmCoordinator(
      catalog: this.catalog,
      signals: _adapter,
      presentation: _presentation,
      log: log,
      gate: gate ?? const BootSelfCheckWarnGate(),
    );
    _demoAlarmWatcher = DemoAlarmCommandWatcher(
      onTrigger: triggerDemoAlarm,
      onClean: clearDemoAlarms,
    );
    _presentation.onClosed = (code) {
      unawaited(() async {
        // Ack before pump/sync so SFX stops on Confirm (fault may still be active).
        await coordinator.acknowledgeOperator(code);
        await coordinator.onPresentationClosed(code);
        _publishActive();
        _syncWarnSound();
      }());
    };
  }

  final AppServices services;
  final AlarmCodeCatalog catalog;
  final AlarmLogRepository log;
  final WarnAlarmSound _sound;

  /// Live Alarm Information state (Modbus via this alarm stack).
  final AlarmMonitorState monitor = AlarmMonitorState();

  late final ModbusAlarmAttributeAdapter _adapter;
  late final CyberUiWarnPresentation _presentation;
  late final WarnAlarmCoordinator coordinator;
  late final DemoAlarmCommandWatcher _demoAlarmWatcher;

  StreamSubscription? _monitorSub;
  StreamSubscription? _healthSub;
  StreamSubscription? _signalSub;
  Timer? _activePoll;
  bool _started = false;

  Stream<List<AlarmLogEntry>> watchHistory({int? limit}) =>
      log.watch(limit: limit);

  Future<void> clearHistory() => log.clear();

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    // Listen before adapter emits: broadcast streams drop events with no listener.
    await coordinator.start();
    _monitorSub = _adapter.monitorChanges.listen((changes) {
      monitor.applyChanges(changes);
      _publishActive();
    });
    _healthSub = _adapter.healthChanges.listen((h) {
      monitor.applyHealth(h);
      _syncWarnSound();
    });
    // Appear / clear / code-change drive SFX (not dialog lifecycle).
    _signalSub = _adapter.events.listen((_) {
      _publishActive();
      _syncWarnSound();
    });
    await _adapter.start();
    _demoAlarmWatcher.start();
    _publishActive();
    _syncWarnSound();
    // Episodes can change without monitor attribute batches (ack/recover).
    _activePoll?.cancel();
    _activePoll = Timer.periodic(const Duration(milliseconds: 400), (_) {
      _publishActive();
      _syncWarnSound();
    });
  }

  /// Host `make alarm CODE=…` — demo episode + warn dialog (catalog code).
  Future<void> triggerDemoAlarm(String code) async {
    final future = coordinator.armDemoEpisode(code);
    // Yield so rising can insert the episode before SFX sync.
    await Future<void>.delayed(Duration.zero);
    _publishActive();
    _syncWarnSound();
    await future;
    _publishActive();
    _syncWarnSound();
  }

  /// Host `make alarm-clean` — clear restrictions; visible popup unchanged.
  Future<void> clearDemoAlarms() async {
    await coordinator.clearAllForDebug();
    _publishActive();
    _syncWarnSound();
  }

  void _publishActive() {
    final rows = <ActiveAlarm>[];
    for (final ep in coordinator.episodes.values) {
      if (!ep.faultActive) {
        continue;
      }
      final entry = catalog.resolve(ep.code);
      rows.add(
        ActiveAlarm(
          id: ep.code,
          code: ep.code,
          label: entry.displayLabel,
        ),
      );
    }
    rows.sort((a, b) => a.code.compareTo(b.code));
    monitor.setActiveAlarms(rows);
  }

  /// SFX lifecycle: appear / code-change / clear / operator Confirm.
  ///
  /// Play while a fault is active and **not** operator-acked. Confirm stops
  /// sound even if the fault bit remains; reminder re-open starts it again.
  /// Same alerting code → [WarnAlarmSound.ensurePlaying] no-ops (no restart).
  void _syncWarnSound() {
    final alertingCodes = coordinator.episodes.entries
        .where(
          (e) =>
              e.value.faultActive &&
              e.value.phase != WarnEpisodePhase.operatorAcked,
        )
        .map((e) => e.key)
        .toList()
      ..sort();
    if (alertingCodes.isEmpty) {
      if (_sound.isActive) {
        unawaited(_sound.stop());
      }
      return;
    }
    final showing = coordinator.showingCode;
    final code = (showing != null && alertingCodes.contains(showing))
        ? showing
        : alertingCodes.first;
    unawaited(_sound.ensurePlaying(code));
  }

  /// After boot self-check (or any gate) clears — present parked / missed episodes.
  Future<void> onPresentationGateOpened() => coordinator.flushPresentation();

  Future<void> dispose() async {
    _activePoll?.cancel();
    await _demoAlarmWatcher.dispose();
    await _monitorSub?.cancel();
    await _healthSub?.cancel();
    await _signalSub?.cancel();
    await coordinator.dispose();
    await _adapter.dispose();
    await _sound.dispose();
    monitor.dispose();
    if (log is FileAlarmLogRepository) {
      await (log as FileAlarmLogRepository).dispose();
    }
  }
}
