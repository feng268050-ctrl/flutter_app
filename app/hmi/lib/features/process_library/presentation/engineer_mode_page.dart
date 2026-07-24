import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/work_mode/presentation/work_mode_status_bar.dart';

/// Engineer Mode shell: work-mode status bar + blank body (no process UI yet).
final class EngineerModePage extends StatefulWidget {
  const EngineerModePage({
    super.key,
    this.initialProcessType,
    this.initialPresetUuid,
  });

  /// Reserved for later draft handoff from Quick Mode.
  final Object? initialProcessType;
  final String? initialPresetUuid;

  @override
  State<EngineerModePage> createState() => _EngineerModePageState();
}

final class _EngineerModePageState extends State<EngineerModePage> {
  @override
  void initState() {
    super.initState();
    scheduleEnsureModbusLive(context);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF060720),
      appBar: WorkModeStatusBar(mode: WorkMode.engineer),
      body: SizedBox.expand(
        child: ColoredBox(
          color: Color(0xFF060720),
          child: Center(
            child: Text(
              'Coming soon',
              key: ValueKey('engineer-mode-placeholder'),
              style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 18),
            ),
          ),
        ),
      ),
    );
  }
}
