/// Joins brand and model for About / Device Model display.
const String kUnavailableDisplay = '-';

String productDeviceModelDisplay(String? brand, String? model) {
  final b = (brand == null || brand.trim().isEmpty)
      ? kUnavailableDisplay
      : brand.trim();
  final m = (model == null || model.trim().isEmpty)
      ? kUnavailableDisplay
      : model.trim();
  final joined = '$b $m';
  if (joined == '$kUnavailableDisplay $kUnavailableDisplay') {
    return kUnavailableDisplay;
  }
  return joined;
}
