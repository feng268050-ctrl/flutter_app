import 'dart:async';

import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:cyber_hal/ip_camera.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/monitor/domain/active_alarm.dart';
import 'package:lws_hmi/features/settings/application/dangerous_operations_settings.dart';
import 'package:lws_hmi/features/settings/application/laser_alarm_policy.dart';
import 'package:lws_hmi/features/settings/application/laser_work_guard.dart';
import 'package:lws_hmi/features/process_mode/domain/laser_enable_preflight.dart';
import 'package:lws_hmi/features/warn_alarm/application/alarm_monitor_state.dart';
import 'package:lws_hmi/features/warn_alarm/catalog/product_alarm_catalog.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/boot_self_check_warn_gate.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/camera_comm_alarm_adapter.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/demo_alarm_command_watcher.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/merging_alarm_signal_source.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/modbus_alarm_attribute_adapter.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/sqlite_alarm_log_repository.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/warn_alarm_sound.dart';
import 'package:lws_hmi/features/warn_alarm/l10n/product_alarm_l10n.dart';
import 'package:lws_hmi/features/warn_alarm/l10n/shielding_gas_alarm_message.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_queue.dart';
import 'package:lws_hmi/features/warn_alarm/presentation/cyber_ui_warn_presentation.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Owns [WarnAlarmCoordinator] + App adapters for the process lifetime.
final class WarnAlarmController {
  WarnAlarmController({
    required this.services,
    required GlobalPromptQueue promptQueue,
    AlarmCodeCatalog? catalog,
    AlarmLogRepository? logRepository,
    WarnGate? gate,
    WarnAlarmSound? sound,
    DangerousOperationsSettings? dangerousOperations,
    bool Function(String code)? infoStyleForCode,
  })  : catalog = catalog ?? ProductAlarmCatalog.seed(),
        log = logRepository ?? SqliteAlarmLogRepository(),
        _sound = sound ?? WarnAlarmSound(services.audio),
        _dangerousOperations = dangerousOperations {
    _infoStyleForCode = infoStyleForCode ??
        (code) {
          final d = _dangerousOperations;
          if (d == null) {
            return false;
          }
          return LaserAlarmPolicy.treatBypassableAsInfo(
            code: code,
            snapshot: d.policySnapshot,
          );
        };
    _presentation = CyberUiWarnPresentation(
      promptQueue: promptQueue,
      stopWarnSound: () => _sound.stop(),
      infoStyleForCode: _infoStyleForCode,
      bodyForCode: _bodyForCode,
    );
    _adapter = ModbusAlarmAttributeAdapter(
      modbus: services.modbus,
      ensureLive: services.ensureModbusLive,
    );
    _cameraAdapter = CameraCommAlarmAdapter();
    _merged = MergingAlarmSignalSource([_adapter, _cameraAdapter]);
    coordinator = WarnAlarmCoordinator(
      catalog: this.catalog,
      signals: _merged,
      presentation: _presentation,
      log: log,
      gate: gate ?? const BootSelfCheckWarnGate(),
    );
    _demoAlarmWatcher = DemoAlarmCommandWatcher(
      onTrigger: triggerDemoAlarm,
      onClean: clearDemoAlarms,
    );
    // After coordinator exists: SFX only when the warn modal is on screen
    // ([CyberUiWarnPresentation.showingCode]), not when the episode is merely
    // queued behind Wi‑Fi / register / other global prompts.
    _presentation.onPresented = (_) => _syncWarnSound();
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
  final DangerousOperationsSettings? _dangerousOperations;
  late final bool Function(String code) _infoStyleForCode;

  /// Live Alarm Information state (Modbus via this alarm stack).
  final AlarmMonitorState monitor = AlarmMonitorState();

  late final ModbusAlarmAttributeAdapter _adapter;
  late final CameraCommAlarmAdapter _cameraAdapter;
  late final MergingAlarmSignalSource _merged;
  late final CyberUiWarnPresentation _presentation;
  late final WarnAlarmCoordinator coordinator;
  late final DemoAlarmCommandWatcher _demoAlarmWatcher;

  StreamSubscription? _monitorSub;
  StreamSubscription? _healthSub;
  StreamSubscription? _signalSub;
  StreamSubscription? _cameraHealthSub;
  Timer? _activePoll;
  bool _started = false;
  int _cameraFirmwareQuietDepth = 0;

  Stream<List<AlarmLogEntry>> watchHistory({int? limit}) =>
      log.watch(limit: limit);

  Future<void> clearHistory() => log.clear();

  /// Pause camera health probes and suppress C002 for firmware upgrade downtime.
  ///
  /// Nestable (host download + apply). Pair with [endCameraFirmwareUpgradeQuiet].
  Future<void> beginCameraFirmwareUpgradeQuiet() async {
    _cameraFirmwareQuietDepth++;
    if (_cameraFirmwareQuietDepth > 1) {
      return;
    }
    _cameraAdapter.setSuppressed(true);
    monitor.setCameraCommFault(false);
    try {
      final session = await services.ensureIpCamera();
      session.camera.suspendProbes();
    } catch (e) {
      debugPrint('warn-alarm: camera quiet suspend soft-failed: $e');
    }
  }

  /// Resume probes and re-arm C002 from live health after firmware upgrade.
  Future<void> endCameraFirmwareUpgradeQuiet({
    bool cameraLikelyOnline = false,
  }) async {
    if (_cameraFirmwareQuietDepth <= 0) {
      return;
    }
    _cameraFirmwareQuietDepth--;
    if (_cameraFirmwareQuietDepth > 0) {
      return;
    }
    try {
      final session = await services.ensureIpCamera();
      session.camera.resumeProbes(configurePingOk: cameraLikelyOnline);
      _cameraAdapter.setSuppressed(false);
      _applyCameraHealthToMonitor(session.camera.currentHealth);
    } catch (e) {
      debugPrint('warn-alarm: camera quiet resume soft-failed: $e');
      _cameraAdapter.setSuppressed(false);
    }
  }
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
    // SFX follows the visible warn modal only (not queued episodes).
    _signalSub = _merged.events.listen((event) {
      _publishActive();
      _syncWarnSound();
      _maybeInterruptOnAlarmEdge(event);
    });
    await _adapter.start();
    await _bindCameraAdapter();
    _demoAlarmWatcher.start();
    _publishActive();
    _syncWarnSound();
    // Episodes can change without monitor attribute batches (ack/recover).
    // Do NOT periodic-flushPresentation: that re-queued fault-active dialogs
    // (esp. demo) and caused Confirm → immediate re-popup loops. Gate open
    // still calls [onPresentationGateOpened] → flush once.
    _activePoll?.cancel();
    _activePoll = Timer.periodic(const Duration(milliseconds: 400), (_) {
      _publishActive();
      _syncWarnSound();
    });
    await services.rgbLedPolicy?.start();
  }

  Future<void> _bindCameraAdapter() async {
    try {
      final session = await services.ensureIpCamera();
      await _cameraHealthSub?.cancel();
      _applyCameraHealthToMonitor(session.camera.currentHealth);
      _cameraHealthSub = session.camera.health.listen(_applyCameraHealthToMonitor);
      await _cameraAdapter.bind(session.camera);
    } catch (e) {
      debugPrint('warn-alarm: camera C002 adapter bind failed: $e');
    }
  }

  void _applyCameraHealthToMonitor(IpCameraHealth health) {
    switch (health.phase) {
      case IpCameraHealthPhase.unknown:
        // Keep last indicator during probe quiet / path reconfigure.
        return;
      case IpCameraHealthPhase.healthy:
        monitor.setCameraCommFault(false);
      case IpCameraHealthPhase.unhealthy:
        monitor.setCameraCommFault(true);
    }
  }

  void _maybeInterruptOnAlarmEdge(AlarmSignalEvent event) {
    if (event.kind != AlarmSignalKind.rising &&
        event.kind != AlarmSignalKind.falling) {
      return;
    }
    final dangerous = _dangerousOperations;
    if (dangerous == null) {
      return;
    }
    unawaited(
      LaserWorkGuard.evaluateAndInterruptIfNeeded(
        services: services,
        dangerous: dangerous,
        warnAlarm: this,
      ),
    );
  }

  String _bodyForCode(String code, AppLocalizations l10n) {
    if (code == LaserAlarmPolicy.alarmA001) {
      return ShieldingGasAlarmMessage.buildDialogContent(l10n, monitor);
    }
    return l10n.alarmBodyFor(code);
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
    _maybeInterruptAfterActiveChange();
  }

  /// Host `make alarm-clean` — clear restrictions; visible popup unchanged.
  Future<void> clearDemoAlarms() async {
    await coordinator.clearAllForDebug();
    _publishActive();
    _syncWarnSound();
    _maybeInterruptAfterActiveChange();
  }

  void _maybeInterruptAfterActiveChange() {
    final dangerous = _dangerousOperations;
    if (dangerous == null) {
      return;
    }
    unawaited(
      LaserWorkGuard.evaluateAndInterruptIfNeeded(
        services: services,
        dangerous: dangerous,
        warnAlarm: this,
      ),
    );
  }

  /// lws-ui LaserEnableAlarmGuard: on alarm block, show the blocking warn
  /// dialog (not a generic "Alarm blocks laser enable" snackbar).
  ///
  /// Returns `true` when a warn dialog was already visible or was requested.
  Future<bool> presentLaserEnableBlock({
    required LaserAlarmPolicySnapshot policy,
  }) async {
    final active = <String>{
      for (final e in coordinator.episodes.values)
        if (e.faultActive) e.code,
    };
    final code = LaserEnablePreflight.firstBlockingAlarmCode(
      activeAlarmCodes: active,
      policy: policy,
    );
    if (code == null) {
      return false;
    }
    final showing = coordinator.showingCode;
    if (showing == code) {
      return true;
    }
    return coordinator.requestImmediateShow(code);
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

  /// SFX lifecycle: tied to the **visible** warn dialog only.
  ///
  /// Use [CyberUiWarnPresentation.showingCode] (set when the frost modal is
  /// actually presented), **not** [WarnAlarmCoordinator.showingCode]. The
  /// coordinator marks an episode "showing" as soon as it enters the present
  /// chain — including while [GlobalPromptQueue] still has Wi‑Fi / register /
  /// other guidance ahead. Queued faults must not start SFX.
  /// Confirm / dismiss clears presentation showing → stop.
  void _syncWarnSound() {
    final showing = _presentation.showingCode;
    if (showing == null) {
      if (_sound.isActive) {
        unawaited(_sound.stop());
      }
      return;
    }
    final alertingCodes = warnSoundAlertingCodes(
      coordinator.episodes,
      isInfoStyle: _infoStyleForCode,
    );
    if (alertingCodes.contains(showing)) {
      unawaited(_sound.ensurePlaying(showing));
    } else if (_sound.isActive) {
      unawaited(_sound.stop());
    }
  }

  /// Codes eligible for looping warn SFX (excludes INFO-styled bypassables).
  @visibleForTesting
  static List<String> warnSoundAlertingCodes(
    Map<String, WarnEpisode> episodes, {
    required bool Function(String code) isInfoStyle,
  }) {
    return episodes.entries
        .where(
          (e) =>
              e.value.faultActive &&
              e.value.phase != WarnEpisodePhase.operatorAcked &&
              !isInfoStyle(e.key),
        )
        .map((e) => e.key)
        .toList()
      ..sort();
  }

  /// After boot self-check (or any gate) clears — present parked / missed episodes.
  Future<void> onPresentationGateOpened() => coordinator.flushPresentation();

  Future<void> dispose() async {
    _activePoll?.cancel();
    await _demoAlarmWatcher.dispose();
    await _monitorSub?.cancel();
    await _healthSub?.cancel();
    await _signalSub?.cancel();
    await _cameraHealthSub?.cancel();
    await coordinator.dispose();
    await _merged.dispose();
    await _cameraAdapter.dispose();
    await _adapter.dispose();
    await _sound.dispose();
    monitor.dispose();
    if (log is SqliteAlarmLogRepository) {
      await (log as SqliteAlarmLogRepository).dispose();
    }
  }
}
