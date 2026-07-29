import 'dart:math' as math;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/ai_vision_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/alarm_information_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/machine_status_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/videos_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/work_information_tab.dart';
import 'package:lws_hmi/features/status_bar/product_page_status_bar.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_accent.dart';
import 'package:lws_hmi/features/work_mode/presentation/work_mode_status_bar.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Product Monitor — five tabs aligned with lws-ui DeviceMonitoring (Material).
///
/// Tab changes are tap-only (no swipe), matching lws-ui FragmentShowHideTabHost.
/// Tab leading icons match lws-ui `job_icon*` / `videos_icon` / `ai_vision_home`.
class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});

  /// Shared page chrome fill — lws-ui `tab_bg` (#060720).
  static const background = Color(0xFF060720);

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
    return Scaffold(
      backgroundColor: MonitorPage.background,
      appBar: ProductPageStatusBar(
        title: tabLabels[_currentTabIndex],
        backgroundColor: MonitorPage.background,
        foregroundColor: Colors.white,
        toolbarHeight: WorkModeStatusBarDimens.height,
        // Home stays fixed; title follows the selected Monitor tab.
        backLabel: l10n.equipmentStatusHome,
        backAccent: WorkModeAccent.weld,
        onBack: canPop ? () => Navigator.of(context).maybePop() : null,
        bottom: _MonitorTopTabs(
          labels: tabLabels,
          tabs: MonitorPage._tabs,
          currentIndex: _currentTabIndex,
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

final class _MonitorTopTabs extends StatefulWidget
    implements PreferredSizeWidget {
  const _MonitorTopTabs({
    required this.labels,
    required this.tabs,
    required this.currentIndex,
    required this.onSelected,
  });

  /// lws-ui `view_top_tab` TabLayout height (slightly tightened).
  static const height = 78.0;

  /// Wider than lws-ui `top_tab_item_width` (236) to fit fontSize 24 labels.
  static const minTabWidth = 280.0;
  static const _sidePadding = 4.0;
  static const _borderAsset = 'assets/monitor/job_border1.webp';

  final List<String> labels;
  final List<({Key key, String iconAsset})> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  State<_MonitorTopTabs> createState() => _MonitorTopTabsState();
}

final class _MonitorTopTabsState extends State<_MonitorTopTabs> {
  final _scrollController = ScrollController();
  final _itemKeys = <GlobalKey>[];

  @override
  void initState() {
    super.initState();
    _syncItemKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSelectedVisible());
  }

  @override
  void didUpdateWidget(covariant _MonitorTopTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncItemKeys();
    if (oldWidget.currentIndex != widget.currentIndex ||
        oldWidget.labels != widget.labels) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _ensureSelectedVisible());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _syncItemKeys() {
    while (_itemKeys.length < widget.tabs.length) {
      _itemKeys.add(GlobalKey());
    }
    if (_itemKeys.length > widget.tabs.length) {
      _itemKeys.removeRange(widget.tabs.length, _itemKeys.length);
    }
  }

  void _ensureSelectedVisible() {
    if (!mounted || widget.currentIndex < 0) {
      return;
    }
    if (widget.currentIndex >= _itemKeys.length) {
      return;
    }
    final ctx = _itemKeys[widget.currentIndex].currentContext;
    if (ctx == null) {
      return;
    }
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  static double _tabWidthFor(String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          height: 1.0,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    // Centered label; icon overlays left with equal L/T/B inset — keep side room.
    const iconSize = _MonitorTopTabItem.iconSize;
    final iconInset = (_MonitorTopTabs.height - iconSize) / 2;
    final side = iconInset + iconSize + _MonitorTopTabItem.iconTextGap;
    return math.max(_MonitorTopTabs.minTabWidth, painter.width + 2 * side);
  }

  @override
  Widget build(BuildContext context) {
    // lws-ui: scrollable TabLayout + `@mipmap/job_border1`.
    return SizedBox(
      height: _MonitorTopTabs.height,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(_MonitorTopTabs._borderAsset),
            fit: BoxFit.fill,
          ),
        ),
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: _MonitorTopTabs._sidePadding,
          ),
          itemCount: widget.tabs.length,
          itemBuilder: (context, i) {
            return KeyedSubtree(
              key: _itemKeys[i],
              child: SizedBox(
                width: _tabWidthFor(widget.labels[i]),
                child: _MonitorTopTabItem(
                  key: widget.tabs[i].key,
                  label: widget.labels[i],
                  iconAsset: widget.tabs[i].iconAsset,
                  selected: i == widget.currentIndex,
                  onTap: () => widget.onSelected(i),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

final class _MonitorTopTabItem extends StatelessWidget {
  const _MonitorTopTabItem({
    super.key,
    required this.label,
    required this.iconAsset,
    required this.selected,
    required this.onTap,
  });

  static const iconSize = 31.0;
  static const iconTextGap = 6.0;

  final String label;
  final String iconAsset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white60;
    // Equal left/top/bottom inset from this tab's bounds (not the strip).
    final iconInset = (_MonitorTopTabs.height - iconSize) / 2;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            // Label centered in the tab; icon is positioned independently.
            Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  height: 1.0,
                ),
              ),
            ),
            Positioned(
              left: iconInset,
              top: iconInset,
              width: iconSize,
              height: iconSize,
              child: Image.asset(
                iconAsset,
                width: iconSize,
                height: iconSize,
                color: color,
                colorBlendMode: BlendMode.srcIn,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.circle, size: 23, color: color),
              ),
            ),
            // Flush with opaque bottom of `job_border1` (~3dp fringe).
            Positioned(
              left: 14,
              right: 14,
              bottom: 3,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: 2,
                color: selected ? Colors.white : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
