import 'dart:async';

import 'package:cyber_hal/input.dart';
import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app/hmi_route_restore.dart';
import 'package:lws_hmi/features/settings/application/product_keyboard_profile.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';

/// Product Keyboard settings: Segment + preview + Apply / Restart.
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
      setState(() => _presence = line);
    } catch (_) {
      if (!mounted) return;
      setState(() => _presence = 'probe unavailable');
    }
  }

  void _onSegment(ProductKeyboardProfile profile) {
    setState(() => _selected = profile);
  }

  Future<void> _apply() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _keyboard.setLayout(_selected.xkbLayout, restart: false);
      _mutableRegional?.profile = _selected.imeProfile;
      if (!mounted) return;
      setState(() => _applied = _selected);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Applied ${_selected.displayName}. '
            'Soft keyboard updated. Tap Restart for physical XKB.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Apply failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restart() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restart HMI?'),
        content: const Text(
          'Physical keyboard layout (XKB) is applied when HMI restarts. '
          'This page will reopen after relaunch.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      // Ensure preference matches the selection before restart.
      if (_selected != _applied) {
        await _keyboard.setLayout(_selected.xkbLayout, restart: false);
        _mutableRegional?.profile = _selected.imeProfile;
        _applied = _selected;
      }
      await HmiRouteRestore.write(HmiRouteRestore.settingsKeyboard);
      await _keyboard.restartToApply();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restart failed: $e')),
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
    return SettingsScaffold(
      title: 'Keyboard',
      body: SettingsScrollView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
        children: [
          const SettingsSectionHeader('Layout'),
          CyberImeLayoutChooser(
            selected: _selected.imeProfile,
            enabled: !_busy,
            onSelected: (p) {
              final match = ProductKeyboardProfile.values.firstWhere(
                (e) => e.imeProfile == p,
              );
              _onSegment(match);
            },
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Attach a physical keyboard that matches the selected '
              'specification. A mismatch may make some keys produce unexpected '
              'characters. Soft CyberIME follows Apply immediately; physical '
              'XKB needs Restart.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: CyberButton(
                    onPressed: _busy ? null : () => unawaited(_apply()),
                    variant: CyberButtonVariant.secondary,
                    child: const Text('Apply'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CyberButton(
                    onPressed: _busy ? null : () => unawaited(_restart()),
                    child: const Text('Restart'),
                  ),
                ),
              ],
            ),
          ),
          const SettingsSectionHeader('HID'),
          SettingsGroup(
            children: [
              ListTile(
                title: const Text('Presence'),
                subtitle: Text(_presence),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
