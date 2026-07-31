import 'dart:async';

import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/process_library/application/process_library_controller.dart';
import 'package:lws_hmi/features/process_library/application/process_library_scope.dart';
import 'package:lws_hmi/features/process_library/application/process_parameter_applier.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/application/gun_dialog_coordinator.dart';
import 'package:lws_hmi/features/process_mode/application/record_work_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/engineer_mode_draft.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_feedback_copy.dart';
import 'package:lws_hmi/features/process_video/application/process_video_save_handler.dart';
import 'package:lws_hmi/features/process_video/application/process_video_snapshot_factory.dart';
import 'package:lws_hmi/features/process_video/application/process_video_snapshot_source.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/features/process_video/infrastructure/sqlite_process_video_repository.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/domain/laser_enable_reminder_copy.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_device_panel.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_favorites_popup.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_frost_panel.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_parameter_form.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_process_tab_bar.dart';
import 'package:lws_hmi/features/process_mode/presentation/laser_enable_reminder_dialog.dart';
import 'package:lws_hmi/features/process_mode/presentation/operation_failed_dialog.dart';
import 'package:lws_hmi/features/process_mode/presentation/process_mode_toast.dart';
import 'package:lws_hmi/features/process_mode/presentation/work_status_dialog_host.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_scope.dart';
import 'package:lws_hmi/features/statistics/application/work_session_statistics_recorder.dart';
import 'package:lws_hmi/features/work_mode/presentation/work_mode_status_bar.dart';
import 'package:lws_hmi/gpio/laser_enable_led_holder.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/cyber/cyber_ime_input_dialog.dart';

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

/// Brighter TL→BR rim for Reset / Save pills (default dark HL is 0x77).
const _engineerActionPillBorder = <Color>[
  Color(0xCCFFFFFF),
  Color(0xAA86868C),
  Color(0x66000000),
];

final class _EngineerModePageState extends State<EngineerModePage> {
  late ProcessType _processType;
  EngineerModeDraft? _draft;

  /// Per-process-type edit sessions (lws-ui `engineer_data_cache:{type}`).
  /// Survives tab switches within Engineer Mode; cleared when leaving the page.
  final Map<ProcessType, EngineerModeDraft> _sessions = {};

  final GlobalKey _moreFavoritesKey = GlobalKey();
  bool _favoritesOpen = false;

  bool _bootstrapped = false;
  DeviceControlController? _deviceControl;
  WorkSessionStatisticsRecorder? _workSessionStatistics;
  RecordWorkController? _recordWork;
  GunDialogCoordinator? _gunDialogs;
  bool _exiting = false;
  int _processSwitchGen = 0;

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
        _recordWork = RecordWorkController(
          deviceControl: _deviceControl!,
          snapshotSource: CallbackProcessVideoSnapshotSource(
            _captureProcessVideoSnapshot,
          ),
          saveHandler: ProcessVideoSaveHandler(
            repository: SqliteProcessVideoRepository(),
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
    LaserEnableLedHolder.instance.clear();
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
    WorkStatusDialogHost.closeDialog();
    final message = switch (event) {
      DeviceControlSafetyEvent.keySwitchOffWhileLaser =>
        DeviceControlFeedbackCopy.keySwitchOffError,
      DeviceControlSafetyEvent.emergencyStop =>
        DeviceControlFeedbackCopy.emergencyStopError,
    };
    unawaited(
      OperationFailedDialogHost.show(
        context,
        message: message,
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
        return;
      }
    }
    _selectDefaultForType(controller);
  }

  /// Assign [_draft] and mirror into [_sessions] for the active process type.
  void _setActiveDraft(EngineerModeDraft? draft) {
    _draft = draft;
    if (draft == null) {
      _sessions.remove(_processType);
    } else {
      _sessions[_processType] = draft;
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

  /// Switch process tab: keep each type's in-memory session (lws-ui behavior).
  ///
  /// UI updates first (Quick Mode pattern). Modbus clear / laser off runs in
  /// the background so tab chrome is not blocked. Record Work stays armed —
  /// encode stops when laser session ends (do not [RecordWorkController.stopRecordingForExit]).
  void _onProcessTypeChanged(ProcessType type) {
    if (type == _processType) {
      return;
    }
    final controller = ProcessLibraryScope.of(context);
    setState(() {
      if (_draft != null) {
        _sessions[_processType] = _draft!;
      }
      _processType = type;
      final cached = _sessions[type];
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
    unawaited(_syncDeviceForProcessType(type, gen));
  }

  /// Clears continuous wire, ends laser session, aligns Auto Wire with capability.
  Future<void> _syncDeviceForProcessType(ProcessType type, int gen) async {
    await _deviceControl?.clearContinuousWire();
    if (!mounted || gen != _processSwitchGen) {
      return;
    }
    await _deviceControl?.disableLaser();
    if (!mounted || gen != _processSwitchGen) {
      return;
    }
    if (type == ProcessType.continuousWelding) {
      await _deviceControl?.ensureAutoWireFeedDefault();
    } else if (_deviceControl?.autoWireFeed == true) {
      await _deviceControl?.setAutoWireFeed(false);
    }
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
        ProcessModeToast.show(
          context,
          DeviceControlFeedbackCopy.messageForDisable(err),
        );
      }
      return;
    }
    _exiting = true;
    try {
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

  Future<void> _openFavorites() async {
    final controller = ProcessLibraryScope.of(context);
    final presets =
        controller.engineerPresets(processType: _processType).toList();
    if (presets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No more favorites')),
      );
      return;
    }

    final box =
        _moreFavoritesKey.currentContext?.findRenderObject() as RenderBox?;
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
    _workSessionStatistics?.configureNextSession(
      modeType: _statisticsModeType(_processType),
      autoWireFeedEnabled: _processType == ProcessType.continuousWelding &&
          (_deviceControl?.autoWireFeed ?? false),
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

    final library = ProcessLibraryScope.of(context);
    final result = await library.apply(draft.preset);
    if (!mounted) {
      return false;
    }
    if (result.failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_applyFailureMessage(result.failure)),
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
        product.focusScaleRef(),
      );
    } catch (_) {
      return 0;
    }
  }

  String _applyFailureMessage(ProcessApplyFailure? failure) {
    return switch (failure) {
      ProcessApplyFailure.busy => 'Apply busy',
      ProcessApplyFailure.statusUnavailable => 'Check equipment status',
      ProcessApplyFailure.unsafeMachineState => 'Laser work in progress',
      ProcessApplyFailure.wireFeedingActive => 'Stop wire feed first',
      ProcessApplyFailure.baselineReadFailed => 'Baseline read failed',
      ProcessApplyFailure.processWriteFailed => 'Write failed',
      ProcessApplyFailure.processReadbackFailed => 'Readback mismatch',
      ProcessApplyFailure.processTypeWriteFailed => 'Process type write failed',
      ProcessApplyFailure.processTypeReadbackFailed =>
        'Process type readback mismatch',
      ProcessApplyFailure.partialApply => 'Partial apply',
      null => 'Apply failed',
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
    setState(() {
      _setActiveDraft(draft.resetToBaseline());
    });
    if (!mounted) {
      return;
    }
    // lws-ui `ToastUtils.showShort(R.string.reset_data_successfully)`.
    ProcessModeToast.show(context, 'Reset complete');
  }

  Future<void> _saveAsFavorite() async {
    final draft = _draft;
    if (draft == null) {
      return;
    }
    final name = await showCyberImeInputDialog(
      context: context,
      title: 'Process Parameter Name',
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
        'Name must be 32 characters or fewer',
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
      ProcessModeToast.show(context, 'Saved');
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
    final name = await showCyberImeInputDialog(
      context: context,
      title: 'Process name',
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
      child: Scaffold(
        backgroundColor: ProcessModeTokens.background,
        appBar: WorkModeStatusBar(
          mode: WorkMode.engineer,
          processType: _processType,
          backLabel: widget.fromQuickHandoff
              ? (AppLocalizations.of(context)?.equipmentStatusBack ?? 'Back')
              : (AppLocalizations.of(context)?.equipmentStatusHome ?? 'Home'),
          onBack: _onBack,
        ),
        body: ProcessModeToastLayer(
          child: CyberBlurBackdropScope(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const CyberBlurBackdropTarget(
                  child: ColoredBox(color: ProcessModeTokens.background),
                ),
                Column(
                  children: [
                    EngineerProcessTabBar(
                      processType: _processType,
                      onChanged: _onProcessTypeChanged,
                    ),
                    if (controller.loading && !controller.initialized)
                      const Expanded(
                          child: Center(child: CircularProgressIndicator()))
                    else if (draft == null)
                      const Expanded(
                        child: Center(
                          child: Text(
                            'No engineer processes for this type',
                            key: ValueKey('engineer-mode-empty'),
                            style: TextStyle(
                                color: Color(0xB3FFFFFF), fontSize: 16),
                          ),
                        ),
                      ),
                    if (draft != null)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 1,
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
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 2,
                                child: EngineerFrostPanel(
                                  key: const ValueKey(
                                      'engineer-parameters-panel'),
                                  edge: EngineerFrostEdge.bottomLeftTopRight,
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            24, 16, 16, 8),
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
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      draft.preset.name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Current Process Name',
                                                      key: ValueKey(
                                                        draft.fromQuickHandoff
                                                            ? 'engineer-mode-draft-uuid'
                                                            : 'engineer-mode-source-label',
                                                      ),
                                                      style: TextStyle(
                                                        color: accent
                                                            .withOpacity(0.9),
                                                        fontSize: 13,
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
                                              child: InkWell(
                                                key: _moreFavoritesKey,
                                                onTap: () {
                                                  CyberClickSoundRegistry
                                                      .playClick();
                                                  if (_favoritesOpen) {
                                                    return;
                                                  }
                                                  _openFavorites();
                                                },
                                                child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 12,
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Text(
                                                        'More Favorites',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 2),
                                                      Icon(
                                                        _favoritesOpen
                                                            ? Icons
                                                                .keyboard_arrow_down
                                                            : Icons
                                                                .chevron_right,
                                                        color: Colors.white,
                                                        size: 30,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
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
                                          onBeginEdit: _beginEditFromBuiltin,
                                          footer: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              8,
                                              0,
                                              12,
                                            ),
                                            child: Row(
                                              children: [
                                                // lws-ui FrostButton DEFAULT
                                                // (`engineer_pine_base_btn_style`).
                                                Expanded(
                                                  child: CyberButton(
                                                    key: const ValueKey(
                                                      'engineer-action-reset-default',
                                                    ),
                                                    stretch: true,
                                                    height: 56,
                                                    // lws-ui FrostButtonShape.ROUNDED
                                                    // (stadium) + top↔bottom rim light.
                                                    shape: CyberButtonShape
                                                        .rounded,
                                                    borderGradientCenter:
                                                        CyberBorderGradientCenter
                                                            .topBottom,
                                                    borderGradientColors:
                                                        _engineerActionPillBorder,
                                                    strokeWidth: 1.5,
                                                    onPressed: _resetToDefault,
                                                    child: const Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.restart_alt,
                                                          size: 20,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Flexible(
                                                          child: Text(
                                                            'Reset to Default',
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 22),
                                                Expanded(
                                                  child: CyberButton(
                                                    key: const ValueKey(
                                                      'engineer-action-save-favorite',
                                                    ),
                                                    stretch: true,
                                                    height: 56,
                                                    shape: CyberButtonShape
                                                        .rounded,
                                                    borderGradientCenter:
                                                        CyberBorderGradientCenter
                                                            .topBottom,
                                                    borderGradientColors:
                                                        _engineerActionPillBorder,
                                                    strokeWidth: 1.5,
                                                    onPressed:
                                                        controller.applying
                                                            ? null
                                                            : _saveAsFavorite,
                                                    child: const Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.bookmark_add,
                                                          size: 20,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Flexible(
                                                          child: Text(
                                                            'Save as Favorite',
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
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
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
