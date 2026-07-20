import 'package:flutter/material.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';

/// lws-ui Monitor → Work Information (placeholder until P4 business migration).
class WorkInformationTab extends StatelessWidget {
  const WorkInformationTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const MonitorPlaceholderPane(
      title: 'Work Information',
      body:
          'Process parameters, weld program context, and live work-state fields '
          'from lws-ui More Monitor will appear here. Data will come from Modbus '
          'attributes in the product catalog and domain services — not raw '
          'registers in UI code.',
    );
  }
}
