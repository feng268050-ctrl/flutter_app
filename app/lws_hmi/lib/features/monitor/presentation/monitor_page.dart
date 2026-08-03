import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/ai_vision_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/alarm_information_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/machine_status_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/videos_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/work_information_tab.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
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
  const MonitorPage({
    super.key,
    this.initialTabIndex = tabWorkInformation,
  });

  static const tabWorkInformation = 0;
  static const tabMachineStatus = 1;
  static const tabAlarmInformation = 2;
  static const tabVideos = 3;
  static const tabAiVision = 4;

  /// Selected tab when the route opens (clamped to valid range).
  final int initialTabIndex;

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

/// Optional [Navigator] arguments for [AppRoutes.monitor].
final class MonitorRouteArgs {
  const MonitorRouteArgs(
      {this.initialTabIndex = MonitorPage.tabWorkInformation});

  /// Opens Monitor on the AI Vision tab (Home quick-action entry).
  static const aiVision = MonitorRouteArgs(
    initialTabIndex: MonitorPage.tabAiVision,
  );

  final int initialTabIndex;
}

class _MonitorPageState extends State<MonitorPage> {
  late int _currentTabIndex;

  @override
  void initState() {
    super.initState();
    _currentTabIndex = widget.initialTabIndex.clamp(
      0,
      MonitorPage._tabs.length - 1,
    );
    // Route-level ensure: Alarm tab is lazy and must not be the only starter.
    scheduleEnsureModbusLive(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tabLabels = MonitorPage._tabLabels(l10n);
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    // Capture root = Home wallpaper so MonitorGlassCard → SettingsPanel frost
    // samples it (same stack as SettingsPage).
    return CyberBlurBackdropScope(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: CyberBlurBackdropTarget(
              // Tone down the wallpaper's broad specular bands only on
              // Monitor, preserving enough contrast for panel cast shadows.
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SettingsHomeBackdrop(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x16000000), Color(0x26000000)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: ProductPageStatusBar(
              title: tabLabels[_currentTabIndex],
              // Keep one continuous wallpaper behind Monitor's status and tabs.
              backgroundColor: Colors.transparent,
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
                backgroundColor: Colors.transparent,
                onSelected: (index) {
                  if (index == _currentTabIndex) {
                    return;
                  }
                  CyberClickSoundRegistry.playClick();
                  setState(() => _currentTabIndex = index);
                },
              ),
            ),
            // Scaffold already starts body layout at the custom Tab divider.
            // Clip there so scroll content cannot paint into the Tab strip.
            body: ClipRect(
              child: IndexedStack(
                index: _currentTabIndex,
                children: [
                  const WorkInformationTab(),
                  const MachineStatusTab(),
                  const AlarmInformationTab(),
                  const VideosTab(),
                  AiVisionTab(
                    visible: _currentTabIndex == MonitorPage.tabAiVision,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
