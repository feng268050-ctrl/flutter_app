import 'package:lws_hmi/platform/percent.dart';

/// Which physical button acts as Flutter primary (left-click).
enum MousePrimaryButton {
  left,
  right,
}

/// Relative pointer X/Y handling (Linux flutter-pi).
///
/// [auto] swaps axes for Bluetooth keyboard+pointer combo devices (common
/// HOGP trackpad clones). [normal] never swaps; [swap] always swaps.
enum MousePointerAxes {
  auto,
  normal,
  swap,
}

/// OS-common mouse preferences (Linux: `/var/lib/lws-hmi/mouse.conf`).
class MouseSettings {
  const MouseSettings({
    this.naturalScroll = false,
    this.scrollSpeedPercent = 50,
    this.pointerSpeedPercent = 50,
    this.pointerSizePercent = 20,
    this.primaryButton = MousePrimaryButton.left,
    this.pointerAxes = MousePointerAxes.auto,
  });

  final bool naturalScroll;
  final int scrollSpeedPercent;
  final int pointerSpeedPercent;

  /// Visual cursor size (0–100). Default 20 — flutter-pi maps this to icon
  /// density (ceil + upscale for sparse hand/text assets).
  final int pointerSizePercent;
  final MousePrimaryButton primaryButton;
  final MousePointerAxes pointerAxes;

  MouseSettings copyWith({
    bool? naturalScroll,
    int? scrollSpeedPercent,
    int? pointerSpeedPercent,
    int? pointerSizePercent,
    MousePrimaryButton? primaryButton,
    MousePointerAxes? pointerAxes,
  }) {
    return MouseSettings(
      naturalScroll: naturalScroll ?? this.naturalScroll,
      scrollSpeedPercent: scrollSpeedPercent ?? this.scrollSpeedPercent,
      pointerSpeedPercent: pointerSpeedPercent ?? this.pointerSpeedPercent,
      pointerSizePercent: pointerSizePercent ?? this.pointerSizePercent,
      primaryButton: primaryButton ?? this.primaryButton,
      pointerAxes: pointerAxes ?? this.pointerAxes,
    );
  }

  static MouseSettings defaults() => const MouseSettings();
}

/// Map 0–100 UI percent ↔ libinput accel speed ∈ [-1, 1].
double pointerPercentToAccel(int percent) =>
    (clampPercent(percent) / 100.0) * 2.0 - 1.0;

int pointerAccelToPercent(double accel) {
  final clamped = accel.clamp(-1.0, 1.0);
  return (((clamped + 1.0) / 2.0) * 100.0).round().clamp(0, 100);
}

/// Reusable mouse settings API (Linux now; Android later).
abstract class MouseSettingsController {
  Future<MouseSettings> getSettings();

  /// Persist [settings] (Linux: write prefs; flutter-pi picks up via mtime poll).
  Future<void> setSettings(MouseSettings settings);

  Future<void> dispose();
}
