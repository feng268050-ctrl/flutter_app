import 'dart:math' as math;

import 'package:cyber_alarm_ui/src/widgets/warn_dialog_body.dart';
import 'package:flutter/material.dart';

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

  /// `frost_dialog_prompt_scroll_max_height` (tightened for hero confirm 68).
  static const double bodyScrollMaxHeight = 134;

  /// `frost_dialog_prompt_content_inset` / shell + body horizontal pad.
  static const double contentInset = 36;

  /// `frost_dialog_prompt_confirm_button_min_width`.
  static const double confirmMinWidth = 500;

  /// Confirm face — aligned with App `HmiButtonSize.hero` (68 / 24 / w700).
  static const double confirmHeight = 68;

  /// Confirm label — aligned with App `HmiButtonSize.hero` / `buttonHero`.
  static const double confirmLabelSize = 24.0;

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
