import 'dart:async';

import 'package:cyber_hal/usb_otg.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Common Settings → Input → USB OTG: persist + apply Micro-USB mode.
class UsbOtgSettingsPage extends StatefulWidget {
  const UsbOtgSettingsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<UsbOtgSettingsPage> createState() => _UsbOtgSettingsPageState();
}

class _UsbOtgSettingsPageState extends State<UsbOtgSettingsPage> {
  UsbOtgMode _mode = UsbOtgMode.debug;
  List<UsbOtgMode> _choices = const [
    UsbOtgMode.debug,
    UsbOtgMode.mtp,
    UsbOtgMode.host,
  ];
  bool _ready = false;
  bool _busy = false;
  String? _error;

  UsbOtg get _otg => widget.services.usbOtg;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final mode = await _otg.getMode();
      final choices = await _otg.pickerModes();
      if (!mounted) {
        return;
      }
      setState(() {
        _mode = mode;
        _choices = choices.isEmpty ? const [UsbOtgMode.debug] : choices;
        _ready = true;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _ready = true;
          _error = '$e';
        });
      }
    }
  }

  String _label(AppLocalizations l10n, UsbOtgMode m) => switch (m) {
        UsbOtgMode.debug => l10n.usbOtgModeDebug,
        UsbOtgMode.mtp => l10n.usbOtgModeMtp,
        UsbOtgMode.host => l10n.usbOtgModeHost,
      };

  /// Plain-language help for the selected mode (ordinary operators).
  String _description(UsbOtgMode m) => switch (m) {
        UsbOtgMode.debug =>
          'Connect this machine to a computer with a USB cable for remote '
              'support and software updates. Keep this mode when a technician '
              'needs to work on the device from a PC.',
        UsbOtgMode.mtp =>
          'Connect this machine to a computer to copy photos and files back '
              'and forth. On the computer it appears as a device named '
              '“LWS Storage”.',
        UsbOtgMode.host =>
          'Plug in a USB keyboard, mouse, or other accessories with a USB '
              'adapter. Use this when you need extra input devices on the '
              'machine itself.',
      };

  Future<void> _setMode(UsbOtgMode mode) async {
    if (_busy || mode == _mode) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _mode = mode;
    });
    try {
      await _otg.setMode(mode);
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
        await _load();
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locked = _choices.length <= 1;
    return SettingsScaffold(
      title: l10n.usbOtgText,
      body: SettingsScrollView(
        children: [
          if (!_ready)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                l10n.loadingText,
                style: const TextStyle(color: Colors.white54),
              ),
            )
          else ...[
            SettingsGroup(
              children: [
                for (final m in _choices)
                  SettingsOptionTile(
                    title: _label(l10n, m),
                    selected: _mode == m,
                    onTap: (_busy || (locked && m != _mode))
                        ? null
                        : () => unawaited(_setMode(m)),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                locked
                    ? 'This product only supports Debug over USB. The mode '
                        'cannot be changed.'
                    : _description(_mode),
                style: const TextStyle(color: Colors.white54, height: 1.35),
              ),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}
