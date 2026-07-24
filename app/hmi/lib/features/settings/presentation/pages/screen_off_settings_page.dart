import 'package:cyber_hal/output.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

class ScreenOffSettingsPage extends StatefulWidget {
  const ScreenOffSettingsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<ScreenOffSettingsPage> createState() => _ScreenOffSettingsPageState();
}

class _ScreenOffSettingsPageState extends State<ScreenOffSettingsPage> {
  AutoSleepPolicy _value = AutoSleepPolicy.never;
  bool _loading = true;

  List<(AutoSleepPolicy, String Function(AppLocalizations l10n))> _options(
    AppLocalizations l10n,
  ) =>
      [
        (AutoSleepPolicy.minutes10, (_) => l10n.screenOffOption10Min),
        (AutoSleepPolicy.minutes30, (_) => l10n.screenOffOption30Min),
        (AutoSleepPolicy.minutes60, (_) => l10n.screenOffOption60Min),
        (AutoSleepPolicy.never, (_) => 'Never'),
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

  String _summaryLabel(AppLocalizations l10n) {
    for (final (p, label) in _options(l10n)) {
      if (p == _value) return label(l10n);
    }
    return 'Never';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = _options(l10n);
    return SettingsScaffold(
      title: l10n.screenOffTimeText,
      body: SettingsScrollView(
        children: [
          const SettingsSectionHeader('Auto-Lock'),
          SettingsGroup(
            children: [
              for (final (policy, label) in options)
                SettingsOptionTile(
                  title: label(l10n),
                  selected: !_loading && _value == policy,
                  onTap: _loading ? null : () => _select(policy),
                ),
            ],
          ),
          if (!_loading)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Current: ${_summaryLabel(l10n)}',
                style: const TextStyle(color: Colors.white54),
              ),
            ),
        ],
      ),
    );
  }
}
