/// Shared Home / Monitor Work Info formatting for cumulative stats metrics.
library;

/// Time metrics: under 1h → whole minutes + `min`; 1h and above → whole hours
/// + `h` (e.g. 75 min → `1` + `h`). Never keeps showing `min` once ≥ 1h.
({String number, String unit}) formatStatsDurationSeconds(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  if (safe >= 3600) {
    return (number: (safe ~/ 3600).toString(), unit: 'h');
  }
  return (number: (safe ~/ 60).toString(), unit: 'min');
}
