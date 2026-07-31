import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/ai_vision_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/alarm_information_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/machine_status_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/videos_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/work_information_tab.dart';
import 'package:lws_hmi/features/status_bar/product_page_status_bar.dart';
import 'package:lws_hmi/features/status_bar/product_top_tabs.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_accent.dart';
import 'package:lws_hmi/features/work_mode/presentation/work_mode_status_bar.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Product Monitor — five tabs aligned with lws-ui DeviceMonitoring (Material).
///
/// Tab changes are tap-only (no swipe), matching lws-ui FragmentShowHideTabHost.
/// Tab leading icons use Material Icons (replacing lws-ui WebP mipmaps).
class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});

  static const _tabs = <({Key key, IconData icon})>[
    (
      key: ValueKey('monitor-tab-work-information'),
      icon: Icons.assessment_outlined,
    ),
    (
      key: ValueKey('monitor-tab-machine-status'),
      icon: Icons.account_tree_outlined,
    ),
    (
      key: ValueKey('monitor-tab-alarm-information'),
      icon: Icons.warning_amber_rounded,
    ),
    (
      key: ValueKey('monitor-tab-videos'),
      icon: Icons.movie_outlined,
    ),
    (
      key: ValueKey('monitor-tab-ai-vision'),
      icon: Icons.visibility_outlined,
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
  int _currentTabIndex = 0;

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
    // Theme blueGrey dark surface (same as Settings), not lws-ui #060720.
    final pageBg = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: pageBg,
      appBar: ProductPageStatusBar(
        title: tabLabels[_currentTabIndex],
        backgroundColor: pageBg,
        foregroundColor: Colors.white,
        toolbarHeight: WorkModeStatusBarDimens.height,
        // Home stays fixed; title follows the selected Monitor tab.
        backLabel: l10n.equipmentStatusHome,
        backAccent: WorkModeAccent.weld,
        onBack: canPop ? () => Navigator.of(context).maybePop() : null,
        bottom: ProductTopTabs(
          labels: tabLabels,
          tabs: MonitorPage._tabs,
          currentIndex: _currentTabIndex,
          layout: ProductTopTabLayout.monitorPinnedIcon,
          onSelected: (index) {
            if (index == _currentTabIndex) {
              return;
            }
            CyberClickSoundRegistry.playClick();
            setState(() => _currentTabIndex = index);
          },
        ),
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: const [
          WorkInformationTab(),
          MachineStatusTab(),
          AlarmInformationTab(),
          VideosTab(),
          AiVisionTab(),
        ],
      ),
    );
  }
}
