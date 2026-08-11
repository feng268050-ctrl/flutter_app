/// Maps finger X (in key-local coords) to a popup option index.
/// Mirrors lws-ui `selectionIndexForX`.
int cyberImeSelectionIndexForX({
  required double x,
  required double keyWidth,
  required int optionCount,
}) {
  if (optionCount <= 1 || keyWidth <= 0) {
    return 0;
  }
  final slot = (x / keyWidth * optionCount).floor();
  if (slot < 0) return 0;
  if (slot >= optionCount) return optionCount - 1;
  return slot;
}

/// Default highlighted index when the popup first appears.
/// Mirrors lws-ui `defaultPopupIndex`: middle for 3+ options, else 0.
int cyberImeDefaultPopupIndex(int optionCount) =>
    optionCount >= 3 ? 1 : 0;

/// Horizontal drag distance (logical px) per soft-Space caret step.
const double cyberImeSpaceCursorStepPx = 14.0;

/// Accumulates horizontal [dx] into discrete caret steps (positive = right).
({int steps, double residual}) cyberImeCursorStepsForDx({
  required double dx,
  required double residual,
  double stepPx = cyberImeSpaceCursorStepPx,
}) {
  if (stepPx <= 0) {
    return (steps: 0, residual: residual + dx);
  }
  final next = residual + dx;
  final steps = next ~/ stepPx;
  return (steps: steps, residual: next - steps * stepPx);
}
