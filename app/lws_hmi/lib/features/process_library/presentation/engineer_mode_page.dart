import 'dart:async';

import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/device/product_property_defaults.dart';
import 'package:lws_hmi/features/process_library/application/process_library_controller.dart';
import 'package:lws_hmi/features/process_library/application/process_library_scope.dart';
import 'package:lws_hmi/features/process_library/application/process_parameter_applier.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_l10n.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_laser_work_guard_host.dart';
import 'package:lws_hmi/features/process_mode/application/engineer_mode_session_store.dart';
import 'package:lws_hmi/features/process_mode/application/gun_dialog_coordinator.dart';
import 'package:lws_hmi/features/process_mode/application/record_work_controller.dart';
import 'package:lws_hmi/features/settings/application/laser_work_guard.dart';
import 'package:lws_hmi/features/process_mode/domain/engineer_mode_draft.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_feedback_copy.dart';
import 'package:lws_hmi/features/process_video/application/process_video_save_handler.dart';
import 'package:lws_hmi/features/process_video/application/process_video_snapshot_factory.dart';
import 'package:lws_hmi/features/process_video/application/process_video_snapshot_source.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/features/process_video/infrastructure/sqlite_process_video_repository.dart';
import 'package:lws_hmi/platform/cloud/cloud_local_runtime_scope.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/domain/laser_enable_reminder_copy.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_device_panel.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_favorites_popup.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_frost_panel.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_parameter_form.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_process_tab_bar.dart';
import 'package:lws_hmi/features/process_mode/presentation/laser_enable_reminder_dialog.dart';
import 'package:lws_hmi/features/process_mode/presentation/key_switch_off_prompt.dart';
import 'package:lws_hmi/features/process_mode/presentation/operation_failed_dialog.dart';
import 'package:lws_hmi/features/process_mode/presentation/process_mode_toast.dart';
import 'package:lws_hmi/features/process_mode/presentation/work_status_dialog_host.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_scope.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/features/statistics/application/work_session_statistics_recorder.dart';
import 'package:lws_hmi/features/status_bar/product_tab_slide_body.dart';
import 'package:lws_hmi/features/work_mode/presentation/work_mode_status_bar.dart';
import 'package:lws_hmi/gpio/laser_enable_led_holder.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_text_scale.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/features/process_library/presentation/engineer_action_layout.dart';
import 'package:lws_hmi/ui/cyber/cyber_ime_input_dialog.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';

/// Engineer Mode: five tabs + left device panel + right parameter card.
final class EngineerModePage extends StatefulWidget {
  const EngineerModePage({
    super.key,
    this.initialProcessType,
    this.initialPresetUuid,
    this.fromQuickHandoff = false,
  });

  final ProcessType? initialProcessType;
  final String? initialPresetUuid;

  /// Quick Mode "More Parameters" entry — status bar shows Back (not Home).
  final bool fromQuickHandoff;

  @override
  State<EngineerModePage> createState() => _EngineerModePageState();
}

final class _EngineerModePageState extends State<EngineerModePage> {
  late ProcessType _processType;
  EngineerModeDraft? _draft;

  /// Debounced Modbus apply (lws-ui `sendDataProxy` / `delayMillis` 300).
  Timer? _applyDebounce;
  int _applyGen = 0;

  bool _favoritesOpen = false;

  bool _bootstrapped = false;
  DeviceControlController? _deviceControl;
  DeviceControlLaserWorkGuardHost? _laserWorkGuardHost;
  WorkSessionStatisticsRecorder? _workSessionStatistics;
  RecordWorkController? _recordWork;
  GunDialogCoordinator? _gunDialogs;
  bool _exiting = false;
  int _processSwitchGen = 0;
  Future<void> _processSwitchSync = Future<void>.value();

  /// Tab slide direction for [ProductTabSlideSwitcher] (higher index = forward).
  bool _tabSlideForward = true;

  double _largeActionLabelWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: context.hmiTypography.buttonLarge,
      ),
      textDirection: Directionality.of(context),
      // Reset / Save Favorite are fixed Medium chrome.
      textScaler: TextScaler.noScaling,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialProcessType;
    _processType =
        initial != null && EngineerProcessTabs.types.contains(initial)
            ? initial
            : ProcessType.continuousWelding;
    LaserEnableLedHolder.instance.setWorkModel(_processType);
    scheduleEnsureModbusLive(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final services = AppScope.maybeOf(context);
      if (services != null && _deviceControl == null) {
        _workSessionStatistics = WorkSessionStatisticsRecorder();
        _deviceControl = DeviceControlController(
          services,
          workSessionStatistics: _workSessionStatistics,
        );
        _deviceControl!.onSafetyEvent = _onDeviceSafetyEvent;
        unawaited(_deviceControl!.start());
        _laserWorkGuardHost = DeviceControlLaserWorkGuardHost(_deviceControl!);
        LaserWorkGuard.register(_laserWorkGuardHost!);
        _recordWork = RecordWorkController(
          deviceControl: _deviceControl!,
          resolveL10n: () => AppLocalizations.of(context)!,
          snapshotSource: CallbackProcessVideoSnapshotSource(
            _captureProcessVideoSnapshot,
          ),
          saveHandler: ProcessVideoSaveHandler(
            repository: SqliteProcessVideoRepository(),
            afterSave: (_) async {
              final runtime = CloudLocalRuntimeScope.maybeOf(context);
              await runtime?.notifyProcessVideoSaved();
            },
          ),
          onMessage: (message) {
            if (!mounted) {
              return;
            }
            ProcessModeToast.show(context, message);
          },
        );
        unawaited(_recordWork!.start(services));
        _gunDialogs = GunDialogCoordinator(
          deviceControl: _deviceControl!,
          services: services,
          contextGetter: () => mounted ? context : null,
          showGroundLockAlarmGetter: () =>
              MiscSettingsScope.maybeOf(context)?.showGroundLockAlarm ?? false,
          // Engineer keeps edge latch across Enable OFF (lws-ui).
          resetGunLatchOnEnableOff: false,
        );
        unawaited(_gunDialogs!.start());
        setState(() {});
      }
      unawaited(_bootstrap());
    });
  }

  @override
  void dispose() {
    _applyDebounce?.cancel();
    LaserEnableLedHolder.instance.clear();
    final host = _laserWorkGuardHost;
    if (host != null) {
      LaserWorkGuard.unregister(host);
      _laserWorkGuardHost = null;
    }
    _gunDialogs?.dispose();
    _gunDialogs = null;
    _recordWork?.dispose();
    _deviceControl?.onSafetyEvent = null;
    _deviceControl?.dispose();
    unawaited(_workSessionStatistics?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  ProcessVideoSnapshot? _captureProcessVideoSnapshot() {
    return ProcessVideoSnapshotFactory.fromPreset(
      processType: _processType,
      preset: _draft?.preset,
    );
  }

  void _onDeviceSafetyEvent(DeviceControlSafetyEvent event) {
    if (!mounted) {
      return;
    }
    switch (event) {
      case DeviceControlSafetyEvent.emergencyStopCleared:
        OperationFailedDialogHost.dismissForSafetyClear(event);
        return;
      case DeviceControlSafetyEvent.keySwitchRestored:
        KeySwitchOffPrompt.reset();
        OperationFailedDialogHost.dismissForSafetyClear(event);
        return;
      case DeviceControlSafetyEvent.keySwitchOff:
        WorkStatusDialogHost.closeDialog();
        final control = _deviceControl;
        if (control != null &&
            !control.suppressKeySwitchOffSafetyPrompt &&
            (MiscSettingsScope.maybeOf(context)?.showKeySwitchAlarm ?? false)) {
          unawaited(
            KeySwitchOffPrompt.maybeShow(
              context,
              alarmEnabled: true,
              services: AppScope.of(context),
            ),
          );
        }
        return;
      case DeviceControlSafetyEvent.emergencyStop:
        break;
    }
    WorkStatusDialogHost.closeDialog();
    final l10n = AppLocalizations.of(context)!;
    final message = DeviceControlFeedbackCopy.emergencyStopError(l10n);
    unawaited(
      OperationFailedDialogHost.show(
        context,
        message: message,
        safetyEvent: event,
      ),
    );
  }

  Future<void> _bootstrap() async {
    final controller = ProcessLibraryScope.of(context);
    await controller.initialize();
    if (!mounted || _bootstrapped) {
      return;
    }
    _bootstrapped = true;
    final handoffUuid = widget.initialPresetUuid;
    if (handoffUuid != null) {
      ProcessPreset? source;
      for (final preset in controller.presets) {
        if (preset.uuid == handoffUuid) {
          source = preset;
          break;
        }
      }
      if (source != null) {
        setState(() {
          _processType = EngineerProcessTabs.types.contains(source!.processType)
              ? source.processType
              : _processType;
          _setActiveDraft(EngineerModeDraft.fromQuickSource(source));
        });
        // lws-ui `applyQuickModeEntry`: sync end power from handoff laser power.
        unawaited(_syncLaserEndPowerFromDraft());
        // Handoff always pushes the carried row (not an isInit-only UI load).
        _scheduleApply(_draft!.preset);
        return;
      }
    }
    // lws-ui `resolveInitialSession`: prefer process-lifetime cache.
    final cached = EngineerModeSessionStore.instance.get(_processType);
    if (cached != null) {
      // Cache hit: UI only (lws-ui `isInit` skips sendDataProxy), including CW.
      setState(() => _setActiveDraft(cached));
      return;
    }
    _selectDefaultForType(controller);
    // Product exception vs lws-ui isInit: cold default load on continuous
    // welding must push swing width 2mm (and the rest of that process group).
    // Spot / clean / cut tabs stay isInit-skip — no auto-apply until edit.
    _scheduleFirstEntryContinuousWeldApply();
  }

  /// Assign [_draft] and publish into [EngineerModeSessionStore] (lws-ui
  /// `publishSession` → MemoryCache).
  void _setActiveDraft(EngineerModeDraft? draft) {
    _draft = draft;
    if (draft != null) {
      EngineerModeSessionStore.instance.put(draft);
    }
  }

  void _selectDefaultForType(ProcessLibraryController controller) {
    final presets =
        controller.engineerPresets(processType: _processType).toList();
    setState(() {
      _setActiveDraft(
        presets.isEmpty ? null : EngineerModeDraft.fromLibrary(presets.first),
      );
    });
  }

  /// Cold default entry on continuous welding only: push process group (swing 2).
  ///
  /// Other engineer tabs mirror lws-ui: first LiveData/`isInit` load is UI-only;
  /// Modbus write waits for `updateProcessParamsDataAndSend` (field edit).
  void _scheduleFirstEntryContinuousWeldApply() {
    final draft = _draft;
    if (draft == null || _processType != ProcessType.continuousWelding) {
      return;
    }
    _scheduleApply(draft.preset);
  }

  /// Switch process tab: keep each type's process-lifetime session.
  ///
  /// UI updates first (Quick Mode pattern). Modbus clear / laser off runs in
  /// the background so tab chrome is not blocked. Record Work stays armed —
  /// encode stops when laser session ends (do not
  /// [RecordWorkController.stopRecordingForExit]).
  ///
  /// Parity with lws-ui `selectModel`: push the active tab's process group and
  /// `control.process_type` (do not confuse with UI-only
  /// `onEngineerPageActivated`). Spot interval/duration only take effect when
  /// process_type is spot welding (1).
  void _onProcessTypeChanged(ProcessType type) {
    if (type == _processType) {
      return;
    }
    // Drop a pending edit apply from the previous tab so it cannot overwrite
    // the new type's process group / process_type.
    _applyDebounce?.cancel();
    _applyDebounce = null;
    final types = EngineerProcessTabs.types;
    final oldIndex = types.indexOf(_processType);
    final newIndex = types.indexOf(type);
    final controller = ProcessLibraryScope.of(context);
    setState(() {
      _tabSlideForward = newIndex >= oldIndex;
      if (_draft != null) {
        EngineerModeSessionStore.instance.put(_draft!);
      }
      _processType = type;
      final cached = EngineerModeSessionStore.instance.get(type);
      if (cached != null) {
        _draft = cached;
        return;
      }
      final presets = controller.engineerPresets(processType: type).toList();
      _setActiveDraft(
        presets.isEmpty ? null : EngineerModeDraft.fromLibrary(presets.first),
      );
    });
    LaserEnableLedHolder.instance.setWorkModel(type);
    final gen = ++_processSwitchGen;
    debugPrint(
      'engineer-mode: process tab changed '
      'type=${type.name} sync=$gen',
    );
    final preset = _draft?.preset;
    if (preset != null && preset.processType == type) {
      // Kick apply without waiting for wire/laser Modbus (those can be slow on
      // a busy RTU). Interlock still blocks when laser is actually on — then
      // [_syncDeviceForProcessType] re-applies after disable.
      _scheduleApply(preset, mode: ProcessApplyMode.modeSwitch);
    }
    _enqueueDeviceSyncForProcessType(type, gen);
  }

  /// Serialize tab-side device writes.
  ///
  /// `DeviceControlController` rejects concurrent commands as `busy`. Starting
  /// one unawaited chain per tab allowed an old `setAutoWireFeed(false)` to
  /// finish after the latest continuous-weld `setAutoWireFeed(true)` was
  /// rejected, producing an alternating off/on result on repeated switches.
  void _enqueueDeviceSyncForProcessType(ProcessType type, int gen) {
    final previous = _processSwitchSync;
    _processSwitchSync = () async {
      try {
        await previous;
      } catch (e) {
        debugPrint('engineer-mode: prior process switch sync failed: $e');
      }
      if (!mounted || gen != _processSwitchGen) {
        return;
      }
      try {
        await _syncDeviceForProcessType(type, gen);
      } catch (e) {
        debugPrint('engineer-mode: process switch sync failed: $e');
      }
    }();
    unawaited(_processSwitchSync);
  }

  /// Clears continuous wire, ends laser session, aligns Auto Wire. Re-applies
  /// process params when laser had been on (early apply would hit interlock).
  Future<void> _syncDeviceForProcessType(ProcessType type, int gen) async {
    if (!mounted || gen != _processSwitchGen) {
      return;
    }
    final laserWasOn = _deviceControl?.laserEnable ?? false;
    final clearResult = await _deviceControl?.clearContinuousWire();
    debugPrint(
      'engineer-mode: process tab clear-wire '
      'type=${type.name} result=$clearResult',
    );
    if (!mounted || gen != _processSwitchGen) {
      return;
    }
    if (laserWasOn) {
      final disableResult = await _deviceControl?.disableLaser();
      debugPrint(
        'engineer-mode: process tab disable-laser '
        'type=${type.name} result=$disableResult',
      );
    }
    if (!mounted || gen != _processSwitchGen) {
      return;
    }
    final device = _deviceControl;
    if (device != null) {
      final enableAutoWire =
          type == ProcessType.continuousWelding && !device.emergencyStop;
      LaserEnableBlockReason? result;
      for (var attempt = 0; attempt < 8; attempt++) {
        if (!mounted || gen != _processSwitchGen) {
          return;
        }
        result = await device.setAutoWireFeed(enableAutoWire);
        if (result != LaserEnableBlockReason.busy) {
          break;
        }
        await Future<void>.delayed(
          Duration(milliseconds: 40 * (attempt + 1)),
        );
      }
      debugPrint(
        'engineer-mode: process tab auto-wire '
        'type=${type.name} enabled=$enableAutoWire result=$result',
      );
    }
    if (!mounted || gen != _processSwitchGen) {
      return;
    }
    if (!laserWasOn) {
      return;
    }
    final preset = _draft?.preset;
    if (preset == null || preset.processType != type) {
      return;
    }
    _scheduleApply(preset);
  }

  /// Engineer Back:
  /// - Laser Enable on → End of work only (stay on Engineer Mode).
  /// - Otherwise → home after laser/wire disarm (awaited).
  Future<void> _handleExit() async {
    if (_exiting) {
      return;
    }
    final device = _deviceControl;
    if (device != null && device.laserEnable) {
      final err = await device.disableLaser();
      if (err != null && mounted) {
        final l10n = AppLocalizations.of(context)!;
        ProcessModeToast.show(
          context,
          DeviceControlFeedbackCopy.messageForDisable(l10n, err),
        );
      }
      return;
    }
    _exiting = true;
    try {
      // Flush only a pending debounce (lws-ui may drop in-flight delay on
      // finish; we keep the last edit). Do not force-apply an untouched draft.
      final shouldFlush = _applyDebounce != null;
      _applyDebounce?.cancel();
      _applyDebounce = null;
      if (shouldFlush) {
        final pending = _draft?.preset;
        if (pending != null) {
          await _applyDraft(pending);
        }
      }
      final record = _recordWork;
      await device?.shutdownForExit();
      await record?.stopRecordingForExit();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } finally {
      _exiting = false;
    }
  }

  void _onBack() => unawaited(_handleExit());

  Future<void> _openFavorites(BuildContext anchorContext) async {
    final controller = ProcessLibraryScope.of(context);
    final presets =
        controller.engineerPresets(processType: _processType).toList();
    if (presets.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noMoreFavorites)),
      );
      return;
    }

    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    final origin = box.localToGlobal(Offset.zero);
    setState(() => _favoritesOpen = true);
    final selected = await showEngineerFavoritesPopup(
      context: context,
      anchor: origin & box.size,
      presets: presets,
      selectedUuid: _draft?.unsaved == true ? null : _draft?.preset.uuid,
      selectedName: _draft?.preset.name,
      processType: _processType,
    );
    if (!mounted) {
      return;
    }
    setState(() => _favoritesOpen = false);
    if (selected == null) {
      return;
    }
    setState(() {
      _setActiveDraft(EngineerModeDraft.fromLibrary(selected));
    });
    _scheduleApply(_draft!.preset);
  }

  void _onDraftChanged(ProcessPreset preset) {
    final draft = _draft;
    if (draft == null || draft.isReadOnly) {
      return;
    }
    final previousPower = draft.preset.parameters.values['process.laser_power'];
    final nextPower = preset.parameters.values['process.laser_power'];
    setState(() {
      _setActiveDraft(draft.copyWith(preset: preset, unsaved: true));
    });
    // lws-ui InputDialogBuilder.weldingPowerBuilder → syncAndSendLaserTerminationPower.
    if (nextPower != null && nextPower != previousPower) {
      unawaited(_syncLaserEndPower(nextPower));
    }
    // lws-ui `updateProcessParamsDataAndSend` → debounced `sendData`.
    _scheduleApply(preset);
  }

  /// Debounced process-group write (lws-ui `sendDataProxy` 300ms).
  ///
  /// Used after field edits / favorites / reset / continuous-weld first entry /
  /// Quick handoff / tab switch (`selectModel` sendData). Unlike Quick Mode,
  /// the same draft uuid may change field values, so every edit schedules an
  /// apply — do not skip on uuid equality.
  void _scheduleApply(
    ProcessPreset preset, {
    ProcessApplyMode mode = ProcessApplyMode.liveTune,
  }) {
    _applyDebounce?.cancel();
    _applyDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      unawaited(_applyDraft(preset, mode: mode));
    });
  }

  Future<bool> _applyDraft(
    ProcessPreset preset, {
    ProcessApplyMode mode = ProcessApplyMode.liveTune,
  }) async {
    final gen = ++_applyGen;
    final library = ProcessLibraryScope.of(context);
    // Tab-switch apply can land while continuous first-entry apply still holds
    // the library lock; retry busy like RTU baseline retries.
    var result = const ProcessApplyResult.failure(ProcessApplyFailure.busy);
    for (var attempt = 0; attempt < 8; attempt++) {
      if (!mounted || gen != _applyGen) {
        return false;
      }
      result = await library.apply(preset, mode: mode);
      if (result.isSuccess || result.failure != ProcessApplyFailure.busy) {
        break;
      }
      await Future<void>.delayed(
        Duration(milliseconds: 40 * (attempt + 1)),
      );
    }
    if (!mounted || gen != _applyGen) {
      return false;
    }
    if (result.isSuccess) {
      return true;
    }
    // Soft-fail like Advanced Settings: keep UI draft; toast only for
    // hard write/readback failures (interlocks are silent — laser path shows).
    final silent = switch (result.failure) {
      ProcessApplyFailure.busy ||
      ProcessApplyFailure.statusUnavailable ||
      ProcessApplyFailure.unsafeMachineState ||
      ProcessApplyFailure.wireFeedingActive ||
      ProcessApplyFailure.baselineReadFailed =>
        true,
      _ => false,
    };
    if (!silent) {
      final l10n = AppLocalizations.of(context)!;
      ProcessModeToast.show(
          context, _applyFailureMessage(l10n, result.failure));
    }
    return false;
  }

  Future<void> _syncLaserEndPowerFromDraft() async {
    final power = _draft?.preset.parameters.values['process.laser_power'];
    await _syncLaserEndPower(power);
  }

  Future<void> _syncLaserEndPower(double? laserPower) async {
    if (!mounted) {
      return;
    }
    final thresholds = AdvancedSettingsScope.maybeThresholdsOf(context);
    if (thresholds == null) {
      return;
    }
    await thresholds.syncAndSendLaserTerminationPower(laserPower);
  }

  void _configureWorkSessionStatistics(ProcessPreset preset) {
    final isWeld = _processType == ProcessType.continuousWelding ||
        _processType == ProcessType.spotWelding;
    _workSessionStatistics?.configureNextSession(
      modeType: _statisticsModeType(_processType),
      // Stored for audit; settle uses modeType==weld × process wire speed
      // (lws-ui weldStop: sessionSeconds * wireFeedSpeed), not this flag.
      autoWireFeedEnabled: isWeld && (_deviceControl?.autoWireFeed ?? false),
      autoWireFeedSpeedMmPerSecond:
          preset.parameters.values['process.wire_feeding_speed'] ?? 0,
      materialType: preset.materialType?.storageValue,
    );
  }

  static int _statisticsModeType(ProcessType type) => switch (type) {
        ProcessType.continuousWelding || ProcessType.spotWelding => 1,
        ProcessType.handCutting || ProcessType.cncCutting => 2,
        ProcessType.weldCleaning || ProcessType.wideCleaning => 3,
      };

  /// Safety dialog + re-apply current draft (Quick enable order parity).
  Future<bool> _beforeEnableLaser() async {
    final draft = _draft;
    if (draft == null) {
      return false;
    }
    final library = ProcessLibraryScope.of(context);
    final focusScaleRef = await _focusScaleRef();
    if (!mounted) {
      return false;
    }
    final confirmed = await showLaserEnableReminderDialog(
      context: context,
      processType: _processType,
      session: LaserEnableReminderSession.engineer,
      focusScaleRef: focusScaleRef,
    );
    if (confirmed == null || !mounted) {
      return false;
    }
    if (confirmed.dontShowAgain) {
      LaserEnableReminderGate.suppress(LaserEnableReminderSession.engineer);
    }

    final control = _deviceControl;
    if (control != null && (control.wireWork || control.wireFeedingOn)) {
      final wireErr = await control.stopWire();
      if (wireErr != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wireErr.message),
            duration: const Duration(seconds: 2),
          ),
        );
        return false;
      }
    }

    // Clear stale laser_enable so process apply is not blocked as "in progress".
    if (control != null) {
      await control.forceDisableLaserForSafety();
      if (!mounted) {
        return false;
      }
    }

    // Enable must write process_type + params after force-disable; do not
    // fall through to live-tune if the enable bit is still stuck on.
    final result = await library.apply(
      draft.preset,
      mode: ProcessApplyMode.modeSwitch,
    );
    if (!mounted) {
      return false;
    }
    if (result.failure != null) {
      final failureL10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_applyFailureMessage(failureL10n, result.failure)),
          duration: const Duration(seconds: 2),
        ),
      );
      return false;
    }
    // lws-ui sendAdvanceSettingData → syncAndSendLaserTerminationPower.
    await _syncLaserEndPower(
      draft.preset.parameters.values['process.laser_power'],
    );
    return true;
  }

  Future<int> _focusScaleRef() async {
    final services = AppScope.maybeOf(context);
    if (services == null) {
      return 0;
    }
    try {
      final product = await services.ensureProductInfo();
      return LaserEnableReminderCopy.parseFocusScaleRef(
        effectiveFocusScaleRefFromProduct(product),
      );
    } catch (_) {
      return 0;
    }
  }

  String _applyFailureMessage(
    AppLocalizations l10n,
    ProcessApplyFailure? failure,
  ) {
    return switch (failure) {
      ProcessApplyFailure.busy => l10n.processApplyFailureBusy,
      ProcessApplyFailure.statusUnavailable =>
        l10n.processApplyFailureStatusUnavailable,
      ProcessApplyFailure.unsafeMachineState =>
        l10n.processApplyFailureUnsafeMachineState,
      ProcessApplyFailure.wireFeedingActive =>
        l10n.processApplyFailureWireFeedingActive,
      ProcessApplyFailure.baselineReadFailed =>
        l10n.processApplyFailureBaselineReadFailed,
      ProcessApplyFailure.processWriteFailed =>
        l10n.processApplyFailureProcessWriteFailed,
      ProcessApplyFailure.processReadFailed =>
        l10n.processApplyFailureProcessReadFailed,
      ProcessApplyFailure.processReadbackFailed =>
        l10n.processApplyFailureProcessReadbackFailed,
      ProcessApplyFailure.processTypeWriteFailed =>
        l10n.processApplyFailureProcessTypeWriteFailed,
      ProcessApplyFailure.processTypeReadFailed =>
        l10n.processApplyFailureProcessTypeReadFailed,
      ProcessApplyFailure.processTypeReadbackFailed =>
        l10n.processApplyFailureProcessTypeReadbackMismatch,
      ProcessApplyFailure.partialApply => l10n.processApplyFailurePartialApply,
      null => l10n.processApplyFailureGeneric,
    };
  }

  /// Unlock built-in for editing as an in-memory user draft (no DB write yet).
  Future<ProcessPreset?> _beginEditFromBuiltin() async {
    final draft = _draft;
    if (draft == null) {
      return null;
    }
    if (!draft.isReadOnly) {
      return draft.preset;
    }
    final next = EngineerModeDraft.fromQuickSource(draft.preset);
    setState(() => _setActiveDraft(next));
    return next.preset;
  }

  Future<void> _resetToDefault() async {
    final draft = _draft;
    if (draft == null) {
      return;
    }
    // lws-ui: restore session baseline (not “first builtin in library”).
    final restored = draft.resetToBaseline();
    setState(() {
      _setActiveDraft(restored);
    });
    _scheduleApply(restored.preset);
    if (!mounted) {
      return;
    }
    // lws-ui `ToastUtils.showShort(R.string.reset_data_successfully)`.
    ProcessModeToast.show(context, AppLocalizations.of(context)!.resetComplete);
  }

  Future<void> _saveAsFavorite() async {
    final draft = _draft;
    if (draft == null) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final name = await showCyberImeInputDialog(
      context: context,
      title: l10n.processParameterName,
      fieldType: CyberImeFieldType.text,
      initial: draft.preset.name,
      requireNonEmpty: true,
    );
    if (name == null || !mounted) {
      return;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (trimmed.length > 32) {
      ProcessModeToast.show(
        context,
        l10n.processNameMaxLength,
      );
      return;
    }
    final controller = ProcessLibraryScope.of(context);
    try {
      ProcessParameterValidator.validate(draft.preset);
      final named = draft.preset.copyWith(name: trimmed);
      final saved = await controller.saveAsFavorite(named, name: trimmed);
      if (!mounted) {
        return;
      }
      setState(() {
        _setActiveDraft(EngineerModeDraft.fromLibrary(saved));
      });
      // lws-ui `ToastUtils.showShort(R.string.saved_successfully)`.
      ProcessModeToast.show(context, l10n.savedSuccessfully);
    } catch (_) {
      // Keep session draft; Save as Favorite is the only persist path.
    }
  }

  Future<void> _editName() async {
    final draft = _draft;
    if (draft == null) {
      return;
    }
    ProcessPreset working = draft.preset;
    if (draft.isReadOnly) {
      final unlocked = await _beginEditFromBuiltin();
      if (unlocked == null || !mounted) {
        return;
      }
      working = unlocked;
    }
    final l10n = AppLocalizations.of(context)!;
    final name = await showCyberImeInputDialog(
      context: context,
      title: l10n.processNameLabel,
      fieldType: CyberImeFieldType.text,
      initial: working.name,
      requireNonEmpty: true,
    );
    if (name == null) {
      return;
    }
    _onDraftChanged(working.copyWith(name: name.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = ProcessLibraryScope.of(context);
    final draft = _draft;
    final accent = ProcessModeTokens.tabActiveColor(_processType);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        unawaited(_handleExit());
      },
      // Same stack as Settings / Monitor: home wallpaper → static σ30 plate → chrome.
      child: SettingsBlurredPageShell(
        blurSigma: SettingsPerspectiveChrome.blurSigma,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: WorkModeStatusBar(
            mode: WorkMode.engineer,
            processType: _processType,
            backLabel: widget.fromQuickHandoff
                ? (AppLocalizations.of(context)?.equipmentStatusBack ?? 'Back')
                : (AppLocalizations.of(context)?.equipmentStatusHome ?? 'Home'),
            onBack: _onBack,
          ),
          body: ProcessModeToastLayer(
            child: Column(
              children: [
                EngineerProcessTabBar(
                  processType: _processType,
                  onChanged: _onProcessTypeChanged,
                ),
                if (controller.loading && !controller.initialized)
                  const Expanded(
                      child: Center(child: CircularProgressIndicator()))
                else
                  Expanded(
                    child: ProductTabSlideSwitcher(
                      forward: _tabSlideForward,
                      child: KeyedSubtree(
                        key: ValueKey(_processType),
                        child: draft == null
                            ? Center(
                                child: Text(
                                  l10n.noEngineerProcesses,
                                  key: const ValueKey('engineer-mode-empty'),
                                  style: context.hmiTypography.supporting
                                      .copyWith(color: const Color(0xB3FFFFFF)),
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  ProcessModeDimens.engineerPanelHorizontalPad,
                                  12,
                                  ProcessModeDimens.engineerPanelHorizontalPad,
                                  16,
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      // 1 : φ ≈ 38.2% : 61.8% with the right panel.
                                      flex: ProcessModeDimens
                                          .engineerLeftPanelFlex,
                                      child: SizedBox(
                                        key: const ValueKey(
                                            'engineer-device-panel-container'),
                                        child: _deviceControl == null ||
                                                _recordWork == null
                                            ? const SizedBox.shrink()
                                            : EngineerDevicePanel(
                                                controller: _deviceControl!,
                                                recordWork: _recordWork!,
                                                processType: _processType,
                                                preset: draft.preset,
                                                onBeforeEnableLaser:
                                                    _beforeEnableLaser,
                                                onConfigureWorkSession:
                                                    _configureWorkSessionStatistics,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: ProcessModeDimens.engineerPanelGap,
                                    ),
                                    Expanded(
                                      flex: ProcessModeDimens
                                          .engineerRightPanelFlex,
                                      child: EngineerFrostPanel(
                                        key: const ValueKey(
                                            'engineer-parameters-panel'),
                                        edge: EngineerFrostEdge
                                            .bottomLeftTopRight,
                                        child: Column(
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      24, 0, 16, 0),
                                              child: SizedBox(
                                                height: 86,
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: InkWell(
                                                        key: const ValueKey(
                                                            'engineer-mode-name'),
                                                        onTap: () {
                                                          CyberClickSoundRegistry
                                                              .playClick();
                                                          _editName();
                                                        },
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              draft.preset
                                                                  .displayProcessName(
                                                                      l10n),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: context
                                                                  .hmiTypography
                                                                  .navigation
                                                                  .copyWith(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 6),
                                                            Text(
                                                              l10n.currentProcessName,
                                                              key: ValueKey(
                                                                draft.fromQuickHandoff
                                                                    ? 'engineer-mode-draft-uuid'
                                                                    : 'engineer-mode-source-label',
                                                              ),
                                                              style: context
                                                                  .hmiTypography
                                                                  .caption
                                                                  .copyWith(
                                                                color: accent
                                                                    .withOpacity(
                                                                        0.9),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    KeyedSubtree(
                                                      key: const ValueKey(
                                                        'engineer-more-favorites',
                                                      ),
                                                      child: Builder(
                                                        builder:
                                                            (anchorContext) {
                                                          return InkWell(
                                                            onTap: () {
                                                              CyberClickSoundRegistry
                                                                  .playClick();
                                                              if (_favoritesOpen) {
                                                                return;
                                                              }
                                                              unawaited(
                                                                _openFavorites(
                                                                  anchorContext,
                                                                ),
                                                              );
                                                            },
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 8,
                                                                vertical: 12,
                                                              ),
                                                              child: Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  Text(
                                                                    l10n.moreFavorites,
                                                                    style: context
                                                                        .hmiTypography
                                                                        .settingsRowTitle
                                                                        .copyWith(
                                                                      color: Colors
                                                                          .white,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      width: 2),
                                                                  Icon(
                                                                    _favoritesOpen
                                                                        ? Icons
                                                                            .keyboard_arrow_down
                                                                        : Icons
                                                                            .chevron_right,
                                                                    color: Colors
                                                                        .white,
                                                                    size: 30,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Divider(
                                              key: const ValueKey(
                                                  'engineer-parameters-header-divider'),
                                              height: 2,
                                              thickness: 1,
                                              color: const Color(0x33FFFFFF),
                                              indent: 24,
                                              endIndent: 24,
                                            ),
                                            Expanded(
                                              child: EngineerParameterForm(
                                                preset: draft.preset,
                                                readOnly: draft.isReadOnly,
                                                onChanged: _onDraftChanged,
                                                onBeginEdit:
                                                    _beginEditFromBuiltin,
                                                footer: Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                    16,
                                                    8,
                                                    0,
                                                    EngineerDevicePanel
                                                        .panelBottomInset,
                                                  ),
                                                  child: LayoutBuilder(
                                                    builder:
                                                        (context, constraints) {
                                                      final resetLabel = l10n
                                                          .engineerActionResetDefaults;
                                                      final saveLabel = l10n
                                                          .engineerActionSaveFavorite;
                                                      final useVertical =
                                                          EngineerActionLayout
                                                              .useVertical(
                                                        // These two action
                                                        // labels intentionally
                                                        // ignore user text size.
                                                        isLargeText: false,
                                                        maxWidth: constraints
                                                            .maxWidth,
                                                        resetLabelWidth:
                                                            _largeActionLabelWidth(
                                                          context,
                                                          resetLabel,
                                                        ),
                                                        saveLabelWidth:
                                                            _largeActionLabelWidth(
                                                          context,
                                                          saveLabel,
                                                        ),
                                                      );
                                                      final reset =
                                                          HmiFixedTextScale(
                                                        child: HmiButton(
                                                          key: const ValueKey(
                                                            'engineer-action-reset-default',
                                                          ),
                                                          label: resetLabel,
                                                          size: HmiButtonSize
                                                              .large,
                                                          widthPolicy:
                                                              HmiButtonWidthPolicy
                                                                  .fill,
                                                          horizontalPadding:
                                                              EngineerActionLayout
                                                                  .horizontalPadding,
                                                          shape:
                                                              CyberButtonShape
                                                                  .rounded,
                                                          icon:
                                                              Icons.restart_alt,
                                                          // Label centered; icon
                                                          // with equal L/R spacing.
                                                          forceTextBandCentered:
                                                              true,
                                                          onPressed:
                                                              _resetToDefault,
                                                        ),
                                                      );
                                                      final save =
                                                          HmiFixedTextScale(
                                                        child: HmiButton(
                                                          key: const ValueKey(
                                                            'engineer-action-save-favorite',
                                                          ),
                                                          label: saveLabel,
                                                          size: HmiButtonSize
                                                              .large,
                                                          widthPolicy:
                                                              HmiButtonWidthPolicy
                                                                  .fill,
                                                          horizontalPadding:
                                                              EngineerActionLayout
                                                                  .horizontalPadding,
                                                          shape:
                                                              CyberButtonShape
                                                                  .rounded,
                                                          icon: Icons
                                                              .bookmark_add,
                                                          forceTextBandCentered:
                                                              true,
                                                          onPressed: controller
                                                                  .applying
                                                              ? null
                                                              : _saveAsFavorite,
                                                        ),
                                                      );
                                                      if (useVertical) {
                                                        return Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .stretch,
                                                          children: [
                                                            reset,
                                                            const SizedBox(
                                                              height:
                                                                  EngineerActionLayout
                                                                      .groupGap,
                                                            ),
                                                            save,
                                                          ],
                                                        );
                                                      }
                                                      return Row(
                                                        children: [
                                                          Expanded(
                                                              child: reset),
                                                          const SizedBox(
                                                            width:
                                                                EngineerActionLayout
                                                                    .groupGap,
                                                          ),
                                                          Expanded(child: save),
                                                        ],
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
