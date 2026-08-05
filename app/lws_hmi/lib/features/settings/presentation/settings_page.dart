import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_device_info_cache.dart';
import 'package:lws_hmi/features/settings/presentation/pages/keyboard_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/advanced_settings_tab.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/common_settings_tab.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/custom_home_tab.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/device_information_tab.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/features/status_bar/product_page_status_bar.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_accent.dart';
import 'package:lws_hmi/features/work_mode/presentation/work_mode_status_bar.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Product Settings shell — four tabs; Custom Home body is blank for now.
///
/// Tab changes are tap-only (no swipe) — same anti-mis-touch rule as Monitor.
/// Top tabs use equal-width Material chrome aligned with card insets.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.openKeyboardOnLaunch = false,
    this.cameraDeviceInfoCache,
  });

  /// When true (post–XKB restart restore), open Common → Keyboard once.
  final bool openKeyboardOnLaunch;

  /// Shared camera version cache (cloud WS + Camera settings).
  final CameraDeviceInfoCache? cameraDeviceInfoCache;

  static const _tabs = <({
    Key key,
    IconData icon,
    double iconLeftNudge,
    bool balanceIconLabelGap,
  })>[
    (
      key: ValueKey('settings-tab-device-info'),
      icon: Icons.info_outline,
      iconLeftNudge: 0,
      balanceIconLabelGap: false,
    ),
    (
      key: ValueKey('settings-tab-common'),
      icon: Icons.settings,
      iconLeftNudge: 0,
      balanceIconLabelGap: false,
    ),
    (
      key: ValueKey('settings-tab-advanced'),
      icon: Icons.tune,
      iconLeftNudge: 0,
      balanceIconLabelGap: false,
    ),
    (
      key: ValueKey('settings-tab-custom-home'),
      icon: Icons.home_outlined,
      iconLeftNudge: 0,
      // Icon left inset == gap between icon and centered label.
      balanceIconLabelGap: true,
    ),
  ];

  static List<String> _tabLabels(AppLocalizations l10n) => [
        l10n.settingsTabDeviceInfo,
        l10n.settingsTabCommon,
        l10n.settingsTabAdvanced,
        l10n.settingsTabCustomHome,
      ];

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with RouteAware {
  late int _currentTabIndex;
  bool _keyboardPushed = false;
  /// Nested Settings push covers this route — pause live σ30 while covered.
  bool _routeCovered = false;

  @override
  void initState() {
    super.initState();
    _currentTabIndex = widget.openKeyboardOnLaunch ? 1 : 0;
    // Route-level ensure (not only Device Information tab).
    scheduleEnsureModbusLive(context);
    if (widget.openKeyboardOnLaunch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _keyboardPushed) return;
        _keyboardPushed = true;
        final services = AppScope.of(context);
        pushSettingsPage(
          context,
          KeyboardSettingsPage(services: services),
        );
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    appRouteObserver.unsubscribe(this);
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() {
    if (!_routeCovered) {
      setState(() => _routeCovered = true);
    }
  }

  @override
  void didPopNext() {
    if (_routeCovered) {
      setState(() => _routeCovered = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final services = AppScope.of(context);
    final tabLabels = SettingsPage._tabLabels(l10n);
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    // Sharp wallpaper → page ImageFiltered blur → panels with rim only (no fill).
    // While a nested Settings route is up, skip live σ30 (parent stays under
    // Cupertino slide; a second/ongoing Gaussian stalls RK3566 exit).
    return SettingsBlurredPageShell(
      livePageBlur: !_routeCovered,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: ProductPageStatusBar(
          title: tabLabels[_currentTabIndex],
          // Share the page wallpaper across status bar, tabs, and body.
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          toolbarHeight: WorkModeStatusBarDimens.height,
          backLabel: l10n.equipmentStatusHome,
          backAccent: WorkModeAccent.weld,
          onBack: canPop ? () => Navigator.of(context).maybePop() : null,
          bottom: SettingsTopTabs(
            labels: tabLabels,
            tabs: SettingsPage._tabs,
            currentIndex: _currentTabIndex,
            backgroundColor: Colors.transparent,
            onSelected: (index) {
              if (index == _currentTabIndex) {
                return;
              }
              setState(() => _currentTabIndex = index);
            },
          ),
        ),
        // Scaffold starts body layout at the custom Tab divider.
        // Clip there so Settings content cannot enter the tab strip.
        body: ClipRect(
          child: IndexedStack(
            index: _currentTabIndex,
            children: [
              DeviceInformationTab(services: services),
              CommonSettingsTab(
                services: services,
                cameraDeviceInfoCache: widget.cameraDeviceInfoCache,
              ),
              const AdvancedSettingsTab(),
              const CustomHomeTab(),
            ],
          ),
        ),
      ),
    );
  }
}
