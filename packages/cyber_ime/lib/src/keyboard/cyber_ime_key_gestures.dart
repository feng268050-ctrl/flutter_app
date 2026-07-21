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
