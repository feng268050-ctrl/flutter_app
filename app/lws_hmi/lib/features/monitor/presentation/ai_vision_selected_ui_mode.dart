/// lws-ui `AiVisionFragment.SelectedVideoUiMode` parity.
enum AiVisionSelectedUiMode {
  /// No process video selected — live PR0 preview.
  liveNoVideo,

  /// Selected video, no timeline yet — show cover + Detect.
  idleReadyToDetect,

  /// Selected video with timeline — cover + Replay/Re-detect.
  idleDetectionComplete,

  /// Detect or Replay playback in progress.
  playback,
}
