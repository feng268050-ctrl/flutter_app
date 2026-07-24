import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/features/status_bar/status_bar_phase.dart';
import 'package:lws_hmi/features/work_mode/application/work_mode_equipment_status_controller.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_assets.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_equipment_status.dart';

/// Quick vs Engineer page chrome (not process type).
enum WorkMode { quick, engineer }

/// App-local status bar for Quick / Engineer (lws-ui `EquipmentStatusBar` parity).
///
/// Lives under `app/hmi/` — not exported from `cyber_ui`. Trailing chrome is
/// camera + clock only (no Wi‑Fi / Bluetooth). Center shows the five equipment
/// indicators with migrated lws-ui icons.
final class WorkModeStatusBar extends StatelessWidget
    implements PreferredSizeWidget {
  const WorkModeStatusBar({
    super.key,
    required this.mode,
    this.equipmentStatus,
    this.cameraStatus,
    this.onBack,
    this.clockNow,
    this.toolbarHeight = WorkModeStatusBarDimens.height,
  });

  final WorkMode mode;
  final WorkModeEquipmentStatus? equipmentStatus;
  final IpCameraUiStatus? cameraStatus;
  final VoidCallback? onBack;
  final DateTime Function()? clockNow;
  final double toolbarHeight;

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('work-mode-status-bar-${mode.name}'),
      color: WorkModeStatusBarDimens.background,
      child: SizedBox(
        height: toolbarHeight,
        child: Row(
          children: [
            SizedBox(
              width: WorkModeStatusBarDimens.sideRailWidth,
              child: _WorkModeBackButton(
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              ),
            ),
            Expanded(
              child: Center(
                child: _WorkModeEquipmentStrip(status: equipmentStatus),
              ),
            ),
            SizedBox(
              width: WorkModeStatusBarDimens.sideRailWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _WorkModeTrailing(
                    cameraStatus: cameraStatus,
                    clockNow: clockNow,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

abstract final class WorkModeStatusBarDimens {
  static const double height = 70;
  static const double sideRailWidth = 160;
  static const double itemGap = 28;
  static const double primaryIconSize = 40;
  static const double trailingIconSize = 36;
  static const double backIconSize = 28;
  static const Color background = Color(0xFF1E1E1E);
  static const Color accent = Color(0xFFFF8A00);
  static const Color label = Color(0xFFFFFFFF);
  static const Color clock = Color(0xFFF2F2F2);
}

final class _WorkModeBackButton extends StatelessWidget {
  const _WorkModeBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WorkModeStatusBarDimens.accent,
      child: InkWell(
        key: const ValueKey('work-mode-status-back'),
        onTap: () {
          CyberClickSoundRegistry.playClick();
          onPressed();
        },
        child: Column(
          children: [
            Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E1E1E), WorkModeStatusBarDimens.accent],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      WorkModeAssets.back,
                      width: WorkModeStatusBarDimens.backIconSize,
                      height: WorkModeStatusBarDimens.backIconSize,
                      filterQuality: FilterQuality.medium,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Back',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E1E1E), WorkModeStatusBarDimens.accent],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _WorkModeEquipmentStrip extends StatefulWidget {
  const _WorkModeEquipmentStrip({this.status});

  final WorkModeEquipmentStatus? status;

  @override
  State<_WorkModeEquipmentStrip> createState() =>
      _WorkModeEquipmentStripState();
}

final class _WorkModeEquipmentStripState extends State<_WorkModeEquipmentStrip> {
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
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: WorkModeStatusBarDimens.label,
            fontSize: 10,
            height: 1,
          ),
        ),
        const SizedBox(width: 8),
        Image.asset(
          active ? onAsset : offAsset,
          width: WorkModeStatusBarDimens.primaryIconSize,
          height: WorkModeStatusBarDimens.primaryIconSize,
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
            () => _camera = const IpCameraUiStatus(phase: IpCameraUiPhase.failed),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KeyedSubtree(
          key: const ValueKey('work-mode-status-camera'),
          child: CyberCameraStatusIcon(
            status: mapCameraLinkStatus(camera.phase),
            size: WorkModeStatusBarDimens.trailingIconSize,
          ),
        ),
        const SizedBox(width: 10),
        CyberStatusBarClock(
          now: widget.clockNow,
          style: const TextStyle(
            color: WorkModeStatusBarDimens.clock,
            fontSize: 12,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
