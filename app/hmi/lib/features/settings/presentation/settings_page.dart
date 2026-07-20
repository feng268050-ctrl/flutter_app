import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/advanced_settings_tab.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/common_settings_tab.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/custom_home_tab.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/device_information_tab.dart';

/// Product Settings shell — four tabs (Material stand-in for FrostUI).
///
/// Tab changes are tap-only (no swipe) — same anti-mis-touch rule as Monitor.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Device Information'),
              Tab(text: 'Common Settings'),
              Tab(text: 'Advanced Settings'),
              Tab(text: 'Custom Home Page'),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            DeviceInformationTab(services: services),
            CommonSettingsTab(services: services),
            const AdvancedSettingsTab(),
            const CustomHomeTab(),
          ],
        ),
      ),
    );
  }
}
