import 'dart:async';
import 'dart:ui' as ui;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_feedback_copy.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';

/// lws-ui [FrostStatusDialog] failure / tip mode (`OperationDialogBuilder.openErrorDialog`).
///
/// Singleton-guarded so key-switch + e-stop paths cannot stack dialogs.
/// Chrome: **dark** frost with card-local Gaussian blur + light tint so the
/// page shows through (背景透视). Outside the panel stays sharp (scrim only).
/// Metrics match `dialog_frost_prompt` + `dialog_frost_body_status`.
abstract final class OperationFailedDialogHost {
  static bool _showing = false;

  @visibleForTesting
  static bool get isShowing => _showing;

  @visibleForTesting
  static void debugReset() {
    _showing = false;
  }

  /// Shows once; no-ops while another Operation-failed tip is open.
  static Future<void> show(
    BuildContext context, {
    required String message,
    String title = DeviceControlFeedbackCopy.operationFailedTitle,
  }) async {
    if (_showing || !context.mounted) {
      return;
    }
    _showing = true;
    try {
      await showOperationFailedDialog(
        context,
        title: title,
        message: message,
      );
    } finally {
      _showing = false;
    }
  }
}

Future<void> showOperationFailedDialog(
  BuildContext context, {
  required String message,
  String title = DeviceControlFeedbackCopy.operationFailedTitle,
}) {
  // Overlay routes sit outside [CyberBlurBackdropScope], so resolve the
  // capture root from the *caller* and sample into the tip card.
  final scope = context.findAncestorStateOfType<CyberBlurBackdropScopeState>();
  final panel = CyberPanelBorder(tone: CyberTone.dark);

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Operation failed tip',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(dialogContext).maybePop(),
              child: const ColoredBox(color: CyberColors.scrim),
            ),
            FadeTransition(
              opacity: animation,
              child: Center(
                child: _OperationFailedFrostCard(
                  scope: scope,
                  panel: panel,
                  title: title,
                  message: message,
                  onConfirm: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Dark tip card with captured Gaussian frost (panel only).
final class _OperationFailedFrostCard extends StatefulWidget {
  const _OperationFailedFrostCard({
    required this.scope,
    required this.panel,
    required this.title,
    required this.message,
    required this.onConfirm,
  });

  final CyberBlurBackdropScopeState? scope;
  final CyberPanelBorder panel;
  final String title;
  final String message;
  final VoidCallback onConfirm;

  /// Charcoal fallback when capture is unavailable.
  static const charcoalFallback = Color(0xFF1A1A1E);

  /// Gaussian sigma (~lws-ui HIGH dialog frost).
  static const blurSigma = 23.0;

  /// Frost wash over the blurred capture — high intensity tint only
  /// (`0x40` alpha), not opaque fake-glass `0xCC`, so page透视 stays visible.
  static Color get charcoalWash => cyberBlurOverlayColor(
        intensity: CyberBlurIntensity.high,
        tint: CyberBlurTint.dark,
      );

  @override
  State<_OperationFailedFrostCard> createState() =>
      _OperationFailedFrostCardState();
}

final class _OperationFailedFrostCardState
    extends State<_OperationFailedFrostCard> {
  ui.Image? _capture;
  final GlobalKey _cardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_sample());
    });
  }

  @override
  void dispose() {
    _capture?.dispose();
    super.dispose();
  }

  Future<void> _sample() async {
    final boundary = widget.scope?.renderBoundary;
    final self = _cardKey.currentContext?.findRenderObject();
    if (boundary == null ||
        !boundary.hasSize ||
        self is! RenderBox ||
        !self.hasSize) {
      return;
    }
    try {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final scale = (dpr / 3).clamp(0.25, dpr);
      final full = await boundary.toImage(pixelRatio: scale);
      if (!mounted) {
        full.dispose();
        return;
      }
      final origin =
          self.localToGlobal(Offset.zero) - boundary.localToGlobal(Offset.zero);
      final src = Rect.fromLTWH(
        origin.dx * scale,
        origin.dy * scale,
        self.size.width * scale,
        self.size.height * scale,
      ).intersect(
        Rect.fromLTWH(0, 0, full.width.toDouble(), full.height.toDouble()),
      );
      if (src.width < 1 || src.height < 1) {
        full.dispose();
        return;
      }
      final cropped = await _crop(full, src);
      full.dispose();
      if (!mounted) {
        cropped.dispose();
        return;
      }
      setState(() {
        _capture?.dispose();
        _capture = cropped;
      });
    } catch (_) {
      // Keep charcoal fallback.
    }
  }

  static Future<ui.Image> _crop(ui.Image src, Rect srcRect) async {
    final w = srcRect.width.round().clamp(1, src.width);
    final h = srcRect.height.round().clamp(1, src.height);
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      src,
      srcRect,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint(),
    );
    final picture = recorder.endRecording();
    try {
      return picture.toImage(w, h);
    } finally {
      picture.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.panel.borderRadius;
    return ClipRRect(
      key: _cardKey,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: widget.panel.flatBorderColor,
            width: widget.panel.width,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: _capture != null
                  ? ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: _OperationFailedFrostCard.blurSigma,
                        sigmaY: _OperationFailedFrostCard.blurSigma,
                        tileMode: TileMode.clamp,
                      ),
                      child: RawImage(
                        image: _capture,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    )
                  : const ColoredBox(
                      color: _OperationFailedFrostCard.charcoalFallback,
                    ),
            ),
            Positioned.fill(
              child: ColoredBox(
                color: _OperationFailedFrostCard.charcoalWash,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(CyberDimens.contentPadding),
              child: _OperationFailedBody(
                title: widget.title,
                message: widget.message,
                onConfirm: widget.onConfirm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _OperationFailedBody extends StatelessWidget {
  const _OperationFailedBody({
    required this.title,
    required this.message,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final VoidCallback onConfirm;

  /// lws-ui default prompt width ≈ screen × 0.62; host caps at 720.
  static const _maxWidth = 720.0;

  /// `dialog_frost_body_status` icon 80dp.
  static const _iconSize = 80.0;

  /// `dialog_frost_prompt` `tv_title` 37sp.
  static const _titleSize = 37.0;

  /// `frost_dialog_status_content` 33sp.
  static const _bodySize = 33.0;

  /// `frost_dialog_prompt_confirm_button_min_width` / entry confirm 500dp.
  static const _confirmMinWidth = 500.0;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final cardW = (screenW * 0.62).clamp(320.0, _maxWidth);

    return ConstrainedBox(
      key: const ValueKey('operation-failed-dialog'),
      constraints: BoxConstraints(maxWidth: cardW),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CyberColors.textPrimary,
              fontSize: _titleSize,
              fontWeight: FontWeight.w700,
              height: 1.15,
              letterSpacing: 0.02 * _titleSize,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: CyberDimens.contentPadding),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x0068686C),
                  CyberColors.dividerCenter,
                  Color(0x0068686C),
                ],
              ),
            ),
            child: SizedBox(height: 1, width: double.infinity),
          ),
          const SizedBox(height: CyberDimens.contentPadding),
          const Center(
            child: Image(
              image: AssetImage(ProcessModeAssets.dialogError),
              width: _iconSize,
              height: _iconSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CyberColors.textSecondary,
                fontSize: _bodySize,
                fontWeight: FontWeight.w400,
                height: 1.2,
                // lineSpacingExtra 6dp ≈ +6 on 33sp body.
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(height: CyberDimens.contentPadding),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x0068686C),
                  CyberColors.dividerCenter,
                  Color(0x0068686C),
                ],
              ),
            ),
            child: SizedBox(height: 1, width: double.infinity),
          ),
          const SizedBox(height: CyberDimens.contentPadding),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: (_confirmMinWidth).clamp(200.0, cardW),
                maxWidth: (_confirmMinWidth).clamp(200.0, cardW),
              ),
              child: SizedBox(
                width: double.infinity,
                child: CyberButton(
                  key: const ValueKey('operation-failed-ok'),
                  variant: CyberButtonVariant.primary,
                  shape: CyberButtonShape.rounded,
                  stretch: true,
                  height: CyberDimens.actionButtonHeight,
                  onPressed: () {
                    CyberClickSoundRegistry.playClick();
                    onConfirm();
                  },
                  child: const Text('OK'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
