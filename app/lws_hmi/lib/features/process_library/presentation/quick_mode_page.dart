import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/process_library/application/process_library_controller.dart';
import 'package:lws_hmi/features/process_library/application/process_library_scope.dart';
import 'package:lws_hmi/features/process_library/application/process_parameter_applier.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/application/cnc_session_controller.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/application/gun_dialog_coordinator.dart';
import 'package:lws_hmi/features/process_mode/application/record_work_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_feedback_copy.dart';
import 'package:lws_hmi/features/process_video/application/process_video_save_handler.dart';
import 'package:lws_hmi/features/process_video/application/process_video_snapshot_factory.dart';
import 'package:lws_hmi/features/process_video/application/process_video_snapshot_source.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/features/process_video/infrastructure/sqlite_process_video_repository.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/domain/quick_mode_selection.dart';
import 'package:lws_hmi/features/process_mode/domain/quick_mode_selection_carry.dart';
import 'package:lws_hmi/features/process_mode/domain/laser_enable_reminder_copy.dart';
import 'package:lws_hmi/features/process_mode/presentation/cnc_connection_guide.dart';
import 'package:lws_hmi/features/process_mode/presentation/cnc_exit_dialog.dart';
import 'package:lws_hmi/features/process_mode/presentation/cnc_running_overlay.dart';
import 'package:lws_hmi/features/process_mode/presentation/laser_enable_region_frost.dart';
import 'package:lws_hmi/features/process_mode/presentation/laser_enable_reminder_dialog.dart';
import 'package:lws_hmi/features/process_mode/presentation/process_mode_toast.dart';
import 'package:lws_hmi/features/process_mode/presentation/operation_failed_dialog.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_device_controls.dart';
import 'package:lws_hmi/features/process_mode/presentation/work_status_dialog_host.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_laser_dashboard.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_mode_entry_tips_dialog.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_material_wheel.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_parameter_preview.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_process_wheel.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_scope.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_value_pick.dart';
import 'package:lws_hmi/features/process_mode/presentation/record_work_toggle.dart';
import 'package:lws_hmi/features/settings/application/common_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/length_unit_convert.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/laser_alarm_policy.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_scope.dart';
import 'package:lws_hmi/features/work_mode/presentation/work_mode_status_bar.dart';
import 'package:lws_hmi/gpio/laser_enable_led_holder.dart';

/// Quick Mode: process wheel + material/gear/dimension selection (U3).
final class QuickModePage extends StatefulWidget {
  const QuickModePage({super.key});

  @override
  State<QuickModePage> createState() => _QuickModePageState();
}

final class _QuickModePageState extends State<QuickModePage> {
  ProcessType _processType = ProcessType.continuousWelding;
  QuickModeSelection? _selection;
  Timer? _applyDebounce;
  String? _lastAppliedUuid;
  String? _statusMessage;
  DeviceControlController? _deviceControl;
  RecordWorkController? _recordWork;
  CncSessionController? _cncSession;
  GunDialogCoordinator? _gunDialogs;
  bool _exiting = false;

  /// Bumps on each accepted mode switch so stale Modbus sync is ignored.
  int _processSwitchGen = 0;

  @override
  void initState() {
    super.initState();
    QuickModeSelectionCarry.clear();
    LaserEnableLedHolder.instance.setWorkModel(_processType);
    scheduleEnsureModbusLive(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final services = AppScope.maybeOf(context);
      if (services != null) {
        if (_deviceControl == null) {
          _deviceControl = DeviceControlController(services);
          _deviceControl!.addListener(_onDeviceControlChanged);
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
          _startGunDialogCoordinator(services);
        }
        if (_cncSession == null) {
          _cncSession = CncSessionController(services);
          _cncSession!.addListener(_onCncSessionChanged);
        }
        setState(() {});
      }
      final controller = ProcessLibraryScope.of(context);
      unawaited(controller.initialize().then((_) {
        if (mounted) {
          _rebuildSelection(controller);
        }
      }));
    });
  }

  void _startGunDialogCoordinator(AppServices services) {
    final device = _deviceControl;
    if (device == null || _gunDialogs != null) {
      return;
    }
    _gunDialogs = GunDialogCoordinator(
      deviceControl: device,
      services: services,
      contextGetter: () => mounted ? context : null,
      showGroundLockAlarmGetter: () =>
          MiscSettingsScope.maybeOf(context)?.showGroundLockAlarm ?? false,
      resetGunLatchOnEnableOff: true,
    );
    unawaited(_gunDialogs!.start());
    _gunDialogs!.setActive(_processType != ProcessType.cncCutting);
  }

  @override
  void dispose() {
    LaserEnableLedHolder.instance.clear();
    _applyDebounce?.cancel();
    _gunDialogs?.dispose();
    _gunDialogs = null;
    _recordWork?.dispose();
    _deviceControl?.onSafetyEvent = null;
    _deviceControl?.removeListener(_onDeviceControlChanged);
    _deviceControl?.dispose();
    _cncSession?.removeListener(_onCncSessionChanged);
    _cncSession?.dispose();
    super.dispose();
  }

  void _onDeviceControlChanged() {
    if (mounted) {
      setState(() {});
    }
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

  void _onCncSessionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  List<ProcessPreset> _rowsFor(ProcessLibraryController controller) =>
      controller.quickPresets(processType: _processType).toList();

  void _rebuildSelection(ProcessLibraryController controller) {
    if (_processType == ProcessType.cncCutting) {
      setState(() {
        _selection = null;
        _statusMessage = null;
      });
      return;
    }
    final previous = _selection;
    final next = QuickModeSelectionBuilder.resolve(
      rows: _rowsFor(controller),
      processType: _processType,
      localMaterial: previous?.material,
      localGear: previous?.gear,
      localThickness: previous?.thickness,
      localSwingWidth: previous?.swingWidth,
    );
    setState(() {
      _selection = next;
      _statusMessage = null;
    });
    _scheduleApply(next.matched);
  }

  Future<void> _onProcessTypeChanged(ProcessType type) async {
    if (type == _processType) {
      return;
    }
    if (_deviceControl?.laserSessionArmed == true) {
      // Wheel may have moved locally; snap accents/selection chrome back.
      setState(() {});
      return;
    }
    final session = _cncSession;
    if (_processType == ProcessType.cncCutting &&
        session != null &&
        session.runningOverlay) {
      _showControlMessage('Turn off CNC first.');
      setState(() {});
      return;
    }
    // Update UI first (lws-ui `setModeType` is sync). Modbus wire sync must
    // not block wheel / accent feedback.
    if (_processType == ProcessType.cncCutting &&
        type != ProcessType.cncCutting) {
      unawaited(session?.leaveWithoutExitWrite());
    }
    setState(() => _processType = type);
    LaserEnableLedHolder.instance.setWorkModel(type);
    _gunDialogs?.setActive(type != ProcessType.cncCutting);
    _rebuildSelection(ProcessLibraryScope.of(context));
    if (type == ProcessType.cncCutting) {
      unawaited(session?.enter() ?? _enterCncWhenReady());
    }
    final gen = ++_processSwitchGen;
    unawaited(_syncDeviceForProcessType(type, gen));
  }

  /// Clears continuous wire and keeps Auto Wire Feed aligned with capability.
  Future<void> _syncDeviceForProcessType(ProcessType type, int gen) async {
    await _deviceControl?.clearContinuousWire();
    if (!mounted || gen != _processSwitchGen) {
      return;
    }
    if (type == ProcessType.continuousWelding) {
      await _deviceControl?.ensureAutoWireFeedDefault();
    } else if (_deviceControl?.autoWireFeed == true) {
      await _deviceControl?.setAutoWireFeed(false);
    }
  }

  Future<void> _enterCncWhenReady() async {
    final services = AppScope.maybeOf(context);
    if (services == null || !mounted) {
      return;
    }
    if (_cncSession == null) {
      _cncSession = CncSessionController(services);
      _cncSession!.addListener(_onCncSessionChanged);
    }
    await _cncSession!.enter();
    if (mounted) {
      setState(() {});
    }
  }

  /// Quick Back:
  /// - Laser Enable on → End of work only (stay on Quick Mode, not home).
  /// - Otherwise → home after laser/wire disarm (awaited).
  Future<void> _handleExit() async {
    if (_exiting) {
      return;
    }
    final session = _cncSession;
    if (session != null && session.blocksNavigation) {
      _showControlMessage('Turn off CNC first.');
      return;
    }
    final device = _deviceControl;
    if (device != null && device.laserEnable) {
      // Back as End of work: close laser, remain on Quick Mode.
      await _disableLaser();
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

  Future<void> _onCncExitPressed() async {
    final session = _cncSession;
    if (session == null) {
      return;
    }
    final confirmed = await showCncExitDialog(context);
    if (!confirmed || !mounted) {
      return;
    }
    await session.exitToGuide(writeContinuous: true);
  }

  void _onMaterialIndex(int index) {
    if (_deviceControl?.laserSessionArmed == true) {
      return;
    }
    final selection = _selection;
    if (selection == null || index < 0 || index >= selection.materials.length) {
      return;
    }
    final material = selection.materials[index];
    if (material == selection.material) {
      return;
    }
    QuickModeSelectionCarry.remember(material: material.storageValue);
    final next = QuickModeSelectionBuilder.resolve(
      rows: _rowsFor(ProcessLibraryScope.of(context)),
      processType: _processType,
      localMaterial: material,
      localGear: selection.gear,
      localThickness: selection.thickness,
      localSwingWidth: selection.swingWidth,
    );
    setState(() => _selection = next);
    _scheduleApply(next.matched);
  }

  void _onGearIndex(int index) {
    if (_deviceControl?.laserSessionArmed == true) {
      return;
    }
    final selection = _selection;
    if (selection == null || index < 0 || index >= selection.gears.length) {
      return;
    }
    final gear = selection.gears[index];
    if (gear == selection.gear) {
      return;
    }
    final next = QuickModeSelectionBuilder.withGear(
      current: selection,
      rows: _rowsFor(ProcessLibraryScope.of(context)),
      gear: gear,
    );
    setState(() => _selection = next);
    _scheduleApply(next.matched);
  }

  void _onDimensionIndex(int index) {
    if (_deviceControl?.laserSessionArmed == true) {
      return;
    }
    final selection = _selection;
    if (selection == null ||
        index < 0 ||
        index >= selection.dimensions.length) {
      return;
    }
    final dimension = selection.dimensions[index];
    if (dimension == selection.dimension) {
      return;
    }
    final next = QuickModeSelectionBuilder.withDimension(
      current: selection,
      rows: _rowsFor(ProcessLibraryScope.of(context)),
      dimension: dimension,
    );
    setState(() => _selection = next);
    _scheduleApply(next.matched);
  }

  void _scheduleApply(ProcessPreset? preset) {
    _applyDebounce?.cancel();
    if (preset == null) {
      return;
    }
    if (preset.uuid == _lastAppliedUuid) {
      return;
    }
    _applyDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      unawaited(_applyPreset(preset));
    });
  }

  Future<bool> _applyPreset(ProcessPreset preset) async {
    final controller = ProcessLibraryScope.of(context);
    final result = await controller.apply(preset);
    if (!mounted) {
      return false;
    }
    if (result.isSuccess) {
      _lastAppliedUuid = preset.uuid;
      setState(() => _statusMessage = null);
      return true;
    }
    final message = _applyFailureMessage(result.failure);
    setState(() => _statusMessage = message);
    // Prefer toast/snackbar — do not paint a persistent red corner banner.
    if (message != 'Baseline read failed' &&
        message != 'Laser work in progress' &&
        message != 'Check equipment status' &&
        message != 'Stop wire feed first') {
      _showControlMessage(message);
    }
    return false;
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
        'Process type readback failed',
      ProcessApplyFailure.partialApply => 'Partial apply',
      null => 'Apply failed',
    };
  }

  LaserAlarmPolicySnapshot _laserPolicy() {
    return AdvancedSettingsScope.maybeDangerousOf(context)?.policySnapshot ??
        const LaserAlarmPolicySnapshot(
          keepLaserOnWhileAlarmed: false,
          allowWorkAfterCameraAlarm: false,
          allowWorkAfterGasAlarm: false,
          allowWorkAfterLensContamination: false,
          allowWorkAfterFeederAlarm: false,
        );
  }

  String? _laserPreflight() {
    final control = _deviceControl;
    if (control == null) {
      return 'Device control unavailable';
    }
    final reason = control.preflightLaserEnable(
      warnAlarm: WarnAlarmScope.maybeOf(context),
      policy: _laserPolicy(),
    );
    if (reason == null) {
      return null;
    }
    if (reason == LaserEnableBlockReason.alarmBlocked) {
      unawaited(_presentLaserEnableAlarmBlock());
      return reason.message;
    }
    if (DeviceControlFeedbackCopy.isSafetyTipBlock(reason)) {
      // Key / E-stop not reset → tip dialog (not Toast).
      unawaited(_showSafetyTip(
          DeviceControlFeedbackCopy.tipForLaserEnableBlock(reason)));
      return reason.message;
    }
    return reason.message;
  }

  Future<void> _showSafetyTip(String message) async {
    if (!mounted) {
      return;
    }
    await OperationFailedDialogHost.show(context, message: message);
  }

  Future<void> _presentLaserEnableAlarmBlock() async {
    final warn = WarnAlarmScope.maybeOf(context);
    if (warn == null || !mounted) {
      return;
    }
    await warn.presentLaserEnableBlock(policy: _laserPolicy());
  }

  Future<void> _handleLaserEnableBlock(LaserEnableBlockReason reason) async {
    if (reason == LaserEnableBlockReason.alarmBlocked) {
      await _presentLaserEnableAlarmBlock();
      return;
    }
    if (DeviceControlFeedbackCopy.isSafetyTipBlock(reason)) {
      await _showSafetyTip(
        DeviceControlFeedbackCopy.tipForLaserEnableBlock(reason),
      );
      return;
    }
    _showControlMessage(reason.message);
  }

  ProcessVideoSnapshot? _captureProcessVideoSnapshot() {
    return ProcessVideoSnapshotFactory.fromPreset(
      processType: _processType,
      preset: _selection?.matched,
      materialFallback: _selection?.material,
    );
  }

  Future<void> _confirmAndEnableLaser() async {
    final control = _deviceControl;
    final preset = _selection?.matched;
    if (control == null || preset == null) {
      _showControlMessage('Select a valid process preset first');
      return;
    }
    final pre = control.preflightLaserEnable(
      warnAlarm: WarnAlarmScope.maybeOf(context),
      policy: _laserPolicy(),
    );
    if (pre != null) {
      await _handleLaserEnableBlock(pre);
      return;
    }

    final focusScaleRef = await _focusScaleRef();
    if (!mounted) {
      return;
    }
    final confirmed = await showLaserEnableReminderDialog(
      context: context,
      processType: _processType,
      session: LaserEnableReminderSession.quick,
      focusScaleRef: focusScaleRef,
    );
    if (confirmed == null || !mounted) {
      return;
    }
    if (confirmed.dontShowAgain) {
      LaserEnableReminderGate.suppress(LaserEnableReminderSession.quick);
    }

    final second = control.preflightLaserEnable(
      warnAlarm: WarnAlarmScope.maybeOf(context),
      policy: _laserPolicy(),
    );
    if (second != null) {
      await _handleLaserEnableBlock(second);
      return;
    }
    final warnAlarm = WarnAlarmScope.maybeOf(context);
    final policy = _laserPolicy();
    final thresholds = AdvancedSettingsScope.maybeThresholdsOf(context);

    // Stop continuous feed before apply — same prelude as enableLaser, and
    // avoids WireFeedingActive interlock on the process write.
    if (control.wireWork || control.wireFeedingOn) {
      final wireErr = await control.stopWire();
      if (wireErr != null && mounted) {
        _showControlMessage(wireErr.message);
        return;
      }
    }

    // Stale control.laser_enable on the wire (failed prior disable) makes the
    // process interlock report "Laser work in progress". lws-ui writes process
    // params while turning enable on without that guard — clear hardware first.
    await control.forceDisableLaserForSafety();
    if (!mounted) {
      return;
    }

    // Match lws-ui ordering: current process + advanced settings, then control.
    final applied = await _applyPreset(preset);
    if (!mounted) {
      return;
    }
    if (!applied) {
      _showControlMessage(_statusMessage ?? 'Process apply failed');
      return;
    }
    // lws-ui QuickProcessParametersDataViewModel.sendAdvanceSettingForLaserEnable:
    // laserEndPower = process laser × 0.97, then write advanced settings.
    if (thresholds != null) {
      await thresholds.syncAndSendLaserTerminationPower(
        preset.parameters.values['process.laser_power'],
      );
    }
    final error = await control.enableLaser(
      warnAlarm: warnAlarm,
      policy: policy,
    );
    if (error != null && mounted) {
      await _handleLaserEnableBlock(error);
    }
  }

  Future<void> _disableLaser() async {
    final error = await _deviceControl?.disableLaser();
    if (error != null && mounted) {
      ProcessModeToast.show(
        context,
        DeviceControlFeedbackCopy.messageForDisable(error),
      );
    }
  }

  void _showControlMessage(String message) {
    if (!mounted) {
      return;
    }
    ProcessModeToast.show(context, message);
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

  Future<void> _openEngineerDraft() async {
    final matched = _selection?.matched;
    if (matched == null || _processType == ProcessType.cncCutting) {
      return;
    }
    final control = _deviceControl;
    // Session only — emission feedback alone must not demand End of work.
    if (control != null && control.laserSessionArmed) {
      _showControlMessage(DeviceControlFeedbackCopy.endOfWorkFirst);
      return;
    }
    if (!EngineerModeEntryTipGate.isSuppressedThisBoot) {
      final result = await showEngineerModeEntryTipsDialog(context);
      if (result == null || !mounted) {
        return;
      }
      if (result.dontShowAgain) {
        EngineerModeEntryTipGate.suppressForThisBoot();
      }
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushNamed(
      AppRoutes.engineerMode,
      arguments: EngineerModeRouteArgs(
        processType: _processType,
        presetUuid: matched.uuid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ProcessLibraryScope.of(context);
    final selection = _selection;
    final isCnc = _processType == ProcessType.cncCutting;
    final showPickers = !isCnc && selection != null;

    final materialIndex = selection == null || selection.material == null
        ? 0
        : selection.materials.indexOf(selection.material!);
    final gearIndex = selection == null || selection.gear == null
        ? 0
        : selection.gears.indexOf(selection.gear!);
    final dimensionIndex = selection == null || selection.dimension == null
        ? 0
        : selection.dimensions.indexOf(selection.dimension!);
    final highlightR = ProcessModeDimens.outerHighlightRadiusFor(
      MediaQuery.sizeOf(context),
    );

    final cncSession = _cncSession;
    final device = _deviceControl;

    Widget stackForLaser(bool laserEnable) {
      // lws-ui BlurUtils (Quick only — Engineer has no region frost):
      // process plate / material / side ops → σ=15 snapshot + hide wheels.
      // More Parameters → INVISIBLE when armed (not blurred).
      // Gear / thickness stay sharp with click disabled.
      final selectorsInteractive = !laserEnable;
      final processWheel = laserEnable
          ? Align(
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: const Offset(0, ProcessModeDimens.quickSelectorNudgeY),
                child: SizedBox(
                  width: ProcessModeDimens.laserEnableProcessFrostWidth,
                  height: ProcessModeDimens.laserEnableProcessFrostHeight,
                  child: LaserEnableRegionFrost(
                    armed: true,
                    child: QuickModeProcessWheel(
                      processType: _processType,
                      showAccents: false,
                      onChanged: (type) =>
                          unawaited(_onProcessTypeChanged(type)),
                    ),
                  ),
                ),
              ),
            )
          : Transform.translate(
              offset: const Offset(0, ProcessModeDimens.quickSelectorNudgeY),
              child: QuickModeProcessWheel(
                processType: _processType,
                onChanged: (type) => unawaited(_onProcessTypeChanged(type)),
              ),
            );

      return Stack(
        clipBehavior: Clip.none,
        children: [
          processWheel,
          if (isCnc)
            Positioned(
              left: ProcessModeDimens.cncGuideLeftInset,
              top: ProcessModeDimens.cncGuideTopInset,
              right: ProcessModeDimens.cncGuideRightInset,
              bottom: ProcessModeDimens.cncGuideBottomInset,
              child: CncConnectionGuide(
                linkStatus: cncSession?.linkStatus ?? CncLinkStatus.connecting,
              ),
            ),
          if (controller.loading && !controller.initialized)
            const Center(child: CircularProgressIndicator()),
          if (!isCnc && device != null && _recordWork != null)
            Positioned(
              top: ProcessModeDimens.quickTopChromeTop,
              left: ProcessModeDimens.quickTopChromeInset,
              child: RecordWorkToggle(
                key: const ValueKey('quick-mode-record-work'),
                controller: _recordWork!,
                processType: _processType,
                compact: true,
              ),
            ),
          if (showPickers) ...[
            if (!laserEnable)
              Positioned(
                top: ProcessModeDimens.quickTopChromeTop,
                right: ProcessModeDimens.quickTopChromeInset,
                child: QuickModeMoreParametersButton(
                  enabled: selection.matched != null,
                  onPressed: _openEngineerDraft,
                ),
              ),
            Center(
              child: QuickModeLaserDashboard(
                processType: _processType,
                gasPressureKpa: device?.gasPressureKpa ?? 0,
                laserEnable: device?.laserEnable ?? false,
                laserOn: device?.laserOn ?? false,
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: Offset(
                  QuickModePickerDimens.gearPickCenterFromPageCenter(
                    highlightR,
                  ),
                  ProcessModeDimens.pickerVerticalFromPageCenter,
                ),
                child: QuickModeGearPick(
                  processType: _processType,
                  gears: selection.gears,
                  selectedIndex: gearIndex < 0 ? 0 : gearIndex,
                  onChanged: _onGearIndex,
                  interactionEnabled: selectorsInteractive,
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: Offset(
                  QuickModePickerDimens.thicknessPickCenterFromPageCenter(
                    highlightR,
                  ),
                  ProcessModeDimens.pickerVerticalFromPageCenter,
                ),
                child: Builder(
                  builder: (context) {
                    final unitStore = CommonSettingsScope.maybeOf(context);
                    Widget pick(bool useMm) {
                      final unit = useMm ? 'mm' : 'in';
                      return QuickModeDimensionPick(
                        processType: _processType,
                        title: selection.useSwingWidth
                            ? 'Swing Width ($unit)'
                            : 'Thickness ($unit)',
                        dimensions: selection.dimensions,
                        selectedIndex: dimensionIndex < 0 ? 0 : dimensionIndex,
                        onChanged: _onDimensionIndex,
                        useMmUnit: useMm,
                        interactionEnabled: selectorsInteractive,
                      );
                    }

                    if (unitStore == null) {
                      return pick(true);
                    }
                    return ListenableBuilder(
                      listenable: unitStore,
                      builder: (context, _) => pick(
                        LengthUnitConvert.isMetric(unitStore.unit),
                      ),
                    );
                  },
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Transform.translate(
                offset: const Offset(
                  0,
                  ProcessModeDimens.materialVerticalOffset,
                ),
                child: LaserEnableRegionFrost(
                  armed: laserEnable,
                  child: QuickModeMaterialWheel(
                    materials: selection.materials,
                    selectedIndex: materialIndex < 0 ? 0 : materialIndex,
                    onChanged: _onMaterialIndex,
                  ),
                ),
              ),
            ),
          ],
          if (!isCnc &&
              controller.initialized &&
              selection != null &&
              selection.materials.isEmpty)
            const Center(
              child: Text(
                'No compatible quick-mode process library is installed.',
                key: ValueKey('quick-mode-empty-library'),
                style: TextStyle(
                  color: Color(0xB3FFFFFF),
                  fontSize: 16,
                ),
              ),
            ),
          if (!isCnc && device != null)
            Positioned.fill(
              child: QuickModeDeviceControls(
                controller: device,
                processType: _processType,
                laserPreflight: _laserPreflight,
                onEnableConfirmed: _confirmAndEnableLaser,
                onDisable: _disableLaser,
              ),
            ),
          if (isCnc && cncSession != null && cncSession.runningOverlay)
            Positioned.fill(
              child: CncRunningOverlay(
                onExitPressed: _onCncExitPressed,
              ),
            ),
        ],
      );
    }

    Widget scaffoldForLaser(bool laserEnable) {
      return Scaffold(
        backgroundColor: ProcessModeTokens.quickRootBackground,
        appBar: WorkModeStatusBar(
          mode: WorkMode.quick,
          processType: _processType,
          onBack: _onBack,
        ),
        body: ProcessModeToastLayer(
          child: CyberBlurBackdropScope(
            child: ColoredBox(
              color: ProcessModeTokens.quickRootBackground,
              child: CyberBlurBackdropTarget(
                child: stackForLaser(laserEnable),
              ),
            ),
          ),
        ),
      );
    }

    final body = device == null
        ? scaffoldForLaser(false)
        : AnimatedBuilder(
            animation: device,
            builder: (context, _) => scaffoldForLaser(device.laserSessionArmed),
          );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        unawaited(_handleExit());
      },
      child: body,
    );
  }
}
