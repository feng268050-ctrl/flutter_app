/// How [CyberBackdropBlur] samples content behind the glass.
///
/// Product pages pick a mode per surface; the default is [realtime].
/// Assignment of which Home / Monitor / dialog widgets use which mode is TBD.
enum CyberBlurSampleMode {
  /// Continuous per-frame sampling (compositor [BackdropFilter]). Default.
  realtime,

  /// Capture once after the first stable frame, then freeze the blurred bitmap.
  firstFrame,

  /// Re-sample when [CyberBackdropBlur.sampleToken] changes, or when
  /// [CyberBackdropBlurController.requestSample] is called.
  onChange,
}
