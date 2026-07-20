import 'package:flutter/material.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';

/// lws-ui Monitor → Machine Status (placeholder until P4 business migration).
class MachineStatusTab extends StatelessWidget {
  const MachineStatusTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const MonitorPlaceholderPane(
      title: 'Machine Status',
      body:
          'Machine run state, interlocks, and controller status rows aligned with '
          'lws-ui Monitor Machine Status will land here. Live values will subscribe '
          'via cyber_hal Modbus watch APIs on configured attribute ids.',
    );
  }
}
