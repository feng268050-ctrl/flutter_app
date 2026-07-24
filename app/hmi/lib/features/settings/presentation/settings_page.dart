import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/pages/keyboard_settings_page.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/advanced_settings_tab.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/common_settings_tab.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/custom_home_tab.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/device_information_tab.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/features/status_bar/product_page_status_bar.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Product Settings shell — four tabs (Material stand-in for FrostUI).
///
/// Tab changes are tap-only (no swipe) — same anti-mis-touch rule as Monitor.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.openKeyboardOnLaunch = false,
  });

  /// When true (post–XKB restart restore), open Common → Keyboard once.
  final bool openKeyboardOnLaunch;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 4,
    vsync: this,
    initialIndex: widget.openKeyboardOnLaunch ? 1 : 0,
  );
  bool _keyboardPushed = false;

  @override
  void initState() {
    super.initState();
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
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final services = AppScope.of(context);
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return Scaffold(
      appBar: ProductPageStatusBar(
        title: l10n.settingsTitle,
        onBack: canPop
            ? () => Navigator.of(context).maybePop()
            : null,
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          onTap: (_) => CyberClickSoundRegistry.playClick(),
          tabs: [
            Tab(text: l10n.settingsTabDeviceInfo),
            Tab(text: l10n.settingsTabCommon),
            Tab(text: l10n.settingsTabAdvanced),
            Tab(text: l10n.settingsTabCustomHome),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          DeviceInformationTab(services: services),
          CommonSettingsTab(services: services),
          const AdvancedSettingsTab(),
          const CustomHomeTab(),
        ],
      ),
    );
  }
}
