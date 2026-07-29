import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_product_session.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/features/ip_camera/presentation/ip_camera_preview.dart';
import 'package:lws_hmi/features/monitor/application/machine_status_controller.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_gauges.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Manual More Status route name (confirm bar). Distinct from gun-managed.
const liveMachineStatusManualRouteName = 'manual-live-machine-status';

/// lws-ui [MachineStatusOverlay] — light frost + live PR1 video (not Monitor route).
///
/// Quick Mode “More Status” opens this with a confirm action
/// (`MachineStatusOverlay.show(context, true)`). Gun path uses
/// [WorkStatusDialogHost.showNoConfirmDialog] (`showConfirmButton: false`).
Future<void> showLiveMachineStatusDialog(
  BuildContext context, {
  IpCameraPreviewPlayerFactory? playerFactory,
  bool showConfirmButton = true,
  String? routeName,
  void Function(BuildContext dialogContext)? onDialogContext,
}) {
  final panel = CyberPanelBorder(tone: CyberTone.light);
  return showDialog<void>(
    context: context,
    barrierDismissible: !showConfirmButton,
    barrierColor: CyberColors.scrim,
    routeSettings: RouteSettings(
      name: routeName ??
          (showConfirmButton
              ? liveMachineStatusManualRouteName
              : 'live-machine-status'),
    ),
    builder: (dialogContext) {
      onDialogContext?.call(dialogContext);
      // lws-ui `machine_status_dialog_screen_inset` = 2dp.
      const screenInset = 2.0;
      final size = MediaQuery.sizeOf(dialogContext);
      final maxW = (size.width - screenInset * 2).clamp(480.0, 1280.0);
      final maxH = (size.height - screenInset * 2).clamp(420.0, 800.0);
      return Material(
        type: MaterialType.transparency,
        child: Center(
          child: SizedBox(
            width: maxW,
            height: maxH,
            child: ClipRRect(
              borderRadius: panel.borderRadius,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: panel.borderRadius,
                  border: Border.all(
                    color: panel.flatBorderColor,
                    width: panel.width,
                  ),
                ),
                child: CyberModal(
                  sampleMode: CyberBlurSampleMode.firstFrame,
                  intensity: CyberBlurIntensity.high,
                  blurTint: CyberBlurTint.warm,
                  useFakeGlass: true,
                  borderRadius: panel.borderRadius,
                  // Horizontal pad 0 so the live frame sits 2px from screen edges.
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
                  child: _LiveMachineStatusBody(
                    playerFactory: playerFactory,
                    showConfirmButton: showConfirmButton,
                    onConfirm: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

final class _LiveMachineStatusBody extends StatefulWidget {
  const _LiveMachineStatusBody({
    required this.onConfirm,
    required this.showConfirmButton,
    this.playerFactory,
  });

  final VoidCallback onConfirm;
  final bool showConfirmButton;
  final IpCameraPreviewPlayerFactory? playerFactory;

  @override
  State<_LiveMachineStatusBody> createState() => _LiveMachineStatusBodyState();
}

final class _LiveMachineStatusBodyState extends State<_LiveMachineStatusBody> {
  static const _titleDark = Color(0xFF1A1A1A);
  static const _liveGaugeSidePad = 12.0;
  static const _liveStatusBottomPad = 12.0;
  static const _liveStatusGap = 8.0;

  IpCameraProductSession? _session;
  IpCameraUiStatus _status = IpCameraUiStatus.connecting;
  StreamSubscription<IpCameraUiStatus>? _statusSub;
  MachineStatusController? _machine;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bind());
    });
  }

  Future<void> _bind() async {
    final services = AppScope.maybeOf(context);
    if (services == null || !mounted) {
      setState(() => _error = 'Camera unavailable');
      return;
    }

    final machine = MachineStatusController(services);
    machine.addListener(_onMachine);
    unawaited(machine.start());

    try {
      final session = await services.ensureIpCamera();
      if (!mounted) {
        machine.dispose();
        return;
      }
      setState(() {
        _session = session;
        _machine = machine;
        _status = session.currentStatus;
        _error = null;
      });
      await _statusSub?.cancel();
      _statusSub = session.status.listen((s) {
        if (mounted) {
          setState(() => _status = s);
        }
      });
      await session.start();
      await session.ensureReady();
      if (mounted) {
        setState(() => _status = session.currentStatus);
      }
    } catch (e) {
      machine.removeListener(_onMachine);
      machine.dispose();
      if (mounted) {
        setState(() => _error = '$e');
      }
    }
  }

  void _onMachine() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    unawaited(_statusSub?.cancel() ?? Future<void>.value());
    final machine = _machine;
    machine?.removeListener(_onMachine);
    machine?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // lws-ui `real_time_machine_status_text` (not Monitor tab title).
    const liveTitle = 'Live Machine Status';

    final session = _session;
    // lws-ui LaserLiveMonitorOverlayFragment uses PR1; fall back to PR0.
    final rtsp = session?.previewPr1 ?? session?.previewPr0;
    final relayReady = session?.previewReady ?? false;
    final machine = _machine;

    final tiles = <(String, bool?)>[
      (l10n?.laserOnLabel ?? 'Laser', machine?.laserOn),
      (l10n?.blowOnLabel ?? 'Blow', machine?.blowOn),
      (l10n?.safetyLockLabel ?? 'Safety Lock', machine?.safetyLockOn),
      (l10n?.gunSwitchLabel ?? 'Gun Switch', machine?.gunSwitchOn),
      (l10n?.redLightLabel ?? 'Red Light', machine?.redLightOn),
      // Live-monitor copy (lws-ui live row); not the shorter Monitor label.
      ('Wire Feeder', machine?.wireFeedingOn),
    ];

    return Column(
      key: const ValueKey('live-machine-status-dialog'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            liveTitle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _titleDark,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.15,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ColoredBox(
            color: Colors.black,
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_error != null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        )
                      else
                        IpCameraPreview(
                          key: const ValueKey('live-machine-status-preview'),
                          rtspUrl: rtsp,
                          linkPhase: _status.phase,
                          relayReady: relayReady,
                          playerFactory:
                              widget.playerFactory ?? createIpCameraPreviewPlayer,
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: _liveGaugeSidePad),
                          child: _GaugePanel(
                            child: CurrentArcGauge(
                              value: machine?.gasPressureKpa ?? 0,
                              min: 0,
                              max: 1500,
                              majorTickEvery: 150,
                              unit: 'kPa',
                              titleLine1: l10n?.machineBlowTitle ?? 'Blow',
                              titleLine2: l10n?.machineBlowContent ?? 'Pressure',
                              size: _LiveGaugeDimens.gaugeSide,
                              trackWidth: _LiveGaugeDimens.trackWidth,
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding:
                              const EdgeInsets.only(right: _liveGaugeSidePad),
                          child: _GaugePanel(
                            child: CurrentArcGauge(
                              value: machine?.laserCurrentA ?? 0,
                              min: 0,
                              max: 100,
                              majorTickEvery: 10,
                              unit: 'A',
                              titleLine1:
                                  l10n?.machineLaserCurrentTitle ?? 'Laser',
                              titleLine2:
                                  l10n?.machineLaserCurrentContent ?? 'Current',
                              size: _LiveGaugeDimens.gaugeSide,
                              trackWidth: _LiveGaugeDimens.trackWidth,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    12,
                    0,
                    12,
                    _liveStatusBottomPad,
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < tiles.length; i++) ...[
                        if (i > 0) const SizedBox(width: _liveStatusGap),
                        Expanded(
                          child: _CompactStatusTile(
                            label: tiles[i].$1,
                            on: tiles[i].$2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.showConfirmButton) ...[
          const SizedBox(height: 10),
          Center(
            child: SizedBox(
              width: 280,
              child: CyberButton(
                key: const ValueKey('live-machine-status-confirm'),
                variant: CyberButtonVariant.primary,
                shape: CyberButtonShape.rounded,
                stretch: true,
                height: 44,
                onPressed: widget.onConfirm,
                child: const Text(
                  'Got it',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// lws-ui `laser_live_monitor_gauge_*` (panel size fixed).
abstract final class _LiveGaugeDimens {
  static const panelW = 280.0;
  static const panelH = 250.0;

  /// Prefer a little inset on all sides while keeping L=R and T=B.
  static double get gaugeSide {
    const minInset = 8.0;
    final short = panelH < panelW ? panelH : panelW;
    return short - 2 * minInset; // 250 - 16 = 234
  }

  static double get padH => (panelW - gaugeSide) / 2;
  static double get padV => (panelH - gaugeSide) / 2;

  static const trackWidth = 18.0;
}

final class _GaugePanel extends StatelessWidget {
  const _GaugePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Explicit equal insets: left==right (padH), top==bottom (padV).
    // Panel size stays [panelW]×[panelH].
    return SizedBox(
      width: _LiveGaugeDimens.panelW,
      height: _LiveGaugeDimens.panelH,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x99000000),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            _LiveGaugeDimens.padH,
            _LiveGaugeDimens.padV,
            _LiveGaugeDimens.padH,
            _LiveGaugeDimens.padV,
          ),
          child: SizedBox(
            width: _LiveGaugeDimens.gaugeSide,
            height: _LiveGaugeDimens.gaugeSide,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// lws-ui [MachineStatusStatusTile]: whole-tile fill, no status glyph.
///
/// Success → `machine_status_tile_success_fill` (#FFF46E01);
/// idle / undetected → `machine_status_tile_idle_fill` (#99000000).
final class _CompactStatusTile extends StatelessWidget {
  const _CompactStatusTile({required this.label, required this.on});

  static const height = 52.0;

  final String label;
  final bool? on;

  static const _idleFill = Color(0x99000000);
  static const _successFill = Color(0xFFF46E01);

  @override
  Widget build(BuildContext context) {
    final active = on == true;
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active ? _successFill : _idleFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x40FFFFFF)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
