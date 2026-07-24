import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/work_mode/presentation/work_mode_status_bar.dart';

/// Quick Mode shell: work-mode status bar + blank body (no process UI yet).
final class QuickModePage extends StatefulWidget {
  const QuickModePage({super.key});

  @override
  State<QuickModePage> createState() => _QuickModePageState();
}

final class _QuickModePageState extends State<QuickModePage> {
  @override
  void initState() {
    super.initState();
    scheduleEnsureModbusLive(context);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF060720),
      appBar: WorkModeStatusBar(mode: WorkMode.quick),
      body: SizedBox.expand(
        child: ColoredBox(
          color: Color(0xFF060720),
          child: Center(
            child: Text(
              'Coming soon',
              key: ValueKey('quick-mode-placeholder'),
              style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 18),
            ),
          ),
        ),
      ),
    );
  }
}
