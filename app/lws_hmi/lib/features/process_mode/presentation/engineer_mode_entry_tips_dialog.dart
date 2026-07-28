import 'dart:async';
import 'dart:ui' as ui;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// Process-lifetime suppress for the engineer entry tip (not persisted).
///
/// Checking “don’t remind me again” only hides the dialog until the next HMI
/// process start / reboot — never written to `misc-settings.json`.
abstract final class EngineerModeEntryTipGate {
  static bool _suppressedThisBoot = false;

  static bool get isSuppressedThisBoot => _suppressedThisBoot;

  static void suppressForThisBoot() {
    _suppressedThisBoot = true;
  }

  /// Test-only reset.
  @visibleForTesting
  static void resetForTest() {
    _suppressedThisBoot = false;
  }
}

/// lws-ui's first-entry notice shared by Home and Quick → Engineer handoff.
final class EngineerModeEntryTipsResult {
  const EngineerModeEntryTipsResult({required this.dontShowAgain});

  final bool dontShowAgain;
}

/// Cream frost prompt with captured Gaussian blur (same path as Laser Enable).
///
/// Overlay routes sit outside [CyberBlurBackdropScope], so [CyberOverlayHost]
/// firstFrame capture falls back to fake glass. Resolve the scope from the
/// *caller* and sample into the card instead.
Future<EngineerModeEntryTipsResult?> showEngineerModeEntryTipsDialog(
  BuildContext context,
) {
  final scope = context.findAncestorStateOfType<CyberBlurBackdropScopeState>();
  final panel = CyberPanelBorder(tone: CyberTone.light);

  return showGeneralDialog<EngineerModeEntryTipsResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Engineer mode entry tips',
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
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _EngineerEntryTipsFrostCard(
                    scope: scope,
                    panel: panel,
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

final class _EngineerEntryTipsFrostCard extends StatefulWidget {
  const _EngineerEntryTipsFrostCard({
    required this.scope,
    required this.panel,
  });

  final CyberBlurBackdropScopeState? scope;
  final CyberPanelBorder panel;

  @override
  State<_EngineerEntryTipsFrostCard> createState() =>
      _EngineerEntryTipsFrostCardState();
}

final class _EngineerEntryTipsFrostCardState
    extends State<_EngineerEntryTipsFrostCard> {
  ui.Image? _capture;
  final GlobalKey _cardKey = GlobalKey();

  /// Opaque cream only when capture is unavailable.
  static const _creamFallback = Color(0xFFFFFCFA);

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
            // Capture Gaussian (opacity 1.0), then cream frost wash. Full
            // `0xFF` cream would hide the blur; `0xD9` matches Laser Enable.
            Positioned.fill(
              child: _capture != null
                  ? ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: 25,
                        sigmaY: 25,
                        tileMode: TileMode.clamp,
                      ),
                      child: RawImage(
                        image: _capture,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    )
                  : const ColoredBox(color: _creamFallback),
            ),
            const Positioned.fill(
              child: ColoredBox(color: Color(0xD9FFFCFA)),
            ),
            const Padding(
              padding: EdgeInsets.all(CyberDimens.contentPadding),
              child: _EngineerModeEntryTipsBody(),
            ),
          ],
        ),
      ),
    );
  }
}

final class _EngineerModeEntryTipsBody extends StatefulWidget {
  const _EngineerModeEntryTipsBody();

  @override
  State<_EngineerModeEntryTipsBody> createState() =>
      _EngineerModeEntryTipsBodyState();
}

final class _EngineerModeEntryTipsBodyState
    extends State<_EngineerModeEntryTipsBody> {
  bool _dontShowAgain = true;

  /// Match [WarnDialogBody] metrics so entry tips share the alarm prompt size.
  static const _iconSize = 120.0;
  static const _titleSize = 32.0;
  static const _bodySize = 20.0;
  static const _bodyDark = Color(0xFF1A1A1A);
  static const _labelMuted = Color(0x80222222);
  static const _titleOrange = Color(0xFFF37535);
  static const _checkboxGreen = Color(0xFF34C759);

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('engineer-mode-entry-tips'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Image.asset(
            'assets/process/engineer_mode_entry_notice.webp',
            width: _iconSize,
            height: _iconSize,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Engineer Mode Notice',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _titleOrange,
            fontSize: _titleSize,
            fontWeight: FontWeight.w700,
            height: 1.15,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: const SingleChildScrollView(
            child: Text(
              'Engineer Mode unlocks advanced parameter customization '
              'for experienced users. We recommend learning how the '
              'machine works before making fine adjustments.',
              textAlign: TextAlign.start,
              style: TextStyle(
                color: _bodyDark,
                fontSize: _bodySize,
                fontWeight: FontWeight.w400,
                height: 1.35,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
            child: SizedBox(
              width: double.infinity,
              child: CyberButton(
                key: const ValueKey('engineer-mode-entry-confirm'),
                variant: CyberButtonVariant.primary,
                stretch: true,
                height: CyberDimens.actionButtonHeight,
                onPressed: () {
                  Navigator.of(context).pop(
                    EngineerModeEntryTipsResult(
                      dontShowAgain: _dontShowAgain,
                    ),
                  );
                },
                child: const Text('Confirm & Enter'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: InkWell(
            key: const ValueKey('engineer-mode-entry-dont-show-again'),
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
                    width: 28,
                    height: 28,
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
                const SizedBox(width: 6),
                const Text(
                  // lws-ui `don_t_show_again_this_session`
                  'Don’t show again this session',
                  style: TextStyle(
                    color: _labelMuted,
                    fontSize: 14,
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
