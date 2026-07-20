import 'package:flutter/material.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/ai_vision_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/alarm_information_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/machine_status_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/videos_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/work_information_tab.dart';

/// Product Monitor — five tabs aligned with lws-ui More Monitor (Material stand-in).
class MonitorPage extends StatelessWidget {
  const MonitorPage({super.key});

  static const _tabLabels = <String>[
    'Work Information',
    'Machine Status',
    'Alarm Information',
    'Videos',
    'AI Vision',
  ];

  static const _tabKeys = <Key>[
    ValueKey('monitor-tab-work-information'),
    ValueKey('monitor-tab-machine-status'),
    ValueKey('monitor-tab-alarm-information'),
    ValueKey('monitor-tab-videos'),
    ValueKey('monitor-tab-ai-vision'),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabLabels.length,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          title: const Text('Monitor'),
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          bottom: TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white70,
            tabs: [
              for (var i = 0; i < _tabLabels.length; i++)
                Tab(key: _tabKeys[i], text: _tabLabels[i]),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            WorkInformationTab(),
            MachineStatusTab(),
            AlarmInformationTab(),
            VideosTab(),
            AiVisionTab(),
          ],
        ),
      ),
    );
  }
}
