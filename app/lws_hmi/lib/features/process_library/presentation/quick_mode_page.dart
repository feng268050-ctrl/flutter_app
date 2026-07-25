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
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/domain/quick_mode_selection.dart';
import 'package:lws_hmi/features/process_mode/domain/quick_mode_selection_carry.dart';
import 'package:lws_hmi/features/process_mode/domain/laser_enable_reminder_copy.dart';
import 'package:lws_hmi/features/process_mode/presentation/cnc_connection_guide.dart';
import 'package:lws_hmi/features/process_mode/presentation/cnc_exit_dialog.dart';
import 'package:lws_hmi/features/process_mode/presentation/cnc_running_overlay.dart';
import 'package:lws_hmi/features/process_mode/presentation/laser_enable_reminder_dialog.dart';
import 'package:lws_hmi/features/process_mode/presentation/process_mode_toast.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_device_controls.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_laser_dashboard.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_mode_entry_tips_dialog.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_material_wheel.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_parameter_preview.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_process_wheel.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_value_pick.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/laser_alarm_policy.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_scope.dart';
import 'package:lws_hmi/features/work_mode/presentation/work_mode_status_bar.dart';

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
  CncSessionController? _cncSession;

  @override
  void initState() {
    super.initState();
    QuickModeSelectionCarry.clear();
    scheduleEnsureModbusLive(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final services = AppScope.maybeOf(context);
      if (services != null) {
        if (_deviceControl == null) {
          _deviceControl = DeviceControlController(services);
          unawaited(_deviceControl!.start());
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

  @override
  void dispose() {
    _applyDebounce?.cancel();
    _deviceControl?.dispose();
    _cncSession?.removeListener(_onCncSessionChanged);
    _cncSession?.dispose();
    super.dispose();
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

  void _onProcessTypeChanged(ProcessType type) {
    if (type == _processType) {
      return;
    }
    final session = _cncSession;
    if (_processType == ProcessType.cncCutting &&
        session != null &&
        session.runningOverlay) {
      _showControlMessage('Turn off CNC first.');
      return;
    }
    if (_processType == ProcessType.cncCutting &&
        type != ProcessType.cncCutting) {
      unawaited(session?.leaveWithoutExitWrite());
    }
    setState(() => _processType = type);
    _rebuildSelection(ProcessLibraryScope.of(context));
    if (type == ProcessType.cncCutting) {
      unawaited(session?.enter() ?? _enterCncWhenReady());
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

  void _onBack() {
    final session = _cncSession;
    if (session != null && session.blocksNavigation) {
      _showControlMessage('Turn off CNC first.');
      return;
    }
    Navigator.of(context).maybePop();
  }

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
    setState(() {
      _statusMessage = _applyFailureMessage(result.failure);
    });
    return false;
  }

  String _applyFailureMessage(ProcessApplyFailure? failure) {
    return switch (failure) {
      ProcessApplyFailure.busy => 'Apply busy',
      ProcessApplyFailure.unsafeMachineState => 'Laser work in progress',
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
    return control
        .preflightLaserEnable(
          warnAlarm: WarnAlarmScope.maybeOf(context),
          policy: _laserPolicy(),
        )
        ?.message;
  }

  Future<void> _confirmAndEnableLaser() async {
    final control = _deviceControl;
    final preset = _selection?.matched;
    if (control == null || preset == null) {
      _showControlMessage('Select a valid process preset first');
      return;
    }
    final blocked = _laserPreflight();
    if (blocked != null) {
      _showControlMessage(blocked);
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

    final secondBlock = _laserPreflight();
    if (secondBlock != null) {
      _showControlMessage(secondBlock);
      return;
    }
    final warnAlarm = WarnAlarmScope.maybeOf(context);
    final policy = _laserPolicy();
    final thresholds = AdvancedSettingsScope.maybeThresholdsOf(context);

    // Match lws-ui ordering: current process + advanced settings, then control.
    final applied = await _applyPreset(preset);
    if (!mounted) {
      return;
    }
    if (!applied) {
      _showControlMessage(_statusMessage ?? 'Process apply failed');
      return;
    }
    if (thresholds != null) {
      await thresholds.commit(thresholds.values);
    }
    final error = await control.enableLaser(
      warnAlarm: warnAlarm,
      policy: policy,
    );
    if (error != null && mounted) {
      _showControlMessage(error.message);
    }
  }

  Future<void> _disableLaser() async {
    final error = await _deviceControl?.disableLaser();
    if (error != null && mounted) {
      _showControlMessage(error.message);
    }
  }

  void _showControlMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
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
    final laserActive = _deviceControl != null &&
        (_deviceControl!.laserEnable || _deviceControl!.laserOn);

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
    final processWheel = Transform.translate(
      offset: const Offset(0, ProcessModeDimens.quickSelectorNudgeY),
      child: QuickModeProcessWheel(
        processType: _processType,
        onChanged: _onProcessTypeChanged,
      ),
    );

    return Scaffold(
      backgroundColor: ProcessModeTokens.quickRootBackground,
      appBar: WorkModeStatusBar(
        mode: WorkMode.quick,
        processType: _processType,
        onBack: _onBack,
      ),
      // In-page toast + capture scope for laser reminder frost.
      body: ProcessModeToastLayer(
        child: CyberBlurBackdropScope(
          child: ColoredBox(
            color: ProcessModeTokens.quickRootBackground,
            child: CyberBlurBackdropTarget(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
            // Wheel under content (Android accent elev 0 / wheel only on the
            // left). CNC guide is Positioned to the right so its bright frame
            // is never covered by the expand wheel layer.
            processWheel,
            if (isCnc)
              Positioned(
                left: ProcessModeDimens.cncGuideLeftInset,
                top: ProcessModeDimens.cncGuideTopInset,
                right: ProcessModeDimens.cncGuideRightInset,
                bottom: ProcessModeDimens.cncGuideBottomInset,
                child: CncConnectionGuide(
                  linkStatus:
                      cncSession?.linkStatus ?? CncLinkStatus.connecting,
                ),
              ),
            if (controller.loading && !controller.initialized)
              const Center(child: CircularProgressIndicator()),
            if (showPickers) ...[
              Positioned(
                top: 20,
                right: 32,
                child: QuickModeMoreParametersButton(
                  enabled: selection.matched != null && !laserActive,
                  onPressed: _openEngineerDraft,
                ),
              ),
              // Center laser dashboard — visual anchor.
              if (_deviceControl != null)
                Center(
                  child: AnimatedBuilder(
                    animation: _deviceControl!,
                    builder: (context, _) {
                      final ctrl = _deviceControl!;
                      return QuickModeLaserDashboard(
                        processType: _processType,
                        gasPressureKpa: ctrl.gasPressureKpa,
                        laserEnable: ctrl.laserEnable,
                        laserOn: ctrl.laserOn,
                      );
                    },
                  ),
                )
              else
                Center(
                  child: QuickModeLaserDashboard(
                    processType: _processType,
                    gasPressureKpa: 0,
                    laserEnable: false,
                    laserOn: false,
                  ),
                ),
              // Gear / thickness: value-wheel center = accent midline (ring-hug).
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
                  child: QuickModeDimensionPick(
                    processType: _processType,
                    title: selection.useSwingWidth
                        ? 'Swing Width (mm)'
                        : 'Thickness (mm)',
                    dimensions: selection.dimensions,
                    selectedIndex: dimensionIndex < 0 ? 0 : dimensionIndex,
                    onChanged: _onDimensionIndex,
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
                  child: QuickModeMaterialWheel(
                    materials: selection.materials,
                    selectedIndex: materialIndex < 0 ? 0 : materialIndex,
                    onChanged: _onMaterialIndex,
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
            // Keep operator safety feedback visible, but do not expose the
            // internal process-library baseline-read failure in Quick mode.
            if (_statusMessage != null &&
                _statusMessage != 'Baseline read failed')
              Positioned(
                left: 40,
                bottom: 24,
                child: Text(
                  _statusMessage!,
                  key: const ValueKey('quick-mode-status-message'),
                  style: const TextStyle(
                    color: Color(0xFFFF8A80),
                    fontSize: 14,
                  ),
                ),
              ),
            if (!isCnc && _deviceControl != null)
              Positioned.fill(
                child: QuickModeDeviceControls(
                  controller: _deviceControl!,
                  processType: _processType,
                  laserPreflight: _laserPreflight,
                  onEnableConfirmed: _confirmAndEnableLaser,
                  onDisable: _disableLaser,
                ),
              ),
            if (isCnc &&
                cncSession != null &&
                cncSession.runningOverlay)
              Positioned.fill(
                child: CncRunningOverlay(
                  onExitPressed: _onCncExitPressed,
                ),
              ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
