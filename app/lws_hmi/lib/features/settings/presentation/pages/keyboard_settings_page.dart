import 'dart:async';

import 'package:cyber_hal/input.dart';
import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app/hmi_route_restore.dart';
import 'package:lws_hmi/features/settings/application/product_keyboard_profile.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Keyboard settings: soft layout Segment + preview + physical keyboard status.
class KeyboardSettingsPage extends StatefulWidget {
  const KeyboardSettingsPage({
    super.key,
    required this.services,
    this.regionalProvider,
  });

  final AppServices services;

  /// Optional override (tests); otherwise uses [CyberImeRegionalLayoutRegistry].
  final CyberImeMutableRegionalLayoutProvider? regionalProvider;

  @override
  State<KeyboardSettingsPage> createState() => _KeyboardSettingsPageState();
}

class _KeyboardSettingsPageState extends State<KeyboardSettingsPage> {
  ProductKeyboardProfile _selected = ProductKeyboardProfile.qwerty;
  ProductKeyboardProfile _applied = ProductKeyboardProfile.qwerty;
  String _presence = '…';
  bool _busy = false;
  Timer? _poll;

  Keyboard get _keyboard => widget.services.keyboard;

  CyberImeMutableRegionalLayoutProvider? get _mutableRegional {
    final override = widget.regionalProvider;
    if (override != null) return override;
    final p = CyberImeRegionalLayoutRegistry.provider;
    return p is CyberImeMutableRegionalLayoutProvider ? p : null;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_refreshPresence());
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_refreshPresence());
    });
  }

  Future<void> _load() async {
    try {
      final layout = await _keyboard.getLayout();
      final profile = ProductKeyboardProfile.fromLayout(layout);
      if (!mounted) return;
      setState(() {
        _selected = profile;
        _applied = profile;
      });
    } catch (e) {
      debugPrint('keyboard settings: load failed: $e');
    }
  }

  Future<void> _refreshPresence() async {
    try {
      final line = await const UsbHidKeyboardProbe().statusLine();
      if (!mounted) return;
      setState(() => _presence = line ?? 'Not detected');
    } catch (_) {
      if (!mounted) return;
      setState(() => _presence = 'Not detected');
    }
  }

  Future<void> _apply() async {
    if (_busy) return;
    final confirmed = await showCyberDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Apply keyboard layout?',
              style: TextStyle(
                fontSize: 20,
                color: CyberColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Saves the selected layout and restarts HMI so soft CyberIME and '
              'physical keyboard both take effect. This page will reopen after '
              'relaunch.',
              style: TextStyle(color: CyberColors.textSecondary),
            ),
            const SizedBox(height: 20),
            CyberButton(
              variant: CyberButtonVariant.primary,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.confirmText),
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
      _mutableRegional?.profile = _selected.imeProfile;
      await HmiRouteRestore.write(HmiRouteRestore.settingsKeyboard);
      await _keyboard.restartToApply();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Apply failed: $e')),
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
            bottomInset: SettingsDimens.helpGap,
            borderGradientCenter: CyberBorderGradientCenter.topLeftBottomRight,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CyberImeLayoutChooser(
                  selected: _selected.imeProfile,
                  enabled: !_busy,
                  showPreview: false,
                  showFootnote: false,
                  onSelected: (p) {
                    CyberClickSoundRegistry.playClick();
                    setState(() {
                      _selected = ProductKeyboardProfile.fromConfProfile(
                        p.confId,
                      );
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: CyberButton(
                    size: CyberButtonSize.small,
                    variant: CyberButtonVariant.primary,
                    onPressed:
                        (_busy || !dirty) ? null : () => unawaited(_apply()),
                    child: const Text('Apply'),
                  ),
                ),
              ),
            ],
          ),
          _KeyboardLayoutPreviewSection(profile: _selected.imeProfile),
          const SettingsHelpFooter(
            'Attach a physical keyboard that matches the selected '
            'specification. A mismatch may make some keys produce unexpected '
            'characters.',
            bottomInset: 0,
          ),
          const SettingsSectionHeader('Physical Keyboard'),
          SettingsGroup(
            borderGradientCenter: CyberBorderGradientCenter.bottomLeftTopRight,
            children: [
              SettingsValueRow(
                title: 'Status',
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
  });

  final CyberImeRegionalProfile profile;

  String get _footnote {
    return switch (profile) {
      CyberImeRegionalProfile.qwertz ||
      CyberImeRegionalProfile.azerty =>
        '长按可输入重音字符',
      CyberImeRegionalProfile.qwerty => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final footnote = _footnote;
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
          CyberImeLayoutPreviewCard(profile: profile),
          if (footnote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                footnote,
                style: const TextStyle(
                  color: Color(0x8CFFFFFF),
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
