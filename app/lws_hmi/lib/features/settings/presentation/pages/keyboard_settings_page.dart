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

/// Keyboard settings: Layout (dropdown + Preview/Apply) + physical keyboard list.
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
  ProductKeyboardProfile _selected = ProductKeyboardProfile.defaultSoft;
  ProductKeyboardProfile _applied = ProductKeyboardProfile.defaultSoft;
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
          // Layout (no section header — title is on the row)
          SettingsGroup(
            borderGradientCenter: CyberBorderGradientCenter.topLeftBottomRight,
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                title: const Text(
                  'Layout',
                  style: TextStyle(
                    fontSize: 18,
                    color: CyberColors.textPrimary,
                  ),
                ),
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<ProductKeyboardProfile>(
                    value: _selected,
                    dropdownColor: CyberColors.fillSolidMid,
                    style: const TextStyle(
                      fontSize: 18,
                      color: CyberColors.textPrimary,
                    ),
                    items: [
                      for (final p in ProductKeyboardProfile.values)
                        DropdownMenuItem(
                          value: p,
                          child: Text(p.displayName),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) {
                            if (v == null) return;
                            CyberClickSoundRegistry.playClick();
                            setState(() => _selected = v);
                          },
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SettingsDimens.inset,
              8,
              SettingsDimens.inset,
              0,
            ),
            child: Row(
              children: [
                const Text(
                  'Preview',
                  style: TextStyle(
                    fontSize: 18,
                    color: CyberColors.textPrimary,
                  ),
                ),
                const Spacer(),
                CyberButton(
                  size: CyberButtonSize.small,
                  variant: CyberButtonVariant.primary,
                  onPressed: (_busy || !dirty) ? null : () => unawaited(_apply()),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SettingsDimens.inset,
              8,
              SettingsDimens.inset,
              0,
            ),
            child: CyberCard(
              child: CyberImeLayoutPreview(profile: _selected.imeProfile),
            ),
          ),
          const SettingsHelpFooter(
            'Attach a physical keyboard that matches the selected '
            'specification. A mismatch may make some keys produce unexpected '
            'characters.',
            bottomInset: 0,
          ),
          // Physical keyboard
          const SettingsSectionHeader('Physical Keyboard'),
          SettingsGroup(
            borderGradientCenter:
                CyberBorderGradientCenter.bottomLeftTopRight,
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
