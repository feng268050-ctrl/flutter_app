/// FrostUI dimension tokens (lws-ui `frostui_dimens.xml` / `FrostDimens`).
///
/// Action-button size tiers ([actionButtonSmallHeight] /
/// [actionButtonMediumHeight] / [actionButtonLargeHeight]) lock **height**
/// only. Width is chosen by the caller (`SizedBox`, `stretch`, `expand`).
/// Capsule (`CyberButtonShape.rounded`) corner radius is always `height / 2`;
/// rounded-rectangle buttons use [rectangleButtonCornerRadius] (14).
abstract final class CyberDimens {
  /// Frost card corner (`frost_corner_radius` ≈ 28dp).
  static const cornerRadius = 28.0;
  static const contentPadding = 24.0;
  static const borderWidth = 1.0;
  static const buttonStrokeWidth = 1.0;

  /// Frost `RECTANGLE` button corner (14dp) — all size tiers.
  static const rectangleButtonCornerRadius = 14.0;

  // --- Action button tiers (small / medium / large) ---

  /// Small tier height (40).
  static const actionButtonSmallHeight = 40.0;
  static const actionButtonSmallPaddingHorizontal = 20.0;
  static const actionButtonSmallFontSize = 14.0;

  /// Medium tier height (58) — default dialog / settings CTA.
  static const actionButtonMediumHeight = 58.0;
  static const actionButtonMediumPaddingHorizontal = 24.0;
  static const actionButtonMediumFontSize = 18.0;

  /// Large tier height (72) — aligns with lws-ui engineer action buttons.
  static const actionButtonLargeHeight = 72.0;
  static const actionButtonLargePaddingHorizontal = 28.0;
  static const actionButtonLargeFontSize = 22.0;

  /// Alias for [actionButtonMediumHeight] (legacy Frost `actionButtonHeight`).
  static const actionButtonHeight = actionButtonMediumHeight;

  /// Alias for [actionButtonMediumPaddingHorizontal].
  static const actionButtonPaddingHorizontal =
      actionButtonMediumPaddingHorizontal;

  /// Alias for [actionButtonMediumFontSize].
  static const actionButtonFontSize = actionButtonMediumFontSize;

  // --- Checkbox face tiers (small / large) ---

  /// Small checkbox face edge length (20).
  static const checkboxSmallSize = 20.0;

  /// Large checkbox face edge length (28).
  static const checkboxLargeSize = 28.0;

  static const dialogFadeInMs = 220;
  static const dialogFadeOutMs = 160;
}
