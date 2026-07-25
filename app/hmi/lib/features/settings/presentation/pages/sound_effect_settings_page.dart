import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/application/sound_effect_scope.dart';
import 'package:lws_hmi/features/settings/application/sound_effect_store.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

class SoundEffectSettingsPage extends StatefulWidget {
  const SoundEffectSettingsPage({super.key});

  @override
  State<SoundEffectSettingsPage> createState() =>
      _SoundEffectSettingsPageState();
}

class _SoundEffectSettingsPageState extends State<SoundEffectSettingsPage> {
  int _index = SoundEffectStore.defaultIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = SoundEffectScope.maybeOf(context);
    if (scope != null) {
      _index = scope.store.index;
    }
  }

  Future<void> _select(int index) async {
    final next = SoundEffectStore.clampIndex(index);
    setState(() => _index = next);
    final scope = SoundEffectScope.maybeOf(context);
    if (scope != null) {
      await scope.clickSound.openEffect(next);
    }
    if (mounted) setState(() {});
  }

  String _label(AppLocalizations l10n, int i) => switch (i) {
        1 => l10n.soundEffectOption2,
        2 => l10n.soundEffectOption3,
        _ => l10n.soundEffectOption1,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: l10n.soundEffectCheck,
      body: SettingsScrollView(
        children: [
          SettingsGroup(
            children: [
              for (var i = 0; i < SoundEffectStore.effectCount; i++)
                SettingsOptionTile(
                  title: _label(l10n, i),
                  selected: _index == i,
                  clickSoundEnabled: false,
                  onTap: () {
                    // ignore: discarded_futures
                    _select(i);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
