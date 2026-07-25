/// How [CyberBackdropBlur] samples content behind the glass.
///
/// CyberUI exposes **two Gaussian blur schemes** (three trigger modes):
///
/// 1. **Realtime Gaussian (default for chrome)** — [realtime] uses Material /
///    `dart:ui` [BackdropFilter] + [ImageFilter.blur] every frame.
/// 2. **Static sampling (FrostUI)** — [firstFrame] / [onChange] capture from
///    [CyberBlurBackdropScope], downscale, blur once (or on token), then freeze.
///
/// Product pages pick a mode per surface. Dialogs typically use [firstFrame].
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
}

extension CyberBlurSampleModeScheme on CyberBlurSampleMode {
  /// True for Material live [BackdropFilter] path.
  bool get isRealtimeGaussian => this == CyberBlurSampleMode.realtime;

  /// True for Frost-style frozen capture path.
  bool get isStaticSampling =>
      this == CyberBlurSampleMode.firstFrame ||
      this == CyberBlurSampleMode.onChange;
}
