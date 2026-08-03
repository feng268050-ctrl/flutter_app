/// How [CyberBackdropBlur] samples content behind the glass.
///
/// CyberUI exposes **two Gaussian blur schemes** (four trigger modes):
///
/// 1. **Realtime Gaussian (default for chrome)** — [realtime] uses Material /
///    `dart:ui` [BackdropFilter] + [ImageFilter.blur] every frame.
/// 2. **Static sampling (FrostUI)** — capture from [CyberBlurBackdropScope],
///    downscale, blur:
///    - [firstFrame] — capture once, freeze
///    - [onChange] — re-capture on token / controller
///    - [followLayout] — capture backdrop once; re-crop as the glass moves
///      (scroll / layout) so wallpaper perspective stays correct
///
/// Product pages pick a mode per surface. Dialogs typically use [firstFrame].
/// Scrollable Settings panels use [followLayout] (Weston [realtime] composites
/// black).
enum CyberBlurSampleMode {
  /// Continuous per-frame sampling (compositor [BackdropFilter]). Default.
  /// Scheme: realtime Gaussian (Material).
  realtime,

  /// Capture once after the first stable frame, then freeze the blurred bitmap.
  /// Scheme: static sampling (FrostUI).
  firstFrame,

  /// Re-sample when [CyberBackdropBlur.sampleToken] changes, or when
  /// [CyberBackdropBlurController.requestSample] is called.
  /// Scheme: static sampling (FrostUI).
  onChange,

  /// Keep a frozen full-backdrop capture; re-crop to the glass bounds whenever
  /// layout/scroll moves the widget so see-through stays aligned.
  /// Scheme: static sampling (FrostUI).
  followLayout,
}

extension CyberBlurSampleModeScheme on CyberBlurSampleMode {
  /// True for Material live [BackdropFilter] path.
  bool get isRealtimeGaussian => this == CyberBlurSampleMode.realtime;

  /// True for Frost-style frozen capture path.
  bool get isStaticSampling =>
      this == CyberBlurSampleMode.firstFrame ||
      this == CyberBlurSampleMode.onChange ||
      this == CyberBlurSampleMode.followLayout;
}
