import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/ai_vision_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/alarm_information_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/machine_status_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/videos_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/work_information_tab.dart';

/// Product Monitor — five tabs aligned with lws-ui DeviceMonitoring (Material).
///
/// Tab changes are tap-only (no swipe), matching lws-ui FragmentShowHideTabHost.
/// Tab leading icons match lws-ui `job_icon*` / `videos_icon` / `ai_vision_home`.
class MonitorPage extends StatefulWidget {
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
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  @override
  void initState() {
    super.initState();
    // Route-level ensure: Alarm tab is lazy and must not be the only starter.
    scheduleEnsureModbusLive(context);
  }

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return DefaultTabController(
      length: MonitorPage._tabs.length,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          title: const Text('Monitor'),
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          leading: canPop
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    CyberClickSoundRegistry.playClick();
                    Navigator.of(context).maybePop();
                  },
                )
              : null,
          bottom: TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white70,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.0,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.0,
            ),
            onTap: (_) => CyberClickSoundRegistry.playClick(),
            tabs: [
              for (final tab in MonitorPage._tabs)
                Tab(
                  key: tab.key,
                  height: 46,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Image.asset(
                        tab.iconAsset,
                        width: 18,
                        height: 18,
                        color: Colors.white,
                        colorBlendMode: BlendMode.srcIn,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.circle, size: 16),
                      ),
                      const SizedBox(width: 6),
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
