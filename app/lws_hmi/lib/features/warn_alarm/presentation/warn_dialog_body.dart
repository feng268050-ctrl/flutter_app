import 'dart:async';
import 'dart:math' as math;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';
import 'package:lws_hmi/ui/hmi/word_boundary_label.dart';

/// lws-ui warn prompt metrics (`FrostPromptDialog` + `dialog_frost_body_prompt`).
///
/// Card size is **unified** for all warn alarms:
/// - width = [minCardWidth] (725) capped to 95% screen
/// - height ∈ [[minCardHeight], [maxCardHeightDimen]] with content centered
///
/// Fonts scale with card width; title is further fitted so one line shows the
/// full string (no ellipsis) inside the content band.
abstract final class WarnDialogMetrics {
  /// Warn alarm card width (design canvas).
  static const double minCardWidth = 725;

  /// `WarnDialogUtil.WARN_DIALOG_MAX_WIDTH_FRACTION`.
  static const double maxWidthFraction = 0.95;

  /// `frost_dialog_prompt_min_height`.
  static const double minCardHeight = 480;

  /// `frost_dialog_prompt_max_height` (`engineer_mode_entry_dialog_height`).
  static const double maxCardHeightDimen = 680;

  /// Breathing room above/below the card (logical px).
  static const double verticalEdgeMargin = 16;

  /// `frost_dialog_prompt_icon_size` → `engineer_mode_entry_icon_size`.
  static const double iconSize = 150;

  /// `frost_dialog_prompt_title_text_size` → criticalTitle (52).
  static const double titleSize = 52.0;

  /// Absolute floor only for pathological titles (prefer fit over this).
  static const double minTitleSize = 18.0; // body

  /// `prompt_content` → largeDialogTitle (36) special large body.
  static const double bodySize = 36.0;

  /// `frost_dialog_prompt_scroll_max_height` (tightened for hero confirm 72).
  static const double bodyScrollMaxHeight = 134;

  /// `frost_dialog_prompt_content_inset` / shell + body horizontal pad.
  static const double contentInset = 36;

  /// `frost_dialog_prompt_confirm_button_min_width`.
  static const double confirmMinWidth = 500;

  /// `frost_action_button_height`.
  static const double confirmHeight = 72; // HmiButton hero

  /// `frost_action_button_text_size` / `text_size_12`.
  static const double confirmLabelSize = 24.0; // navigation / hero

  /// Body `lineSpacingExtra` 6dp on 37sp ≈ height multiplier.
  static const double bodyHeight = (37 + 6) / 37;

  /// Max card height: dimen cap and screen margins.
  static double maxCardHeight(BuildContext context) {
    final fromScreen =
        MediaQuery.sizeOf(context).height - verticalEdgeMargin * 2;
    return math.min(maxCardHeightDimen, fromScreen);
  }

  /// Min card height, never above [maxCardHeight].
  static double minCardHeightFor(BuildContext context) {
    return math.min(minCardHeight, maxCardHeight(context));
  }

  /// Unified warn card width (725), capped to 95% of screen.
  static double resolveCardWidth(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    return math.min(minCardWidth, screenW * maxWidthFraction);
  }

  /// Scale all chrome when the card is narrower than the 725 design canvas.
  static double layoutScale(double cardWidth) {
    if (cardWidth >= minCardWidth) {
      return 1.0;
    }
    return (cardWidth / minCardWidth).clamp(0.72, 1.0);
  }

  static TextStyle titleStyle({
    required bool infoStyle,
    required double fontSize,
  }) =>
      TextStyle(
        // WARN → red; INFO (e.g. Allow Work After Camera Alarm) → black.
        color: infoStyle ? WarnDialogBody.titleBlack : WarnDialogBody.titleRed,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        height: 1.0,
        decoration: TextDecoration.none,
      );

  static TextStyle bodyStyle({required double fontSize}) => TextStyle(
        color: WarnDialogBody.bodyDark,
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        height: bodyHeight,
        decoration: TextDecoration.none,
      );

  /// Title band width inside the card (content inset on both sides).
  static double titleMaxWidth(double cardWidth, double scale) =>
      cardWidth - contentInset * 2 * scale;

  /// Font size so [title] fits on **one full line** inside [maxWidth].
  ///
  /// Starts from the design size ([titleSize] × layout scale) and shrinks from
  /// measured [TextPainter] width until it fits — no ellipsis. Prefer not to
  /// go below [minTitleSize], but will if that is the only way to keep one line.
  static double resolveTitleFontSize({
    required BuildContext context,
    required String title,
    required double maxWidth,
    required bool infoStyle,
    required double layoutScale,
  }) {
    final design = titleSize * layoutScale;
    if (title.isEmpty || maxWidth <= 0) {
      return design;
    }

    var size = design;
    for (var i = 0; i < 12; i++) {
      final painter = TextPainter(
        text: TextSpan(
          text: title,
          style: titleStyle(infoStyle: infoStyle, fontSize: size),
        ),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: TextScaler.noScaling,
      )..layout();
      if (painter.width <= maxWidth) {
        return size;
      }
      // Shrink past [minTitleSize] when needed so the full title stays on one line.
      final next = size * maxWidth / painter.width;
      if ((size - next).abs() < 0.05) {
        return next;
      }
      size = next;
    }
    return size;
  }
}

/// Warn dialog body matching lws-ui `dialog_frost_body_prompt` + confirm action.
///
/// Layout: centered alarm icon → title → body → orange Confirm.
/// [infoStyle] (lws-ui INFO_TYPE): orange info icon + black title — used when a
/// bypassable alarm is allowed (e.g. Allow Work After Camera Alarm → C002).
/// Otherwise WARN: red siren + red title.
class WarnDialogBody extends StatelessWidget {
  const WarnDialogBody({
    super.key,
    required this.title,
    required this.body,
    required this.onConfirm,
    this.beforeConfirm,
    this.confirmLabel = 'Confirm',
    this.infoStyle = false,
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
  final bool infoStyle;

  /// lws-ui `alarm_warn_icon` (WARN_TYPE).
  static const warnIconAsset = 'assets/warn/alarm_warn_icon.webp';

  /// lws-ui `alarm_info_icon` (INFO_TYPE / yellow-orange warning).
  static const infoIconAsset = 'assets/warn/alarm_info_icon.webp';

  /// Bright warn red (lws-ui WARN_TYPE title).
  static const titleRed = Color(0xFFFF0000);

  /// INFO title (lws-ui INFO_TYPE).
  static const titleBlack = Color(0xFF000000);

  /// Body on light frost (lws-ui `text_black`).
  static const bodyDark = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    final cardW = WarnDialogMetrics.resolveCardWidth(context);
    final scale = WarnDialogMetrics.layoutScale(cardW);
    final minH = WarnDialogMetrics.minCardHeightFor(context);
    final maxH = WarnDialogMetrics.maxCardHeight(context);
    final inset = WarnDialogMetrics.contentInset * scale;
    final icon = WarnDialogMetrics.iconSize * scale;
    final scrollMax = WarnDialogMetrics.bodyScrollMaxHeight * scale;
    final titleMax = WarnDialogMetrics.titleMaxWidth(cardW, scale);
    final titleFont = WarnDialogMetrics.resolveTitleFontSize(
      context: context,
      title: title,
      maxWidth: titleMax,
      infoStyle: infoStyle,
      layoutScale: scale,
    );
    // Body must never read larger than the (possibly fitted) title.
    final bodyFont = math.min(WarnDialogMetrics.bodySize * scale, titleFont);
    final confirmW = (WarnDialogMetrics.confirmMinWidth * scale).clamp(
      200.0,
      cardW - inset * 2,
    );
    final iconAsset = infoStyle ? infoIconAsset : warnIconAsset;

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
                  infoStyle: infoStyle,
                  fontSize: titleFont,
                ),
              ),
            ),
          ),
          SizedBox(height: inset),
          // Reserve the design body scroll band so fitted (smaller) body fonts
          // do not shrink the card — keeps warn dialogs height-unified.
          SizedBox(
            height: scrollMax,
            width: double.infinity,
            child: SingleChildScrollView(
              child: WordBoundaryBody(
                text: body,
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
              child: HmiButton(
                label: confirmLabel,
                size: HmiButtonSize.hero,
                widthPolicy: HmiButtonWidthPolicy.fill,
                variant: CyberButtonVariant.primary,
                shape: CyberButtonShape.rounded,
                // Stop warn SFX before the click sample (shared audio session).
                clickSoundEnabled: false,
                onPressed: () {
                  unawaited(() async {
                    await beforeConfirm?.call();
                    CyberClickSoundRegistry.playClick();
                    onConfirm();
                  }());
                },
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
