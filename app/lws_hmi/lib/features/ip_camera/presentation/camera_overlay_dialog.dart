import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_show_overlay_applier.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';
import 'package:lws_hmi/ui/tip_dialog_host.dart';

/// Opens Change Overlay dialog. Returns applied params on success, else null.
Future<CameraShowOverlayParams?> showCameraOverlayDialog({
  required BuildContext context,
  required CameraShowOverlayApplier applier,
  required String cameraHost,
  required String machineModel,
  CameraShowOverlayParams? initial,
}) {
  return TipDialogHost.showDarkPrompt<CameraShowOverlayParams>(
    context: context,
    barrierDismissible: true,
    constraints: const BoxConstraints(
      minWidth: 560,
      maxWidth: 720,
      maxHeight: 720,
    ),
    builder: (ctx) => _CameraOverlayDialogBody(
      applier: applier,
      cameraHost: cameraHost,
      machineModel: machineModel,
      initial: initial ??
          const CameraShowOverlayParams(
            enable: 0,
            positionX: CameraShowOverlayParams.defaultPosition,
            positionY: CameraShowOverlayParams.defaultPosition,
          ),
    ),
  );
}

class _CameraOverlayDialogBody extends StatefulWidget {
  const _CameraOverlayDialogBody({
    required this.applier,
    required this.cameraHost,
    required this.machineModel,
    required this.initial,
  });

  final CameraShowOverlayApplier applier;
  final String cameraHost;
  final String machineModel;
  final CameraShowOverlayParams initial;

  @override
  State<_CameraOverlayDialogBody> createState() =>
      _CameraOverlayDialogBodyState();
}

class _CameraOverlayDialogBodyState extends State<_CameraOverlayDialogBody> {
  late bool _enable;
  late int _x;
  late int _y;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _enable = widget.initial.enable == 1;
    _x = widget.initial.positionX;
    _y = widget.initial.positionY;
  }

  int get _yMax => _enable
      ? CameraShowOverlayParams.maxYWhenEnabled
      : CameraShowOverlayParams.maxY;

  Future<void> _apply() async {
    if (_busy) {
      return;
    }
    final y = _y.clamp(CameraShowOverlayParams.minY, _yMax);
    final params = CameraShowOverlayParams.tryParse(
      enableRaw: _enable ? 1 : 0,
      positionXRaw: _x,
      positionYRaw: y,
    );
    if (params == null) {
      setState(() => _error = 'invalid');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _y = y;
    });
    final result = await widget.applier.apply(
      cameraHost: widget.cameraHost,
      machineModel: widget.machineModel,
      params: params,
    );
    if (!mounted) {
      return;
    }
    if (result.ok) {
      Navigator.pop(context, params);
      return;
    }
    setState(() {
      _busy = false;
      _error = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labelStyle = context.hmiTypography.sectionTitle;
    final errorStyle = context.hmiTypography.body.copyWith(
      color: const Color(0xFFFF6B6B),
    );
    return CyberPromptContent(
      title: l10n.cameraChangeOverlay,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.cameraOverlayEnable,
                  style: labelStyle,
                ),
              ),
              CyberSwitch(
                value: _enable,
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                          _enable = v;
                          if (_enable && _y > _yMax) {
                            _y = _yMax;
                          }
                        }),
              ),
            ],
          ),
          if (_enable) ...[
            const SizedBox(height: 12),
            Text(
              '${l10n.cameraOverlayPositionX}: $_x',
              style: labelStyle,
            ),
            CyberSlider(
              value: _x.toDouble().clamp(
                CameraShowOverlayParams.minX.toDouble(),
                CameraShowOverlayParams.maxX.toDouble(),
              ),
              min: CameraShowOverlayParams.minX.toDouble(),
              max: CameraShowOverlayParams.maxX.toDouble(),
              enabled: !_busy,
              showDragValueLabel: true,
              onChanged: (v) => setState(() => _x = v.round()),
            ),
            const SizedBox(height: 12),
            Text(
              '${l10n.cameraOverlayPositionY}: $_y',
              style: labelStyle,
            ),
            CyberSlider(
              value: _y.toDouble().clamp(
                CameraShowOverlayParams.minY.toDouble(),
                _yMax.toDouble(),
              ),
              min: CameraShowOverlayParams.minY.toDouble(),
              max: _yMax.toDouble(),
              enabled: !_busy,
              showDragValueLabel: true,
              onChanged: (v) => setState(() => _y = v.round()),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error == 'invalid'
                  ? l10n.cameraOverlayApplyFailed
                  : '${l10n.cameraOverlayApplyFailed}\n$_error',
              style: errorStyle,
            ),
          ],
        ],
      ),
      actions: [
        HmiButton(
          key: const Key('camera-overlay-cancel'),
          label: l10n.cancelText,
          size: HmiButtonSize.medium,
          widthPolicy: HmiButtonWidthPolicy.fixed,
          width: 168,
          variant: CyberButtonVariant.secondary,
          shape: CyberButtonShape.rounded,
          onPressed: _busy ? null : () => Navigator.pop(context),
        ),
        HmiButton(
          key: const Key('camera-overlay-apply'),
          label: l10n.wifiApply,
          size: HmiButtonSize.medium,
          widthPolicy: HmiButtonWidthPolicy.fixed,
          width: 168,
          variant: CyberButtonVariant.primary,
          shape: CyberButtonShape.rounded,
          onPressed: _busy ? null : () => unawaited(_apply()),
        ),
      ],
    );
  }
}
