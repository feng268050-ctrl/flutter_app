import 'package:flutter/material.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';

/// lws-ui Monitor → Videos (placeholder until P4.1 MediaMTX / preview).
class VideosTab extends StatelessWidget {
  const VideosTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const MonitorPlaceholderPane(
      title: 'Videos',
      body:
          'Camera preview and relay streams (MediaMTX / GStreamer / flutter-pi '
          'video) belong to P4.1. This tab reserves the Monitor layout slot '
          'matching lws-ui Videos.',
    );
  }
}
