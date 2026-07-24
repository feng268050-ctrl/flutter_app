import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/ai_vision_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/alarm_information_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/machine_status_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/videos_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/work_information_tab.dart';
import 'package:lws_hmi/features/status_bar/product_page_status_bar.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Product Monitor — five tabs aligned with lws-ui DeviceMonitoring (Material).
///
/// Tab changes are tap-only (no swipe), matching lws-ui FragmentShowHideTabHost.
/// Tab leading icons match lws-ui `job_icon*` / `videos_icon` / `ai_vision_home`.
class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});

  static const _tabs = <({Key key, String iconAsset})>[
    (
      key: ValueKey('monitor-tab-work-information'),
      iconAsset: 'assets/monitor/job_icon1.webp',
    ),
    (
      key: ValueKey('monitor-tab-machine-status'),
      iconAsset: 'assets/monitor/job_icon2.webp',
    ),
    (
      key: ValueKey('monitor-tab-alarm-information'),
      iconAsset: 'assets/monitor/job_icon3.webp',
    ),
    (
      key: ValueKey('monitor-tab-videos'),
      iconAsset: 'assets/monitor/videos_icon.webp',
    ),
    (
      key: ValueKey('monitor-tab-ai-vision'),
      iconAsset: 'assets/monitor/ai_vision_tab.webp',
    ),
  ];

  static List<String> _tabLabels(AppLocalizations l10n) => [
        l10n.deviceMonitorWorkInfoTitle,
        l10n.deviceMonitorMachineStatusTitle,
        l10n.deviceMonitorWarnInfoTitle,
        l10n.videosTitle,
        l10n.aiVisionTitle,
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
    final l10n = AppLocalizations.of(context)!;
    final tabLabels = MonitorPage._tabLabels(l10n);
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return DefaultTabController(
      length: MonitorPage._tabs.length,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: ProductPageStatusBar(
          title: l10n.deviceMonitorHomeTitle,
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          onBack: canPop
              ? () => Navigator.of(context).maybePop()
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
              for (var i = 0; i < MonitorPage._tabs.length; i++)
                Tab(
                  key: MonitorPage._tabs[i].key,
                  height: 46,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Image.asset(
                        MonitorPage._tabs[i].iconAsset,
                        width: 18,
                        height: 18,
                        color: Colors.white,
                        colorBlendMode: BlendMode.srcIn,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.circle, size: 16),
                      ),
                      const SizedBox(width: 6),
                      Text(tabLabels[i]),
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
