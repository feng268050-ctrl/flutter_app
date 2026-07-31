import 'dart:async';
import 'dart:math' as math;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// lws-ui warn prompt metrics (`FrostPromptDialog` + `dialog_frost_body_prompt`).
///
/// On short HMI viewports, [layoutScale] + [FittedBox] shrink content to fit
/// within [verticalEdgeMargin] while the shell keeps the card centered.
abstract final class WarnDialogMetrics {
  /// `engineer_mode_entry_dialog_width` / `FrostPromptDialog.standardWidthPx`.
  static const double minCardWidth = 700;

  /// `WarnDialogUtil.WARN_DIALOG_MAX_WIDTH_FRACTION`.
  static const double maxWidthFraction = 0.95;

  /// `frost_dialog_prompt_max_height` (`engineer_mode_entry_dialog_height`).
  static const double maxCardHeightDimen = 680;

  /// Breathing room above/below the card (logical px). Card stays centered;
  /// keep this tight so short HMI panels do not show large empty bands.
  static const double verticalEdgeMargin = 16;

  /// Unscaled content budget used to derive [layoutScale].
  static const double referenceContentHeight = 560;

  /// `frost_dialog_prompt_icon_size` → `engineer_mode_entry_icon_size`.
  static const double iconSize = 150;

  /// `frost_dialog_prompt_title_text_size`.
  static const double titleSize = 53;

  /// `prompt_content` textSize in `dialog_frost_body_prompt`.
  static const double bodySize = 37;

  /// `frost_dialog_prompt_scroll_max_height`.
  static const double bodyScrollMaxHeight = 148;

  /// `frost_dialog_content_padding` (card chrome).
  static const double cardPadding = 24;

  /// `frost_dialog_prompt_content_inset`.
  static const double contentInset = 36;

  /// `frost_dialog_prompt_confirm_button_min_width`.
  static const double confirmMinWidth = 500;

  /// `frost_action_button_text_size` / `text_size_12`.
  static const double confirmLabelSize = 29;

  /// Body `lineSpacingExtra` 6dp on 37sp ≈ height multiplier.
  static const double bodyHeight = (37 + 6) / 37;

  /// Max card height: dimen cap and screen margins.
  static double maxCardHeight(BuildContext context) {
    final fromScreen =
        MediaQuery.sizeOf(context).height - verticalEdgeMargin * 2;
    return math.min(maxCardHeightDimen, fromScreen);
  }

  /// Uniform shrink only when the viewport cannot fit the design height.
  /// No extra short-panel compact factor — that left large centered gaps.
  static double layoutScale(BuildContext context) {
    final budget = maxCardHeight(context);
    if (budget >= referenceContentHeight) {
      return 1.0;
    }
    return (budget / referenceContentHeight).clamp(0.72, 1.0);
  }

  static TextStyle titleStyle({
    required bool infoStyle,
    required double scale,
  }) =>
      TextStyle(
        // WARN → red; INFO (e.g. Allow Work After Camera Alarm) → black.
        color: infoStyle ? WarnDialogBody.titleBlack : WarnDialogBody.titleRed,
        fontSize: titleSize * scale,
        fontWeight: FontWeight.w700,
        height: 1.0,
        decoration: TextDecoration.none,
      );

  static TextStyle bodyStyle({required double scale}) => TextStyle(
        color: WarnDialogBody.bodyDark,
        fontSize: bodySize * scale,
        fontWeight: FontWeight.w400,
        height: bodyHeight,
        decoration: TextDecoration.none,
      );

  /// Mirrors `FrostPromptDialog.resolveTitleBasedWidthPx` via [TextPainter].
  static double resolveCardWidth(
    BuildContext context,
    String title, {
    required double scale,
  }) {
    final screenW = MediaQuery.sizeOf(context).width;
    final maxW = math.max(minCardWidth * scale, screenW * maxWidthFraction);
    final minW = minCardWidth * scale;
    final style = titleStyle(infoStyle: false, scale: scale);
    final painter = TextPainter(
      text: TextSpan(text: title, style: style),
      maxLines: 1,
      ellipsis: '…',
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final titleBased = painter.width + contentInset * 2 * scale;
    return titleBased.clamp(minW, maxW);
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
    final scale = WarnDialogMetrics.layoutScale(context);
    final maxH = WarnDialogMetrics.maxCardHeight(context);
    final cardW =
        WarnDialogMetrics.resolveCardWidth(context, title, scale: scale);
    final pad = WarnDialogMetrics.cardPadding * scale;
    final inset = WarnDialogMetrics.contentInset * scale;
    final icon = WarnDialogMetrics.iconSize * scale;
    final scrollMax = WarnDialogMetrics.bodyScrollMaxHeight * scale;
    final btnH = CyberDimens.actionButtonMediumHeight;
    final confirmW = (WarnDialogMetrics.confirmMinWidth * scale).clamp(
      200.0,
      cardW - pad * 2,
    );
    final iconAsset = infoStyle ? infoIconAsset : warnIconAsset;

    final content = SizedBox(
      width: cardW,
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: inset),
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
                  // Keep card size; shrink title type so long alarm names stay
                  // fully visible (no ellipsis) inside the existing width.
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        softWrap: false,
                        style: WarnDialogMetrics.titleStyle(
                          infoStyle: infoStyle,
                          scale: scale,
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
                        style: WarnDialogMetrics.bodyStyle(scale: scale),
                      ),
                    ),
                  ),
                  SizedBox(height: inset),
                ],
              ),
            ),
            Center(
              child: SizedBox(
                width: confirmW,
                height: btnH,
                child: CyberButton(
                  size: CyberButtonSize.medium,
                  variant: CyberButtonVariant.primary,
                  shape: CyberButtonShape.rounded,
                  stretch: true,
                  height: btnH,
                  // Stop warn SFX before the click sample (shared audio session).
                  clickSoundEnabled: false,
                  onPressed: () {
                    unawaited(() async {
                      await beforeConfirm?.call();
                      CyberClickSoundRegistry.playClick();
                      onConfirm();
                    }());
                  },
                  child: Text(
                    confirmLabel,
                    style: TextStyle(
                      fontSize: WarnDialogMetrics.confirmLabelSize * scale,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Cap height; FittedBox shrinks further if still too tall (Flutter-native).
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: cardW, maxHeight: maxH),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: content,
      ),
    );
  }
}
