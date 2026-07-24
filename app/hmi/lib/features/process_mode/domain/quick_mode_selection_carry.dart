/// Session-scoped Quick Mode selection carry (lws-ui `QuickModeSelectionCarry`).
///
/// Cleared when entering Quick Mode; not persisted to disk. Thickness and swing
/// width stay independent across weld vs clean mode families.
final class QuickModeSelectionCarry {
  QuickModeSelectionCarry._();

  static int? materialType;
  static int? gear;
  static double? thickness;
  static double? swingWidth;

  static void clear() {
    materialType = null;
    gear = null;
    thickness = null;
    swingWidth = null;
  }

  /// Remembers non-null fields only.
  static void remember({
    int? material,
    int? gearValue,
    double? thicknessValue,
    double? swingWidthValue,
  }) {
    if (material != null) {
      materialType = material;
    }
    if (gearValue != null) {
      gear = gearValue;
    }
    if (thicknessValue != null) {
      thickness = thicknessValue;
    }
    if (swingWidthValue != null) {
      swingWidth = swingWidthValue;
    }
  }
}
