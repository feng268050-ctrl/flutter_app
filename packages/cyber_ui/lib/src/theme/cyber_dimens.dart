/// FrostUI dimension tokens (lws-ui `frostui_dimens.xml` / `FrostDimens`).
///
/// Action-button size tiers ([actionButtonMiniHeight] /
/// [actionButtonSmallHeight] / [actionButtonMediumHeight] /
/// [actionButtonLargeHeight]) lock **height** only. Width is chosen by the
/// caller (`SizedBox`, `stretch`, `expand`). Capsule (`CyberButtonShape.rounded`)
/// corner radius is always `height / 2`; rounded-rectangle buttons use
/// [rectangleButtonCornerRadius] (14).
abstract final class CyberDimens {
  /// Frost card corner (`frost_corner_radius` ≈ 28dp).
  static const cornerRadius = 28.0;
  static const contentPadding = 24.0;
  static const borderWidth = 1.0;
  static const buttonStrokeWidth = 1.0;

  /// Frost `RECTANGLE` button corner (14dp) — all size tiers.
  static const rectangleButtonCornerRadius = 14.0;

  // --- Action button tiers (mini / small / medium / large) ---
  // Heights only; horizontal padding + label size are stable per tier.

  /// Mini tier height (38) — compact trailing actions (e.g. Auto zero).
  static const actionButtonMiniHeight = 38.0;
  static const actionButtonMiniPaddingHorizontal = 20.0;
  static const actionButtonMiniFontSize = 14.0;

  /// Small tier height (56) — default dialog / settings / monitor CTA.
  static const actionButtonSmallHeight = 56.0;
  static const actionButtonSmallPaddingHorizontal = 20.0;
  static const actionButtonSmallFontSize = 14.0;

  /// Medium tier height (66) — process-mode outline / wire actions.
  static const actionButtonMediumHeight = 66.0;
  static const actionButtonMediumPaddingHorizontal = 24.0;
  static const actionButtonMediumFontSize = 18.0;

  /// Large tier height (86) — primary hold / enable actions.
  static const actionButtonLargeHeight = 86.0;
  static const actionButtonLargePaddingHorizontal = 28.0;
  static const actionButtonLargeFontSize = 22.0;

  /// Alias for [actionButtonSmallHeight] (default CTA height).
  static const actionButtonHeight = actionButtonSmallHeight;

  /// Alias for [actionButtonSmallPaddingHorizontal].
  static const actionButtonPaddingHorizontal =
      actionButtonSmallPaddingHorizontal;

  /// Alias for [actionButtonSmallFontSize].
  static const actionButtonFontSize = actionButtonSmallFontSize;

  // --- Checkbox face tiers (small / large) ---

  /// Small checkbox face edge length (24).
  static const checkboxSmallSize = 24.0;

  /// Large checkbox face edge length (26).
  static const checkboxLargeSize = 26.0;

  static const dialogFadeInMs = 220;
  static const dialogFadeOutMs = 160;
}
