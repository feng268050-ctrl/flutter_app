import 'dart:async';

import 'package:cyber_hal/input.dart';
import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';
import 'package:os_settings/chrome/settings_chrome.dart';
import 'package:os_settings/l10n/app_localizations.dart';
import 'package:os_settings/util/keyboard_profile.dart';

/// Keyboard — soft layout Segment + Apply (os-settings seat only).
class KeyboardPage extends StatefulWidget {
  const KeyboardPage({super.key});

  @override
  State<KeyboardPage> createState() => _KeyboardPageState();
}

class _KeyboardPageState extends State<KeyboardPage> {
  KeyboardProfile _selected = KeyboardProfile.qwerty;
  KeyboardProfile _applied = KeyboardProfile.qwerty;
  String _presence = '…';
  bool _busy = false;
  Timer? _poll;

  Keyboard get _keyboard => OsSettingsScope.of(context).keyboard();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
      unawaited(_refreshPresence());
    });
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_refreshPresence());
    });
  }

  Future<void> _load() async {
    try {
      final layout = await _keyboard.getLayout();
      final profile = KeyboardProfile.fromLayout(layout);
      if (!mounted) return;
      setState(() {
        _selected = profile;
        _applied = profile;
      });
    } catch (e) {
      debugPrint('keyboard: load failed: $e');
    }
  }

  Future<void> _refreshPresence() async {
    final l10n = AppLocalizations.of(context);
    final notDetected = l10n?.keyboardNotDetected ?? 'Not detected';
    try {
      final line = await const UsbHidKeyboardProbe().statusLine();
      if (!mounted) return;
      setState(() => _presence = line ?? notDetected);
    } catch (_) {
      if (!mounted) return;
      setState(() => _presence = notDetected);
    }
  }

  Future<void> _apply() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showCyberDialog<bool>(
      context: context,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.keyboardApplyConfirmTitle,
              style: SettingsTextStyles.title.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.keyboardApplyConfirmOsBody,
              style: SettingsTextStyles.supporting,
            ),
            const SizedBox(height: 20),
            CyberButton(
              variant: CyberButtonVariant.primary,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.wifiApply),
            ),
            const SizedBox(height: 8),
            CyberButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancelText),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _keyboard.setLayout(_selected.xkbLayout, restart: false);
      final regional = CyberImeRegionalLayoutRegistry.provider;
      if (regional is CyberImeMutableRegionalLayoutProvider) {
        regional.profile = _selected.imeProfile;
      }
      await _keyboard.restartToApply();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.wifiApply}: $e')),
        );
        setState(() => _busy = false);
      }
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dirty = _selected != _applied;
    return SettingsScaffold(
      title: l10n.keyboardText,
      body: SettingsScrollView(
        children: [
          SettingsGroup(
            bottomInset: SettingsDimens.inset,
            borderGradientCenter: CyberBorderGradientCenter.topLeftBottomRight,
            children: [
              CyberImeLayoutChooser(
                selected: _selected.imeProfile,
                enabled: !_busy,
                showDisplayName: false,
                showPreview: false,
                showFootnote: false,
                segmentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                onSelected: (p) {
                  CyberClickSoundRegistry.playClick();
                  setState(() {
                    _selected = KeyboardProfile.fromConfProfile(p.confId);
                  });
                },
              ),
            ],
          ),
          _KeyboardLayoutPreviewSection(
            profile: _selected.imeProfile,
            previewCaption: l10n.previewLabel,
            applyLabel: l10n.wifiApply,
            applyEnabled: !_busy && dirty,
            onApply: () => unawaited(_apply()),
          ),
          SettingsHelpFooter(
            l10n.keyboardLayoutHelpOs,
            bottomInset: 0,
          ),
          SettingsSectionHeader(l10n.keyboardPhysicalSection),
          SettingsGroup(
            bottomInset: 0,
            borderGradientCenter: CyberBorderGradientCenter.bottomLeftTopRight,
            children: [
              SettingsValueRow(
                title: l10n.cameraStatus,
                value: _presence,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeyboardLayoutPreviewSection extends StatelessWidget {
  const _KeyboardLayoutPreviewSection({
    required this.profile,
    required this.previewCaption,
    required this.applyLabel,
    required this.applyEnabled,
    required this.onApply,
  });

  final CyberImeRegionalProfile profile;
  final String previewCaption;
  final String applyLabel;
  final bool applyEnabled;
  final VoidCallback onApply;

  String _footnote(AppLocalizations l10n) => switch (profile) {
        CyberImeRegionalProfile.qwertz ||
        CyberImeRegionalProfile.azerty =>
          l10n.keyboardLongPressAccentHint,
        CyberImeRegionalProfile.qwerty => '',
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final footnote = _footnote(l10n);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SettingsDimens.inset,
        0,
        SettingsDimens.inset,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  previewCaption,
                  style: SettingsTextStyles.supporting.copyWith(
                    color: Colors.white54,
                  ),
                ),
              ),
              CyberButton(
                variant: CyberButtonVariant.primary,
                onPressed: applyEnabled ? onApply : null,
                child: Text(applyLabel),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CyberImeLayoutPreviewCard(
            profile: profile,
            previewCaption: '',
            captionStyle: SettingsTextStyles.supporting.copyWith(
              color: Colors.white54,
            ),
          ),
          if (footnote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                footnote,
                style: SettingsTextStyles.supporting.copyWith(
                  color: Colors.white54,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
