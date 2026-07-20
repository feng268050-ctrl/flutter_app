import 'package:flutter/material.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';

/// lws-ui Monitor → AI Vision (placeholder until P4.3 libai / overlay UI).
class AiVisionTab extends StatelessWidget {
  const AiVisionTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const MonitorPlaceholderPane(
      title: 'AI Vision',
      body:
          'AI detection overlay, alert boxes, and inference status from libai.so '
          'will appear here after P4.3. Video relay from P4.1 is a prerequisite '
          'for the full lws-ui AI Vision experience.',
    );
  }
}
