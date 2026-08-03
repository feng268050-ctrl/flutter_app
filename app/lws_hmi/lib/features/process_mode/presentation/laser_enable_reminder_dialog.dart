import 'dart:async';
import 'dart:ui' as ui;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart'
    hide MaterialType;
import 'package:lws_hmi/features/process_mode/domain/laser_enable_reminder_copy.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';

/// Result of the laser-enable Important Reminder dialog.
final class LaserEnableReminderResult {
  const LaserEnableReminderResult({required this.dontShowAgain});

  final bool dontShowAgain;
}

/// Shows lws-ui `ReminderExactBuilder` Important Reminder, or returns
/// immediately when [LaserEnableReminderGate] is suppressed for [session].
Future<LaserEnableReminderResult?> showLaserEnableReminderDialog({
  required BuildContext context,
  required ProcessType processType,
  required LaserEnableReminderSession session,
  int focusScaleRef = 0,
}) async {
  if (LaserEnableReminderGate.isSuppressed(session)) {
    return const LaserEnableReminderResult(dontShowAgain: false);
  }
  return _showLaserEnableReminderOverlay(
    context: context,
    processType: processType,
    focusScaleRef: focusScaleRef,
  );
}

Future<LaserEnableReminderResult?> _showLaserEnableReminderOverlay({
  required BuildContext context,
  required ProcessType processType,
  required int focusScaleRef,
}) {
  // Resolve capture root from the *caller* (dialog route has no scope).
  final scope = context.findAncestorStateOfType<CyberBlurBackdropScopeState>();
  final panel = CyberPanelBorder(tone: CyberTone.light);

  // Transparent barrier so we can dim outside without feeding the panel blur
  // a full-screen scrim sample. Outside stays sharp; only the card is frosted.
  // Inset 12 from screen edges (not inner content padding).
  return showGeneralDialog<LaserEnableReminderResult>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Laser enable reminder',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: CyberColors.scrim),
            FadeTransition(
              opacity: animation,
              child: Padding(
                // Exact 12px to screen edges (not SafeArea — HMI is full-bleed).
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: _LaserEnableFrostCard(
                      scope: scope,
                      panel: panel,
                      processType: processType,
                      focusScaleRef: focusScaleRef,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Cream Important Reminder card with captured Gaussian frost (panel only).
final class _LaserEnableFrostCard extends StatefulWidget {
  const _LaserEnableFrostCard({
    required this.scope,
    required this.panel,
    required this.processType,
    required this.focusScaleRef,
  });

  final CyberBlurBackdropScopeState? scope;
  final CyberPanelBorder panel;
  final ProcessType processType;
  final int focusScaleRef;

  @override
  State<_LaserEnableFrostCard> createState() => _LaserEnableFrostCardState();
}

final class _LaserEnableFrostCardState extends State<_LaserEnableFrostCard> {
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
      // Keep cream fallback.
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
                        sigmaX: 22,
                        sigmaY: 22,
                        tileMode: TileMode.clamp,
                      ),
                      child: RawImage(
                        image: _capture,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    )
                  : const ColoredBox(color: Color(0xE8FFFCFA)),
            ),
            const Positioned.fill(
              child: ColoredBox(color: Color(0xD9FFFCFA)),
            ),
            Padding(
              // Inner chrome padding (frost_dialog_content_padding = 24).
              // Screen-edge inset is 12 on the dialog host, not here.
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: _LaserEnableReminderBody(
                processType: widget.processType,
                focusScaleRef: widget.focusScaleRef,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _LaserEnableReminderBody extends StatefulWidget {
  const _LaserEnableReminderBody({
    required this.processType,
    required this.focusScaleRef,
  });

  final ProcessType processType;
  final int focusScaleRef;

  @override
  State<_LaserEnableReminderBody> createState() =>
      _LaserEnableReminderBodyState();
}

final class _LaserEnableReminderBodyState
    extends State<_LaserEnableReminderBody> {
  bool _dontShowAgain = true;

  static const _titleDark = Color(0xFF1A1A1A);
  static const _labelMuted = Color(0x80222222);
  static const _checkboxGreen = Color(0xFF34C759);

  @override
  Widget build(BuildContext context) {
    final showFocus =
        LaserEnableReminderCopy.showsFocusScale(widget.processType);
    final focusAsset =
        ProcessModeAssets.laserReminderFocusScale(widget.focusScaleRef);

    return Column(
      key: const ValueKey('laser-enable-reminder'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Important',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _titleDark,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.1,
            decoration: TextDecoration.none,
          ),
        ),
        // lws-ui `frost_dialog_title_divider` (edge → center → edge).
        const SizedBox(height: 24),
        const SizedBox(
          height: 1,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x00000000),
                  CyberColors.dividerCenter,
                  Color(0x00000000),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ReminderCard(
                asset: ProcessModeAssets.laserReminderProtection,
                tip: 'Confirm you’re wearing laser protective equipment.',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ReminderCard(
                asset: LaserEnableReminderCopy.nozzleAsset(widget.processType),
                tip: LaserEnableReminderCopy.nozzleTip(widget.processType),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ReminderCard(
                asset: showFocus && focusAsset.isNotEmpty ? focusAsset : null,
                tip: showFocus
                    ? 'Set the welding gun focus scale to the indicated value.'
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 360, maxWidth: 560),
            child: SizedBox(
              width: double.infinity,
              child: CyberButton(
                key: const ValueKey('laser-enable-reminder-confirm'),
                size: CyberButtonSize.medium,
                variant: CyberButtonVariant.primary,
                shape: CyberButtonShape.rounded,
                stretch: true,
                onPressed: () {
                  CyberClickSoundRegistry.playClick();
                  Navigator.of(context).pop(
                    LaserEnableReminderResult(dontShowAgain: _dontShowAgain),
                  );
                },
                child: const Text(
                  'Yes — I’ve completed the safety checks above',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: InkWell(
            key: const ValueKey('laser-enable-reminder-dont-show-again'),
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              CyberClickSoundRegistry.playClick();
              setState(() => _dontShowAgain = !_dontShowAgain);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IgnorePointer(
                  child: SizedBox(
                    width: CyberDimens.checkboxLargeSize,
                    height: CyberDimens.checkboxLargeSize,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Checkbox(
                        value: _dontShowAgain,
                        activeColor: _checkboxGreen,
                        checkColor: Colors.white,
                        side: const BorderSide(color: _labelMuted, width: 1.5),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        onChanged: (_) {},
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Don’t show again this session',
                  style: TextStyle(
                    color: _labelMuted,
                    fontSize: 13,
                    height: 1.2,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

final class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.asset,
    required this.tip,
  });

  final String? asset;
  final String? tip;

  static const _cardFill = Color(0xFFF8F0E8);
  static const _tipDark = Color(0xFF1A1A1A);
  static const _illustrationSize = 200.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: _illustrationSize,
          height: _illustrationSize,
          child: DecoratedBox(
            decoration: const BoxDecoration(color: _cardFill),
            child: Center(
              child: asset == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        asset!,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 60,
          child: tip == null
              ? const SizedBox.shrink()
              : Text(
                  tip!,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _tipDark,
                    fontSize: 14,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
        ),
      ],
    );
  }
}
