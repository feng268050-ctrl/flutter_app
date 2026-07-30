import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/pages/keyboard_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/advanced_settings_tab.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/common_settings_tab.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/custom_home_tab.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/device_information_tab.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/custom_home_save_success_dialog.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/features/status_bar/product_page_status_bar.dart';
import 'package:lws_hmi/features/status_bar/product_top_tabs.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_accent.dart';
import 'package:lws_hmi/features/work_mode/presentation/work_mode_status_bar.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Product Settings shell — four tabs; Custom Home body is blank for now.
///
/// Tab changes are tap-only (no swipe) — same anti-mis-touch rule as Monitor.
/// Chrome matches lws-ui `DeviceSettingActivity` + `TopTabView`.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.openKeyboardOnLaunch = false,
  });

  /// When true (post–XKB restart restore), open Common → Keyboard once.
  final bool openKeyboardOnLaunch;

  /// Shared page chrome fill — lws-ui `tab_bg` (#060720).
  static const background = Color(0xFF060720);

  static const _tabs = <({Key key, String iconAsset})>[
    (
      key: ValueKey('settings-tab-device-info'),
      iconAsset: 'assets/settings/device_info.webp',
    ),
    (
      key: ValueKey('settings-tab-common'),
      iconAsset: 'assets/settings/common_settings.webp',
    ),
    (
      key: ValueKey('settings-tab-advanced'),
      iconAsset: 'assets/settings/settings.webp',
    ),
    (
      key: ValueKey('settings-tab-custom-home'),
      iconAsset: 'assets/settings/placeholder.webp',
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
  bool _keyboardPushed = false;
  final GlobalKey _pageCaptureKey =
      GlobalKey(debugLabel: 'settingsPageCapture');

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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final services = AppScope.of(context);
    final tabLabels = SettingsPage._tabLabels(l10n);
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return CustomHomePageCaptureScope(
      boundaryKey: _pageCaptureKey,
      child: RepaintBoundary(
        key: _pageCaptureKey,
        child: Scaffold(
          backgroundColor: SettingsPage.background,
          appBar: ProductPageStatusBar(
            title: tabLabels[_currentTabIndex],
            backgroundColor: SettingsPage.background,
            foregroundColor: Colors.white,
            toolbarHeight: WorkModeStatusBarDimens.height,
            backLabel: l10n.equipmentStatusHome,
            backAccent: WorkModeAccent.weld,
            onBack: canPop ? () => Navigator.of(context).maybePop() : null,
            bottom: ProductTopTabs(
              labels: tabLabels,
              tabs: SettingsPage._tabs,
              currentIndex: _currentTabIndex,
              layout: ProductTopTabLayout.lwsUi,
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
            children: [
              DeviceInformationTab(services: services),
              CommonSettingsTab(services: services),
              const AdvancedSettingsTab(),
              const CustomHomeTab(),
            ],
          ),
        ),
      ),
    );
  }
}
