import 'dart:async';

import 'package:cyber_hal/datetime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';

/// Date & Time hub — phone-style automatic + date/time/zone rows.
class DateTimeSettingsPage extends StatefulWidget {
  const DateTimeSettingsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<DateTimeSettingsPage> createState() => _DateTimeSettingsPageState();
}

class _DateTimeSettingsPageState extends State<DateTimeSettingsPage> {
  TimeSyncMode _mode = TimeSyncMode.network;
  String _timezone = 'Asia/Shanghai';
  DateTime _now = DateTime.now();
  String? _status;
  bool _busy = false;
  Timer? _tick;

  DateTimeController get _dt => widget.services.dateTime;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_refreshNow());
    });
  }

  Future<void> _load() async {
    try {
      final mode = await _dt.getSyncMode();
      final tz = await _dt.getTimezone();
      final now = await _dt.now();
      if (!mounted) return;
      setState(() {
        _mode = mode;
        _timezone = TimeSyncPrefs.curatedTimezones.contains(tz)
            ? tz
            : 'Asia/Shanghai';
        _now = now;
      });
    } catch (e) {
      if (mounted) setState(() => _status = '$e');
    }
  }

  Future<void> _refreshNow() async {
    try {
      final now = await _dt.now();
      if (mounted) setState(() => _now = now);
    } catch (_) {}
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await fn();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _status = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String get _dateLabel =>
      '${_now.year.toString().padLeft(4, '0')}-'
      '${_now.month.toString().padLeft(2, '0')}-'
      '${_now.day.toString().padLeft(2, '0')}';

  String get _timeLabel =>
      '${_now.hour.toString().padLeft(2, '0')}:'
      '${_now.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final automatic = _mode == TimeSyncMode.network;
    return SettingsScaffold(
      title: 'Date & Time',
      body: SettingsScrollView(
        children: [
          const SettingsSectionHeader('Date & Time'),
          SettingsGroup(
            children: [
              SettingsSwitchRow(
                title: 'Set Automatically',
                value: automatic,
                onChanged: _busy
                    ? null
                    : (v) => unawaited(
                          _run(
                            () => _dt.setSyncMode(
                              v ? TimeSyncMode.network : TimeSyncMode.manual,
                            ),
                          ),
                        ),
              ),
              SettingsNavRow(
                title: 'Date',
                value: _dateLabel,
                onTap: automatic || _busy
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _now,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked == null) return;
                        final next = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          _now.hour,
                          _now.minute,
                          _now.second,
                        );
                        await _run(() => _dt.setWallClock(next));
                      },
              ),
              SettingsNavRow(
                title: 'Time',
                value: _timeLabel,
                onTap: automatic || _busy
                    ? null
                    : () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_now),
                        );
                        if (picked == null) return;
                        final next = DateTime(
                          _now.year,
                          _now.month,
                          _now.day,
                          picked.hour,
                          picked.minute,
                          _now.second,
                        );
                        await _run(() => _dt.setWallClock(next));
                      },
              ),
              SettingsNavRow(
                title: 'Time Zone',
                value: _timezone,
                onTap: _busy
                    ? null
                    : () => pushSettingsPage(
                          context,
                          _TimezonePickerPage(
                            current: _timezone,
                            onSelected: (tz) => unawaited(
                              _run(() => _dt.setTimezone(tz)),
                            ),
                          ),
                        ),
              ),
            ],
          ),
          if (!automatic)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : () {
                        CyberClickSoundRegistry.playClick();
                        unawaited(_run(() => _dt.syncFromNetwork()));
                      },
                child: const Text('Sync Now'),
              ),
            ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _status!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimezonePickerPage extends StatelessWidget {
  const _TimezonePickerPage({
    required this.current,
    required this.onSelected,
  });

  final String current;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final zones = TimeSyncPrefs.curatedTimezones;
    return SettingsScaffold(
      title: 'Time Zone',
      body: SettingsScrollView(
        children: [
          SettingsGroup(
            children: [
              for (final tz in zones)
                SettingsOptionTile(
                  title: tz,
                  selected: tz == current,
                  onTap: () {
                    onSelected(tz);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
