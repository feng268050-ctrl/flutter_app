import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_device_info_cache.dart';
import 'package:lws_hmi/features/settings/presentation/pages/keyboard_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/advanced_settings_tab.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/common_settings_tab.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/custom_home_tab.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/device_information_tab.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/features/status_bar/product_page_status_bar.dart';
import 'package:lws_hmi/features/status_bar/product_tab_slide_body.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_accent.dart';
import 'package:lws_hmi/features/work_mode/presentation/work_mode_status_bar.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Optional [AppRoutes.settings] arguments (keyboard restore / deep-link nested page).
final class SettingsRouteArgs {
  const SettingsRouteArgs({
    this.openKeyboardOnLaunch = false,
    this.initialNestedPage,
  });

  final bool openKeyboardOnLaunch;

  /// Pushed once after Settings mounts (e.g. System / Control-board Upgrade).
  final Widget? initialNestedPage;
}

/// Product Settings shell — four tabs; Custom Home body is blank for now.
///
/// Tab changes animate L/R on tap (finger swipe disabled — anti-mis-touch).
/// Top tabs use equal-width Material chrome aligned with card insets.
/// Page blur uses a static baked σ30 plate ([SettingsBlurredPageShell] default).
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.openKeyboardOnLaunch = false,
    this.initialNestedPage,
    this.cameraDeviceInfoCache,
  });

  /// When true (post–XKB restart restore), open Common → Keyboard once.
  final bool openKeyboardOnLaunch;

  /// When set (e.g. Home “Go to Settings” for an update), push this sub-page
  /// once after Settings mounts.
  final Widget? initialNestedPage;

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

class _SettingsPageState extends State<SettingsPage> {
  late int _currentTabIndex;
  bool _nestedLaunched = false;

  @override
  void initState() {
    super.initState();
    _currentTabIndex = widget.openKeyboardOnLaunch ? 1 : 0;
    // Route-level ensure (not only Device Information tab).
    scheduleEnsureModbusLive(context);
    if (widget.openKeyboardOnLaunch || widget.initialNestedPage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _nestedLaunched) {
          return;
        }
        _nestedLaunched = true;
        final nested = widget.initialNestedPage ??
            (widget.openKeyboardOnLaunch
                ? KeyboardSettingsPage(services: AppScope.of(context))
                : null);
        if (nested == null) {
          return;
        }
        pushSettingsPage(context, nested);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final services = AppScope.of(context);
    final tabLabels = SettingsPage._tabLabels(l10n);
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    // Sharp wallpaper → static baked σ30 plate → panels (tint/rim only).
    return SettingsBlurredPageShell(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: ProductPageStatusBar(
          title: tabLabels[_currentTabIndex],
          // Share the page wallpaper across status bar, tabs, and body.
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          toolbarHeight: WorkModeStatusBarDimens.height,
          backLabel: tabLabels[_currentTabIndex],
          useHomeIcon: true,
          centerClock: true,
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
          child: ProductTabSlideBody(
            index: _currentTabIndex,
            children: [
              DeviceInformationTab(
                services: services,
                cameraDeviceInfoCache: widget.cameraDeviceInfoCache,
              ),
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
