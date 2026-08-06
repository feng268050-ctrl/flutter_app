import 'dart:async';

import 'package:cyber_alarm_ui/src/domain/warn_chrome_style.dart';
import 'package:cyber_alarm_ui/src/widgets/warn_dialog_metrics.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// Warn dialog body matching lws-ui `dialog_frost_body_prompt` + confirm action.
///
/// Layout: centered alarm icon → title → body → primary Confirm.
/// [infoStyle] / [chromeStyle] INFO: orange info icon + black title — used when
/// a bypassable alarm is allowed. Otherwise WARN: red siren + red title.
class WarnDialogBody extends StatelessWidget {
  const WarnDialogBody({
    super.key,
    required this.title,
    required this.body,
    required this.onConfirm,
    this.beforeConfirm,
    this.confirmLabel = 'Confirm',
    this.infoStyle = false,
    this.chromeStyle,
  });

  /// Product alarm title (e.g. "Camera Communication Alarm").
  final String title;

  /// Instruction / detail copy.
  final String body;

  final String confirmLabel;
  final VoidCallback onConfirm;

  /// Stop warn loop before click (single mpg123 session — mutual exclusion).
  final Future<void> Function()? beforeConfirm;

  /// When true, INFO chrome (bypassable alarm allowed to continue work).
  /// Ignored when [chromeStyle] is set.
  final bool infoStyle;

  /// Preferred chrome selector; when null, falls back to [infoStyle].
  final WarnChromeStyle? chromeStyle;

  /// Package asset path for WARN icon (use with [packageName]).
  static const warnIconAsset = 'assets/warn/alarm_warn_icon.webp';

  /// Package asset path for INFO icon (use with [packageName]).
  static const infoIconAsset = 'assets/warn/alarm_info_icon.webp';

  /// Asset package name for [Image.asset].
  static const packageName = 'cyber_alarm_ui';

  /// Bright warn red (lws-ui WARN_TYPE title).
  static const titleRed = Color(0xFFFF0000);

  /// INFO title (lws-ui INFO_TYPE).
  static const titleBlack = Color(0xFF000000);

  /// Body on light frost (lws-ui `text_black`).
  static const bodyDark = Color(0xFF1A1A1A);

  bool get _useInfoStyle =>
      chromeStyle?.isInfo ?? infoStyle;

  @override
  Widget build(BuildContext context) {
    final useInfo = _useInfoStyle;
    final cardW = WarnDialogMetrics.resolveCardWidth(context);
    final scale = WarnDialogMetrics.layoutScale(cardW);
    final minH = WarnDialogMetrics.minCardHeightFor(context);
    final maxH = WarnDialogMetrics.maxCardHeight(context);
    final inset = WarnDialogMetrics.contentInset * scale;
    final icon = WarnDialogMetrics.iconSize * scale;
    final scrollMax = WarnDialogMetrics.bodyScrollMaxHeight * scale;
    final bodyFont = WarnDialogMetrics.bodySize * scale;
    final titleMax = WarnDialogMetrics.titleMaxWidth(cardW, scale);
    final titleFont = WarnDialogMetrics.resolveTitleFontSize(
      context: context,
      title: title,
      maxWidth: titleMax,
      infoStyle: useInfo,
      layoutScale: scale,
    );
    final confirmH = WarnDialogMetrics.confirmHeight * scale;
    final confirmFont = WarnDialogMetrics.confirmLabelSize * scale;
    final confirmW = (WarnDialogMetrics.confirmMinWidth * scale).clamp(
      200.0,
      cardW - inset * 2,
    );
    final iconAsset = useInfo ? infoIconAsset : warnIconAsset;

    // lws-ui: content inset on shell (top/bottom) + body/action (start/end).
    // Top-aligned (not vertically centered) so minHeight slack stays at the
    // bottom — avoids a large empty band above the alarm icon.
    final content = Padding(
      padding: EdgeInsets.fromLTRB(inset, inset, inset, inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Image.asset(
              iconAsset,
              package: packageName,
              width: icon,
              height: icon,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          SizedBox(height: inset),
          // Reserve the design title band height so fitted (smaller) fonts
          // do not shrink the card — keeps warn dialogs height-unified.
          SizedBox(
            height: WarnDialogMetrics.titleSize * scale,
            width: double.infinity,
            child: Center(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                textScaler: TextScaler.noScaling,
                style: WarnDialogMetrics.titleStyle(
                  infoStyle: useInfo,
                  fontSize: titleFont,
                ),
              ),
            ),
          ),
          SizedBox(height: inset),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: scrollMax),
            child: SingleChildScrollView(
              child: Text(
                body,
                textAlign: TextAlign.start,
                style: WarnDialogMetrics.bodyStyle(fontSize: bodyFont),
              ),
            ),
          ),
          // Explicit gap before Confirm (lws-ui body marginBottom = content inset).
          // Keeps the button from painting over the last body line.
          SizedBox(height: inset),
          Center(
            child: SizedBox(
              width: confirmW,
              height: confirmH,
              child: CyberButton(
                onPressed: () {
                  unawaited(() async {
                    await beforeConfirm?.call();
                    CyberClickSoundRegistry.playClick();
                    onConfirm();
                  }());
                },
                variant: CyberButtonVariant.primary,
                shape: CyberButtonShape.rounded,
                size: CyberButtonSize.large,
                // Stop warn SFX before the click sample (shared audio session).
                clickSoundEnabled: false,
                height: confirmH,
                stretch: true,
                child: Text(
                  confirmLabel,
                  textAlign: TextAlign.center,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: confirmFont,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // minHeight 480 like lws-ui. Column packs from the top under the min
    // constraint so slack stays below Confirm (never a void above the icon).
    return SizedBox(
      width: cardW,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: cardW,
          maxWidth: cardW,
          minHeight: minH,
          maxHeight: maxH,
        ),
        child: content,
      ),
    );
  }
}
