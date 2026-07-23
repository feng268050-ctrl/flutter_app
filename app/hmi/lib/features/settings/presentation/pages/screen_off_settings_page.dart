import 'package:cyber_hal/output.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';

class ScreenOffSettingsPage extends StatefulWidget {
  const ScreenOffSettingsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<ScreenOffSettingsPage> createState() => _ScreenOffSettingsPageState();
}

class _ScreenOffSettingsPageState extends State<ScreenOffSettingsPage> {
  AutoSleepPolicy _value = AutoSleepPolicy.never;
  bool _loading = true;

  static const _options = <(AutoSleepPolicy, String)>[
    (AutoSleepPolicy.minutes10, '10 min'),
    (AutoSleepPolicy.minutes30, '30 min'),
    (AutoSleepPolicy.minutes60, '60 min'),
    (AutoSleepPolicy.never, 'Never'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final policy = await widget.services.autoSleep.getPolicy();
    if (!mounted) return;
    setState(() {
      _value = policy;
      _loading = false;
    });
  }

  Future<void> _select(AutoSleepPolicy policy) async {
    setState(() => _value = policy);
    await widget.services.autoSleep.setPolicy(policy);
  }

  String get _summaryLabel {
    for (final (p, label) in _options) {
      if (p == _value) return label;
    }
    return 'Never';
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Screen-off Time',
      body: SettingsScrollView(
        children: [
          const SettingsSectionHeader('Auto-Lock'),
          SettingsGroup(
            children: [
              for (final (policy, label) in _options)
                SettingsOptionTile(
                  title: label,
                  selected: !_loading && _value == policy,
                  onTap: _loading ? null : () => _select(policy),
                ),
            ],
          ),
          if (!_loading)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Current: $_summaryLabel',
                style: const TextStyle(color: Colors.white54),
              ),
            ),
        ],
      ),
    );
  }
}
