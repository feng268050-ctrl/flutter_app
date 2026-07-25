/// FrostUI dimension tokens (lws-ui `frostui_dimens.xml` / `FrostDimens`).
abstract final class CyberDimens {
  /// Frost card corner (`frost_corner_radius` ≈ 28dp).
  static const cornerRadius = 28.0;
  static const contentPadding = 24.0;
  static const borderWidth = 1.0;
  static const buttonStrokeWidth = 1.0;

  /// Frost `RECTANGLE` button corner (14dp).
  static const rectangleButtonCornerRadius = 14.0;

  static const actionButtonHeight = 58.0;
  static const actionButtonPaddingHorizontal = 24.0;
  static const actionButtonSmallHeight = 40.0;
  static const actionButtonSmallPaddingHorizontal = 20.0;

  /// Label size for regular 58dp buttons — matches HMI settings row text
  /// (18), not Android design-canvas `text_size_12` (29sp).
  static const actionButtonFontSize = 18.0;

  /// Label size for small / chip-height buttons (40dp / 36dp Auto).
  static const actionButtonSmallFontSize = 14.0;

  static const dialogFadeInMs = 220;
  static const dialogFadeOutMs = 160;
}
