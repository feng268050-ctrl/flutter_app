/// One step in an ordered upgrade session.
class UpgradePhase {
  const UpgradePhase({
    required this.id,
    required this.label,
  });

  /// Stable id (e.g. `download`, `verify`, `transferring`).
  final String id;

  /// Operator-visible label (App supplies l10n).
  final String label;
}
