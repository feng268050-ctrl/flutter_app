import 'package:flutter/material.dart';

/// Apply HAL `display.conf` `ui_scale` as a pure multiplier on the embedder
/// [MediaQuery].
///
/// **`ui_scale == 1.0` means physical 1:1** — no FittedBox rematch, no design
/// density compensation. Any previous hard-coded “match simulator / panel”
/// scale lives in the preference value itself (e.g. QEMU/host sim may set
/// `ui_scale≈1.13` in OS Settings to approximate the ynh960 panel).
Widget matchEmbedderDensity(
  BuildContext context,
  Widget? child, {
  double uiScale = 1.0,
}) {
  final content = child ?? const SizedBox.shrink();
  final scale = uiScale.clamp(0.5, 2.0);
  // Treat ~1.0 as identity (slider / conf float noise).
  if ((scale - 1.0).abs() < 0.005) {
    return content;
  }

  final mq = MediaQuery.of(context);
  final dpr = mq.devicePixelRatio;
  final logical = Size(mq.size.width / scale, mq.size.height / scale);
  return SizedBox(
    width: mq.size.width,
    height: mq.size.height,
    child: FittedBox(
      fit: BoxFit.fill,
      child: SizedBox(
        width: logical.width,
        height: logical.height,
        child: MediaQuery(
          data: mq.copyWith(
            size: logical,
            devicePixelRatio: dpr * scale,
          ),
          child: content,
        ),
      ),
    ),
  );
}
