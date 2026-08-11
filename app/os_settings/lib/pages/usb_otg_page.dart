import 'dart:async';

import 'package:cyber_hal/usb_otg.dart';
import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';
import 'package:os_settings/chrome/settings_chrome.dart';

/// USB OTG — debug / mtp / host mode.
class UsbOtgPage extends StatefulWidget {
  const UsbOtgPage({super.key});

  @override
  State<UsbOtgPage> createState() => _UsbOtgPageState();
}

class _UsbOtgPageState extends State<UsbOtgPage> {
  UsbOtgMode _mode = UsbOtgMode.debug;
  List<UsbOtgMode> _choices = const [
    UsbOtgMode.debug,
    UsbOtgMode.mtp,
    UsbOtgMode.host,
  ];
  bool _ready = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    try {
      final otg = OsSettingsScope.of(context).usbOtg();
      final mode = await otg.getMode();
      final choices = await otg.pickerModes();
      if (!mounted) return;
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

  String _label(UsbOtgMode m) => switch (m) {
        UsbOtgMode.debug => 'USB Debug',
        UsbOtgMode.mtp => 'MTP',
        UsbOtgMode.host => 'Host',
      };

  String _description(UsbOtgMode m) => switch (m) {
        UsbOtgMode.debug =>
          'Expose USB gadget for SSH / ADB-style debugging.',
        UsbOtgMode.mtp => 'Present storage to a host PC over MTP.',
        UsbOtgMode.host => 'Act as USB host for peripherals.',
      };

  Future<void> _setMode(UsbOtgMode mode) async {
    if (_busy || mode == _mode) return;
    setState(() {
      _busy = true;
      _error = null;
      _mode = mode;
    });
    try {
      await OsSettingsScope.of(context).usbOtg().setMode(mode);
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
        await _load();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _choices.length <= 1;
    return SettingsScaffold(
      title: 'USB OTG',
      body: SettingsScrollView(
        children: [
          if (!_ready)
            const SettingsHelpFooter('Loading…')
          else ...[
            SettingsGroup(
              bottomInset: 0,
              children: [
                for (final m in _choices)
                  SettingsOptionTile(
                    title: _label(m),
                    selected: _mode == m,
                    onTap: (_busy || (locked && m != _mode))
                        ? null
                        : () => unawaited(_setMode(m)),
                  ),
              ],
            ),
            SettingsHelpFooter(
              locked
                  ? 'Only USB Debug is available on this build. MTP and Host '
                      'modes are disabled.'
                  : _description(_mode),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SettingsDimens.inset,
                0,
                SettingsDimens.inset,
                SettingsDimens.inset,
              ),
              child: Text(
                _error!,
                style: SettingsTextStyles.supporting.copyWith(
                  color: Colors.redAccent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
