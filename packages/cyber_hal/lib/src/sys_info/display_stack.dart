import 'dart:io';

/// Active HMI display / embedder stack on the appliance.
///
/// Image stamp: `/etc/display-stack` (post-build; flutter-pi XOR weston).
/// Runtime stamp: `/run/display-stack` (`hmi-launch.sh`).
/// Legacy fallbacks: `/etc/hmi/display-stack`, `/run/hmi/display-stack`.
enum DisplayStack {
  /// Sony/Rockchip flutter-pi DRM path (alternate rootfs).
  flutterPi,

  /// Weston + flutter-wayland-client (default production image).
  weston,

  /// Host / sim / undecided — treat feature gates like [flutterPi].
  unknown;

  /// Settings / Device Information label.
  String get displayLabel => switch (this) {
        DisplayStack.flutterPi => 'Flutter-pi',
        DisplayStack.weston => 'Weston',
        DisplayStack.unknown => 'Unknown',
      };
}

/// Which mouse preference knobs the active stack actually applies.
///
/// Pref file (`mouse.conf`) always stores the full set; unavailable knobs are
/// hidden in Settings and ignored by the compositor.
final class MouseSettingAvailability {
  const MouseSettingAvailability({
    required this.naturalScroll,
    required this.scrollSpeed,
    required this.pointerSpeed,
    required this.pointerSize,
    required this.primaryButton,
    required this.pointerAxes,
  });

  /// flutter-pi patch 0005 / 0009 — full set.
  static const flutterPi = MouseSettingAvailability(
    naturalScroll: true,
    scrollSpeed: true,
    pointerSpeed: true,
    pointerSize: true,
    primaryButton: true,
    pointerAxes: true,
  );

  /// Weston `cursor-size` + `[libinput]` only (no scroll-factor / axis swap).
  static const weston = MouseSettingAvailability(
    naturalScroll: true,
    scrollSpeed: false,
    pointerSpeed: true,
    pointerSize: true,
    primaryButton: true,
    pointerAxes: false,
  );

  final bool naturalScroll;
  final bool scrollSpeed;
  final bool pointerSpeed;
  final bool pointerSize;
  final bool primaryButton;
  final bool pointerAxes;
}

extension DisplayStackMouse on DisplayStack {
  MouseSettingAvailability get mouseSettings => switch (this) {
        DisplayStack.weston => MouseSettingAvailability.weston,
        DisplayStack.flutterPi || DisplayStack.unknown =>
          MouseSettingAvailability.flutterPi,
      };

  bool get isWeston => this == DisplayStack.weston;
  bool get isFlutterPi => this == DisplayStack.flutterPi;
}

/// Resolves [DisplayStack] from runtime/image stamps and/or Wayland env.
///
/// Always async — stamp reads must not use `*Sync` on the UI isolate.
final class DisplayStackProbe {
  const DisplayStackProbe({
    this.runtimeStampPath = defaultRuntimeStampPath,
    this.imageStampPath = defaultImageStampPath,
    this.environment,
    this.fileExists,
    this.readFile,
  });

  /// Written by `hmi-launch.sh` after the embedder path is chosen.
  static const defaultRuntimeStampPath = '/run/display-stack';

  /// Baked by rootfs post-build (`flutter-pi` XOR `weston`).
  static const defaultImageStampPath = '/etc/display-stack';

  /// Pre-`/run/display-stack` path (partial-upgrade fallback).
  static const legacyRuntimeStampPath = '/run/hmi/display-stack';

  /// Pre-`/etc/display-stack` path (partial-upgrade fallback).
  static const legacyImageStampPath = '/etc/hmi/display-stack';

  final String runtimeStampPath;
  final String imageStampPath;
  final Map<String, String>? environment;

  /// Test inject; default is async [File.exists].
  final Future<bool> Function(String path)? fileExists;

  /// Test inject; default is async [File.readAsString].
  final Future<String> Function(String path)? readFile;

  Future<DisplayStack> detect() async {
    final exists = fileExists ?? ((path) => File(path).exists());
    final read = readFile ?? ((path) => File(path).readAsString());
    final env = environment ?? Platform.environment;

    final paths = <String>[
      runtimeStampPath,
      imageStampPath,
      // Partial-upgrade: old stamps under /run/hmi and /etc/hmi.
      if (runtimeStampPath != legacyRuntimeStampPath) legacyRuntimeStampPath,
      if (imageStampPath != legacyImageStampPath) legacyImageStampPath,
    ];

    for (final path in paths) {
      if (!await exists(path)) {
        continue;
      }
      try {
        final parsed = _parseToken((await read(path)).trim().toLowerCase());
        if (parsed != null) {
          return parsed;
        }
      } catch (_) {
        // try next
      }
    }

    final wayland = env['WAYLAND_DISPLAY']?.trim() ?? '';
    if (wayland.isNotEmpty) {
      return DisplayStack.weston;
    }

    if (Platform.isLinux) {
      return DisplayStack.flutterPi;
    }
    return DisplayStack.unknown;
  }

  static DisplayStack? _parseToken(String token) {
    switch (token) {
      case 'weston':
      case 'wayland':
      case 'elinux':
        return DisplayStack.weston;
      case 'flutter-pi':
      case 'flutterpi':
      case 'pi':
        return DisplayStack.flutterPi;
      default:
        return null;
    }
  }
}
