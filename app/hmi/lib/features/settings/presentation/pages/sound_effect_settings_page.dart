import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/application/sound_effect_scope.dart';
import 'package:lws_hmi/features/settings/application/sound_effect_store.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';

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

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Sound Effect',
      body: SettingsScrollView(
        children: [
          const SettingsSectionHeader('Click Sound'),
          SettingsGroup(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: CyberSegmentedControl<int>(
                  segments: [
                    for (var i = 0; i < SoundEffectStore.effectCount; i++)
                      ButtonSegment<int>(
                        value: i,
                        label: Text(SoundEffectStore.labels[i]),
                      ),
                  ],
                  selected: {_index},
                  // openEffect already previews; avoid double click from segment.
                  clickSoundEnabled: false,
                  onSelectionChanged: (s) {
                    if (s.isEmpty) return;
                    // ignore: discarded_futures
                    _select(s.first);
                  },
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Persisted under /var/lib/hmi/sound.conf (`button_feedback=`) (asset key). '
              'Home and Cyber controls use the selected click sample.',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}
