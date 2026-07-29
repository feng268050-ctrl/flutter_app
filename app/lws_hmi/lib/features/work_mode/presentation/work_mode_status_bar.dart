import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/status_bar/call_back_home_button.dart';
import 'package:lws_hmi/features/status_bar/status_bar_phase.dart';
import 'package:lws_hmi/features/work_mode/application/work_mode_equipment_status_controller.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_accent.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_assets.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_equipment_status.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Quick vs Engineer page chrome (not process type).
enum WorkMode { quick, engineer }

/// App-local status bar for Quick / Engineer (lws-ui `EquipmentStatusBar` parity).
///
/// Layout follows lws-ui: fixed, equal 160dp left/right rails and an Expanded
/// center rail. Back fills the left rail, equipment is centered in the
/// remaining width, and camera + clock are end-aligned in the right rail.
final class WorkModeStatusBar extends StatelessWidget
    implements PreferredSizeWidget {
  const WorkModeStatusBar({
    super.key,
    required this.mode,
    this.processType = ProcessType.continuousWelding,
    this.backEnabled = true,
    this.equipmentStatus,
    this.cameraStatus,
    this.onBack,
    this.clockNow,
    this.toolbarHeight = WorkModeStatusBarDimens.height,
  });

  final WorkMode mode;

  /// Drives Back-rail accent (weld orange / clean green / cut blue).
  final ProcessType processType;

  /// When false, Back uses gray chrome and does not navigate.
  final bool backEnabled;

  final WorkModeEquipmentStatus? equipmentStatus;
  final IpCameraUiStatus? cameraStatus;
  final VoidCallback? onBack;
  final DateTime Function()? clockNow;
  final double toolbarHeight;

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    final services = AppScope.maybeOf(context);
    final resolvedNow =
        clockNow ?? (services != null ? () => services.wallClock.now : null);
    final listenable = clockNow == null ? services?.wallClock : null;

    Widget body() {
      final accent = backEnabled
          ? WorkModeAccent.forProcessType(processType)
          : WorkModeAccent.disabled;
      return Material(
        key: ValueKey('work-mode-status-bar-${mode.name}'),
        color: WorkModeStatusBarDimens.background,
        child: SizedBox(
          height: toolbarHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // lws-ui left_rail: fixed 160dp; Back fills the complete slot.
              SizedBox(
                width: WorkModeStatusBarDimens.sideRailWidth,
                child: CallBackHomeButton(
                  key: const ValueKey('work-mode-status-back'),
                  accent: accent,
                  enabled: backEnabled,
                  label: AppLocalizations.of(context)?.equipmentStatusHome ??
                      'Home',
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                ),
              ),
              // lws-ui center_content: weight=1 + gravity=center.
              Expanded(
                child: Center(
                  child: _WorkModeEquipmentStrip(
                    status: equipmentStatus,
                  ),
                ),
              ),
              // lws-ui right_rail: fixed 160dp, end-aligned, 16dp end padding.
              SizedBox(
                width: WorkModeStatusBarDimens.sideRailWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      right: WorkModeStatusBarDimens.rightRailPadding,
                    ),
                    child: _WorkModeTrailing(
                      cameraStatus: cameraStatus,
                      clockNow: resolvedNow,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (listenable == null) {
      return body();
    }
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) => body(),
    );
  }
}

abstract final class WorkModeStatusBarDimens {
  /// lws-ui `equipment_status` minHeight / rail height.
  static const double height = 70;

  /// lws-ui `equipment_status_side_rail_width`.
  static const double sideRailWidth = 160;

  /// lws-ui right_rail `paddingEnd`.
  static const double rightRailPadding = 16;

  /// Gap between the five equipment status groups, scaled with their labels.
  static const double itemGap = 12;

  /// Equipment on/off icons, scaled with [statusLabelFontSize].
  static const double primaryIconSize = 38;

  /// Text ↔ icon gap within one equipment status group.
  static const double statusIconGap = 6;

  /// Design size for camera (same as HomeStatusBar `iconSize: 32` on 1280×800).
  static const double trailingIconSize = 32;

  /// lws-ui / home design canvas (see `home_page.dart` `_kDesignW` / `_kDesignH`).
  static const double designWidth = 1280;
  static const double designHeight = 800;

  /// Same scale Home applies: `32 * ((sx + sy) / 2)` with sx=w/1280, sy=h/800.
  /// Compensates `_matchFlutterPiDensity` FittedBox so camera matches Home.
  static double trailingIconSizeFor(Size layoutSize) {
    final sx = layoutSize.width / designWidth;
    final sy = layoutSize.height / designHeight;
    return trailingIconSize * ((sx + sy) / 2);
  }

  /// lws-ui `equipment_status_back_icon_size`.
  static const double backIconSize = 28;

  /// lws-ui Back `paddingStart` / `paddingEnd`.
  static const double backHorizontalPadding = 12;

  static const double edgeLineHeight = 3;

  /// Five equipment status labels.
  static const double statusLabelFontSize = 26;

  /// Home label; intentionally independent from the clock size.
  static const double homeLabelFontSize = 24;

  /// Clock size; camera and time retain their existing scale.
  static const double chromeLabelFontSize = 20;

  static const Color background = Colors.transparent;
  static const Color label = Color(0xFFFFFFFF);
  static const Color clock = Color(0xFFF2F2F2);
  static const Color backLabelDisabled = Color(0xFF909399);
}

final class _WorkModeEquipmentStrip extends StatefulWidget {
  const _WorkModeEquipmentStrip({this.status});

  final WorkModeEquipmentStatus? status;

  @override
  State<_WorkModeEquipmentStrip> createState() =>
      _WorkModeEquipmentStripState();
}

final class _WorkModeEquipmentStripState
    extends State<_WorkModeEquipmentStrip> {
  WorkModeEquipmentStatusController? _ctrl;
  WorkModeEquipmentStatus _status = WorkModeEquipmentStatus.unknown;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.status != null) {
      _status = widget.status!;
      return;
    }
    if (_ctrl != null) {
      return;
    }
    final services = AppScope.maybeOf(context);
    if (services == null) {
      return;
    }
    final ctrl = WorkModeEquipmentStatusController(services);
    ctrl.addListener(_onUpdate);
    _ctrl = ctrl;
    unawaited(ctrl.start());
  }

  @override
  void didUpdateWidget(covariant _WorkModeEquipmentStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != null) {
      _status = widget.status!;
    }
  }

  void _onUpdate() {
    final ctrl = _ctrl;
    if (!mounted || ctrl == null) {
      return;
    }
    setState(() => _status = ctrl.status);
  }

  @override
  void dispose() {
    final ctrl = _ctrl;
    ctrl?.removeListener(_onUpdate);
    ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status ?? _status;
    // Content-width group centered by parent; scaleDown only if the center
    // rail is too narrow (does not flex-shrink individual items).
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _EquipmentStatusItem(
            key: const ValueKey('work-mode-gun-switch'),
            label: 'Gun Switch',
            onAsset: WorkModeAssets.gunSwitchOn,
            offAsset: WorkModeAssets.gunSwitchOff,
            active: status.gunSwitchOn,
          ),
          const SizedBox(width: WorkModeStatusBarDimens.itemGap),
          _EquipmentStatusItem(
            key: const ValueKey('work-mode-ground-clamp'),
            label: 'Ground Clamp',
            onAsset: WorkModeAssets.groundClampOn,
            offAsset: WorkModeAssets.groundClampOff,
            active: status.groundClampOn,
          ),
          const SizedBox(width: WorkModeStatusBarDimens.itemGap),
          _EquipmentStatusItem(
            key: const ValueKey('work-mode-key-switch'),
            label: 'Key Switch',
            onAsset: WorkModeAssets.keySwitchOn,
            offAsset: WorkModeAssets.keySwitchOff,
            active: status.keySwitchOn,
          ),
          const SizedBox(width: WorkModeStatusBarDimens.itemGap),
          _EquipmentStatusItem(
            key: const ValueKey('work-mode-gas-flow'),
            label: 'Gas Flow',
            onAsset: WorkModeAssets.gasFlowOn,
            offAsset: WorkModeAssets.gasFlowOff,
            active: status.gasFlowOn,
          ),
          const SizedBox(width: WorkModeStatusBarDimens.itemGap),
          _EquipmentStatusItem(
            key: const ValueKey('work-mode-e-stop'),
            label: 'E-Stop',
            // lws-ui: triggered → stop_icon; clear → stop_icon_on
            onAsset: WorkModeAssets.eStopActive,
            offAsset: WorkModeAssets.eStopIdle,
            active: status.eStopTriggered,
          ),
        ],
      ),
    );
  }
}

final class _EquipmentStatusItem extends StatelessWidget {
  const _EquipmentStatusItem({
    super.key,
    required this.label,
    required this.onAsset,
    required this.offAsset,
    required this.active,
  });

  final String label;
  final String onAsset;
  final String offAsset;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final iconSize = WorkModeStatusBarDimens.primaryIconSize;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: WorkModeStatusBarDimens.label,
            fontSize: WorkModeStatusBarDimens.statusLabelFontSize,
            height: 1,
          ),
        ),
        const SizedBox(width: WorkModeStatusBarDimens.statusIconGap),
        Image.asset(
          active ? onAsset : offAsset,
          width: iconSize,
          height: iconSize,
          filterQuality: FilterQuality.medium,
        ),
      ],
    );
  }
}

final class _WorkModeTrailing extends StatefulWidget {
  const _WorkModeTrailing({
    this.cameraStatus,
    this.clockNow,
  });

  final IpCameraUiStatus? cameraStatus;
  final DateTime Function()? clockNow;

  @override
  State<_WorkModeTrailing> createState() => _WorkModeTrailingState();
}

final class _WorkModeTrailingState extends State<_WorkModeTrailing> {
  IpCameraUiStatus _camera = IpCameraUiStatus.connecting;
  StreamSubscription<IpCameraUiStatus>? _cameraSub;
  bool _wired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_wired) {
      return;
    }
    _wired = true;
    if (widget.cameraStatus != null) {
      _camera = widget.cameraStatus!;
      return;
    }
    final services = AppScope.maybeOf(context);
    if (services == null || !services.ipCameraSupported) {
      return;
    }
    unawaited(() async {
      try {
        final session = await services.ensureIpCamera();
        if (!mounted) {
          return;
        }
        setState(() => _camera = session.currentStatus);
        await _cameraSub?.cancel();
        _cameraSub = session.status.listen((status) {
          if (mounted) {
            setState(() => _camera = status);
          }
        });
      } catch (_) {
        if (mounted) {
          setState(
            () =>
                _camera = const IpCameraUiStatus(phase: IpCameraUiPhase.failed),
          );
        }
      }
    }());
  }

  @override
  void didUpdateWidget(covariant _WorkModeTrailing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cameraStatus != null &&
        widget.cameraStatus != oldWidget.cameraStatus) {
      _camera = widget.cameraStatus!;
    }
  }

  @override
  void dispose() {
    unawaited(_cameraSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = widget.cameraStatus ?? _camera;
    final cameraSize = WorkModeStatusBarDimens.trailingIconSizeFor(
      MediaQuery.sizeOf(context),
    );
    return SizedBox(
      height: WorkModeStatusBarDimens.height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          KeyedSubtree(
            key: const ValueKey('work-mode-status-camera'),
            child: CyberCameraStatusIcon(
              status: mapCameraLinkStatus(camera.phase),
              size: cameraSize,
            ),
          ),
          const SizedBox(width: 10),
          CyberStatusBarClock(
            now: widget.clockNow,
            style: const TextStyle(
              color: WorkModeStatusBarDimens.clock,
              fontSize: WorkModeStatusBarDimens.chromeLabelFontSize,
              height: 1,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
