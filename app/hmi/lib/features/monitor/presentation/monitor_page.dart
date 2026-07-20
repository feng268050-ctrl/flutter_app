import 'package:flutter/material.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/ai_vision_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/alarm_information_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/machine_status_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/videos_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/work_information_tab.dart';

/// Product Monitor — five tabs aligned with lws-ui DeviceMonitoring (Material).
///
/// Tab changes are tap-only (no swipe), matching lws-ui FragmentShowHideTabHost.
/// Tab leading icons match lws-ui `job_icon*` / `videos_icon` / `ai_vision_home`.
class MonitorPage extends StatelessWidget {
  const MonitorPage({super.key});

  static const _tabs = <({Key key, String label, String iconAsset})>[
    (
      key: ValueKey('monitor-tab-work-information'),
      label: 'Work Information',
      iconAsset: 'assets/monitor/job_icon1.webp',
    ),
    (
      key: ValueKey('monitor-tab-machine-status'),
      label: 'Machine Status',
      iconAsset: 'assets/monitor/job_icon2.webp',
    ),
    (
      key: ValueKey('monitor-tab-alarm-information'),
      label: 'Alarm Information',
      iconAsset: 'assets/monitor/job_icon3.webp',
    ),
    (
      key: ValueKey('monitor-tab-videos'),
      label: 'Videos',
      iconAsset: 'assets/monitor/videos_icon.webp',
    ),
    (
      key: ValueKey('monitor-tab-ai-vision'),
      label: 'AI Vision',
      iconAsset: 'assets/monitor/ai_vision_tab.webp',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
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
              for (final tab in _tabs)
                Tab(
                  key: tab.key,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        tab.iconAsset,
                        width: 24,
                        height: 24,
                        color: Colors.white,
                        colorBlendMode: BlendMode.srcIn,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.circle, size: 22),
                      ),
                      const SizedBox(width: 8),
                      Text(tab.label),
                    ],
                  ),
                ),
            ],
          ),
        ),
        body: const TabBarView(
          physics: NeverScrollableScrollPhysics(),
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
