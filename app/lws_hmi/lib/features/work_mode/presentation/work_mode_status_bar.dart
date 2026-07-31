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
/// Layout uses fixed, equal side rails and an Expanded center rail. Back fills
/// the left rail (label centered). Each equipment status is a label+icon group
/// with a fixed icon size; inter-group gaps share leftover width equally so
/// labels stay fully visible when possible. Camera + clock are centered in the
/// right rail.
final class WorkModeStatusBar extends StatelessWidget
    implements PreferredSizeWidget {
  const WorkModeStatusBar({
    super.key,
    required this.mode,
    this.processType = ProcessType.continuousWelding,
    this.backEnabled = true,
    this.backLabel,
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

  /// Left-rail caption. Defaults to Home; Engineer←Quick uses Back.
  final String? backLabel;

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
              // Fixed left rail; Back fills the complete slot.
              SizedBox(
                width: WorkModeStatusBarDimens.sideRailWidth,
                child: CallBackHomeButton(
                  key: const ValueKey('work-mode-status-back'),
                  accent: accent,
                  enabled: backEnabled,
                  label: backLabel ??
                      AppLocalizations.of(context)?.equipmentStatusHome ??
                      'Home',
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                ),
              ),
              // Label+icon groups: fixed icon size, equal gaps; labels may ellipsize.
              Expanded(
                child: _WorkModeEquipmentStrip(
                  status: equipmentStatus,
                ),
              ),
              // Fixed right rail; camera + clock centered (mirror Home).
              SizedBox(
                width: WorkModeStatusBarDimens.sideRailWidth,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
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

  /// Soft target for inter-group spacing when the center rail has spare width.
  /// Actual gaps shrink first so labels can stay fully visible.
  static const double equipmentItemGap = 28;

  /// Equipment on/off icons (not scaled by the status-strip layout).
  static const double primaryIconSize = 50;

  /// Text ↔ icon gap within one equipment status group.
  static const double statusIconGap = 0;

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

  /// Five equipment status labels (keep compact when icons grow).
  static const double statusLabelFontSize = 20;

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
    const specs = <({String key, String label, String on, String off})>[
      (
        key: 'work-mode-gun-switch',
        label: 'Gun Switch',
        on: WorkModeAssets.gunSwitchOn,
        off: WorkModeAssets.gunSwitchOff,
      ),
      (
        key: 'work-mode-ground-clamp',
        label: 'Ground Clamp',
        on: WorkModeAssets.groundClampOn,
        off: WorkModeAssets.groundClampOff,
      ),
      (
        key: 'work-mode-key-switch',
        label: 'Key Switch',
        on: WorkModeAssets.keySwitchOn,
        off: WorkModeAssets.keySwitchOff,
      ),
      (
        key: 'work-mode-gas-flow',
        label: 'Gas Flow',
        on: WorkModeAssets.gasFlowOn,
        off: WorkModeAssets.gasFlowOff,
      ),
      (
        key: 'work-mode-e-stop',
        label: 'E-Stop',
        on: WorkModeAssets.eStopActive,
        off: WorkModeAssets.eStopIdle,
      ),
    ];
    final active = [
      status.gunSwitchOn,
      status.groundClampOn,
      status.keySwitchOn,
      status.gasFlowOn,
      status.eStopTriggered,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const labelStyle = TextStyle(
          fontSize: WorkModeStatusBarDimens.statusLabelFontSize,
          height: 1,
        );
        final labelWidths = <double>[
          for (final spec in specs)
            () {
              final painter = TextPainter(
                text: TextSpan(text: spec.label, style: labelStyle),
                maxLines: 1,
                textDirection: TextDirection.ltr,
              )..layout();
              return painter.width;
            }(),
        ];
        final iconBlock = WorkModeStatusBarDimens.primaryIconSize +
            WorkModeStatusBarDimens.statusIconGap;
        final contentWidth = labelWidths.fold<double>(0, (a, b) => a + b) +
            iconBlock * specs.length;
        final gapCount = specs.length - 1;
        final free = constraints.maxWidth - contentWidth;
        // Prefer full labels: shrink gaps first. Ellipsize only if still tight.
        final gap = free >= 0 ? free / gapCount : 0.0;
        final maxLabelWidth = free >= 0
            ? double.infinity
            : ((constraints.maxWidth - iconBlock * specs.length) / specs.length)
                .clamp(16.0, 400.0);

        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < specs.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                _EquipmentStatusItem(
                  key: ValueKey(specs[i].key),
                  label: specs[i].label,
                  onAsset: specs[i].on,
                  offAsset: specs[i].off,
                  active: active[i],
                  maxLabelWidth: maxLabelWidth,
                ),
              ],
            ],
          ),
        );
      },
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
    required this.maxLabelWidth,
  });

  final String label;
  final String onAsset;
  final String offAsset;
  final bool active;
  final double maxLabelWidth;

  @override
  Widget build(BuildContext context) {
    final iconSize = WorkModeStatusBarDimens.primaryIconSize;
    // Label + icon stay one group; icon size is fixed (not parent-scaled).
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxLabelWidth),
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: maxLabelWidth.isFinite
                ? TextOverflow.ellipsis
                : TextOverflow.visible,
            style: const TextStyle(
              color: WorkModeStatusBarDimens.label,
              fontSize: WorkModeStatusBarDimens.statusLabelFontSize,
              height: 1,
            ),
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
