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
/// Home and camera+clock size to their content. Fixed
/// [WorkModeStatusBarDimens.clusterSideGap] separates Home↔cluster and
/// cluster↔trailing; the equipment strip [Expanded] absorbs leftover width in
/// its inter-group gaps so both side gaps stay equal and tight.
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
              // Content-sized Home; screen-edge inset kept on the outside.
              Padding(
                padding: const EdgeInsets.only(
                  left: WorkModeStatusBarDimens.screenEdgeInset,
                ),
                child: CallBackHomeButton(
                  key: const ValueKey('work-mode-status-back'),
                  accent: accent,
                  enabled: backEnabled,
                  expandWidth: false,
                  label: backLabel ??
                      AppLocalizations.of(context)?.equipmentStatusHome ??
                      'Home',
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(width: WorkModeStatusBarDimens.clusterSideGap),
              // Strip fills leftover; inter-group gaps absorb free width.
              Expanded(
                child: _WorkModeEquipmentStrip(
                  status: equipmentStatus,
                ),
              ),
              const SizedBox(width: WorkModeStatusBarDimens.clusterSideGap),
              Padding(
                padding: const EdgeInsets.only(
                  right: WorkModeStatusBarDimens.screenEdgeInset,
                ),
                child: _WorkModeTrailing(
                  cameraStatus: cameraStatus,
                  clockNow: resolvedNow,
                  use24HourFormat: services?.wallClock.use24HourFormat ?? true,
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

  /// Legacy fixed side-rail width (Settings [CallBackHomeButton.railWidth]).
  /// Quick / Engineer no longer use equal fixed rails — see [screenEdgeInset].
  static const double sideRailWidth = 160;

  /// Outer inset from screen edge to Home / camera+clock.
  static const double screenEdgeInset = 12;

  /// Home ↔ equipment cluster and cluster ↔ camera+clock (equal, fixed).
  static const double clusterSideGap = 25;

  /// Fallback / min inter-group spacing when the strip is not stretched.
  /// When the strip has free width, gaps grow evenly to fill it.
  static const double equipmentItemGap = 10;

  /// Equipment on/off icons (not scaled by the status-strip layout).
  static const double primaryIconSize = 50;

  /// Text ↔ icon gap within one equipment status group.
  /// Negative pulls the icon toward the label (mipmaps have transparent padding).
  static const double statusIconGap = -4;

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

  /// Five equipment status labels → [HmiTypography.statusBarLabel] (20).
  static const double statusLabelFontSize = 20.0;

  /// Home / Back label → [HmiTypography.statusBarAction] (24).
  static const double homeLabelFontSize = 24.0;

  /// Clock size → [HmiTypography.statusBarLabel] (20).
  static const double chromeLabelFontSize = 20.0;

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
    final l10n = AppLocalizations.of(context)!;
    final specs = <({String key, String label, String on, String off})>[
      (
        key: 'work-mode-gun-switch',
        label: l10n.gunSwitchLabel,
        on: WorkModeAssets.gunSwitchOn,
        off: WorkModeAssets.gunSwitchOff,
      ),
      (
        key: 'work-mode-ground-clamp',
        label: l10n.groundClampLabel,
        on: WorkModeAssets.groundClampOn,
        off: WorkModeAssets.groundClampOff,
      ),
      (
        key: 'work-mode-key-switch',
        label: l10n.keySwitchLabel,
        on: WorkModeAssets.keySwitchOn,
        off: WorkModeAssets.keySwitchOff,
      ),
      (
        key: 'work-mode-gas-flow',
        label: l10n.gasFlowLabel,
        on: WorkModeAssets.gasFlowOn,
        off: WorkModeAssets.gasFlowOff,
      ),
      (
        key: 'work-mode-e-stop',
        label: l10n.eStopLabel,
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
        final textScaler = MediaQuery.textScalerOf(context);
        final labelWidths = <double>[
          for (final spec in specs)
            () {
              final painter = TextPainter(
                text: TextSpan(text: spec.label, style: labelStyle),
                maxLines: 1,
                textDirection: TextDirection.ltr,
                textScaler: textScaler,
              )..layout();
              return painter.width;
            }(),
        ];
        final iconOverlap = WorkModeStatusBarDimens.statusIconGap < 0
            ? WorkModeStatusBarDimens.statusIconGap
            : 0.0;
        // Layout width accounts for label←icon overlap (visual translate).
        final iconLayoutWidth =
            WorkModeStatusBarDimens.primaryIconSize + iconOverlap;
        final contentWidth = labelWidths.fold<double>(0, (a, b) => a + b) +
            iconLayoutWidth * specs.length;
        final free = constraints.maxWidth - contentWidth;
        // Prefer full labels; ellipsize only when the strip cannot fit at
        // zero inter-group gaps.
        final maxLabelWidth = free >= 0
            ? double.infinity
            : ((constraints.maxWidth - iconLayoutWidth * specs.length) /
                    specs.length)
                .clamp(16.0, 400.0);

        // Spacers pin first/last to the Expanded edges so the outer
        // [clusterSideGap] stays exact; free width is split evenly.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < specs.length; i++) ...[
              if (i > 0) const Spacer(),
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
    final iconGap = WorkModeStatusBarDimens.statusIconGap;
    final iconLayoutWidth = iconSize + (iconGap < 0 ? iconGap : 0);
    // Label + icon stay one group; negative gap pulls icon toward the label
    // while layout width matches the visual trailing edge.
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
        if (iconGap > 0) SizedBox(width: iconGap),
        SizedBox(
          width: iconLayoutWidth,
          height: iconSize,
          child: iconGap < 0
              ? OverflowBox(
                  alignment: Alignment.centerRight,
                  minWidth: iconSize,
                  maxWidth: iconSize,
                  maxHeight: iconSize,
                  child: Image.asset(
                    active ? onAsset : offAsset,
                    width: iconSize,
                    height: iconSize,
                    filterQuality: FilterQuality.medium,
                  ),
                )
              : Image.asset(
                  active ? onAsset : offAsset,
                  width: iconSize,
                  height: iconSize,
                  filterQuality: FilterQuality.medium,
                ),
        ),
      ],
    );
  }
}

final class _WorkModeTrailing extends StatefulWidget {
  const _WorkModeTrailing({
    this.cameraStatus,
    this.clockNow,
    this.use24HourFormat = true,
  });

  final IpCameraUiStatus? cameraStatus;
  final DateTime Function()? clockNow;
  final bool use24HourFormat;

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
            use24HourFormat: widget.use24HourFormat,
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
