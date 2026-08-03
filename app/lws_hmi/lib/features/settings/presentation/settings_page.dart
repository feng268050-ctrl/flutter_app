import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_device_info_cache.dart';
import 'package:lws_hmi/features/settings/presentation/pages/keyboard_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/advanced_settings_tab.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/common_settings_tab.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/custom_home_tab.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/device_information_tab.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/custom_home_save_success_dialog.dart';
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

  static const _tabs = <({Key key, IconData icon})>[
    (
      key: ValueKey('settings-tab-device-info'),
      icon: Icons.info_outline,
    ),
    (
      key: ValueKey('settings-tab-common'),
      icon: Icons.settings,
    ),
    (
      key: ValueKey('settings-tab-advanced'),
      icon: Icons.tune,
    ),
    (
      key: ValueKey('settings-tab-custom-home'),
      icon: Icons.home_outlined,
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
    // Blur capture root = Home wallpaper so SettingsPanel frost samples it.
    return CyberBlurBackdropScope(
      child: CustomHomePageCaptureScope(
        boundaryKey: _pageCaptureKey,
        child: RepaintBoundary(
          key: _pageCaptureKey,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(
                child: CyberBlurBackdropTarget(
                  child: SettingsHomeBackdrop(),
                ),
              ),
              Scaffold(
                backgroundColor: Colors.transparent,
                appBar: ProductPageStatusBar(
                  title: tabLabels[_currentTabIndex],
                  // Match [SettingsTopTabs.background] — no wallpaper透视 on chrome.
                  backgroundColor: SettingsTopTabs.background,
                  foregroundColor: Colors.white,
                  toolbarHeight: WorkModeStatusBarDimens.height,
                  backLabel: l10n.equipmentStatusHome,
                  backAccent: WorkModeAccent.weld,
                  onBack: canPop ? () => Navigator.of(context).maybePop() : null,
                  bottom: SettingsTopTabs(
                    labels: tabLabels,
                    tabs: SettingsPage._tabs,
                    currentIndex: _currentTabIndex,
                    onSelected: (index) {
                      if (index == _currentTabIndex) {
                        return;
                      }
                      setState(() => _currentTabIndex = index);
                    },
                  ),
                ),
                body: IndexedStack(
                  index: _currentTabIndex,
                  // Material elevation shadows on settings cards paint outside
                  // the card bounds; do not clip them at the tab layer.
                  clipBehavior: Clip.none,
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
            ],
          ),
        ),
      ),
    );
  }
}
