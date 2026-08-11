import 'package:os_settings/ui/cyber_date_time_pickers.dart';
import 'dart:async';

import 'package:cyber_hal/datetime.dart';
import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';
import 'package:os_settings/chrome/settings_chrome.dart';





/// Date & Time hub — Automatic sync + NTP server + auto timezone + manual rows.
class DateTimePage extends StatefulWidget {
  const DateTimePage({super.key});


  @override
  State<DateTimePage> createState() => _DateTimePageState();
}

class _DateTimePageState extends State<DateTimePage> {
  TimeSyncMode _mode = TimeSyncMode.network;
  String _timezone = 'Asia/Shanghai';
  String _ntpServerId = NtpServerCatalog.defaultId;
  bool _autoTimezone = false;
  bool _use24Hour = true;
  DateTime _now = DateTime.now();
  String? _status;
  bool _busy = false;
  Timer? _tick;

  DateTimeController get _dt => OsSettingsScope.of(context).dateTime();

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
      final ntp = await _dt.getNtpServerId();
      final autoTz = await _dt.getAutoTimezone();
      final use24 = await _dt.getUse24HourFormat();
      final now = await _dt.now();
      if (!mounted) return;
      setState(() {
        _mode = mode;
        _timezone = tz.isNotEmpty ? tz : 'Asia/Shanghai';
        _ntpServerId = ntp;
        _autoTimezone = autoTz;
        _use24Hour = use24;
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
      await OsSettingsScope.of(context).wallClock.refresh();
    } catch (e) {
      if (mounted) setState(() => _status = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setAutomatic(bool enabled) async {
    await _run(() async {
      if (enabled) {
        await _dt.setSyncMode(TimeSyncMode.network);
        await _dt.syncFromNetwork();
      } else {
        await _dt.setSyncMode(TimeSyncMode.manual);
      }
    });
  }

  Future<void> _setAutoTimezone(bool enabled) async {
    const geoFailedMsg = 'Couldn’t set time zone from network location';
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final r = await _dt.setAutoTimezone(enabled);
      await _load();
      await OsSettingsScope.of(context).wallClock.refresh();
      if (enabled && !r.ok && mounted) {
        setState(() {
          _status = geoFailedMsg ??
              (r.message.isNotEmpty ? r.message : 'timezone geo lookup failed');
        });
      }
    } catch (e) {
      if (mounted) setState(() => _status = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showCyberDatePicker(
      context: context,
      title: 'Date',
      initial: _now,
      confirmLabel: 'Confirm',
      cancelLabel: 'Cancel',
    );
    if (picked == null || !mounted) return;
    final next = DateTime(
      picked.year,
      picked.month,
      picked.day,
      _now.hour,
      _now.minute,
      _now.second,
    );
    await _run(() => _dt.setWallClock(next));
  }

  Future<void> _pickTime() async {
    final picked = await showCyberTimePicker(
      context: context,
      title: 'Time',
      initial: TimeOfDay.fromDateTime(_now),
      confirmLabel: 'Confirm',
      cancelLabel: 'Cancel',
    );
    if (picked == null || !mounted) return;
    final next = DateTime(
      _now.year,
      _now.month,
      _now.day,
      picked.hour,
      picked.minute,
      0,
    );
    await _run(() => _dt.setWallClock(next));
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
      TimeDisplayFormat.formatHm(_now, use24Hour: _use24Hour);

  @override
  Widget build(BuildContext context) {
    final automatic = _mode == TimeSyncMode.network;
    final ntpPreset = NtpServerCatalog.byId(_ntpServerId) ??
        NtpServerCatalog.presets.first;
    final syncChildren = <Widget>[
      SettingsSwitchRow(
        title: 'Automatic',
        value: automatic,
        onChanged: _busy ? null : (v) => unawaited(_setAutomatic(v)),
      ),
    ];
    if (automatic) {
      syncChildren.add(
        SettingsNavRow(
          title: 'Time Server',
          value: ntpServerLabel(ntpPreset),
          onTap: _busy
              ? null
              : () => pushSettingsPage(
                    context,
                    _NtpServerPickerPage(
                      currentId: _ntpServerId,
                      presets: _dt.listNtpServerPresets(),
                      onSelected: (id) => unawaited(
                        _run(() async {
                          await _dt.setNtpServerId(id);
                          await _dt.syncFromNetwork();
                        }),
                      ),
                    ),
                  ),
        ),
      );
    }

    return SettingsScaffold(
      title: 'Date & Time',
      body: SettingsScrollView(
        children: [
          SettingsGroup(
            borderGradientCenter:
                CyberBorderGradientCenter.bottomLeftTopRight,
            children: syncChildren,
          ),
          SettingsGroup(
            borderGradientCenter:
                CyberBorderGradientCenter.topLeftBottomRight,
            children: [
              SettingsNavRow(
                title: 'Date',
                value: _dateLabel,
                onTap: automatic || _busy
                    ? null
                    : () => unawaited(_pickDate()),
              ),
              SettingsNavRow(
                title: 'Time',
                value: _timeLabel,
                onTap: automatic || _busy
                    ? null
                    : () => unawaited(_pickTime()),
              ),
              SettingsSwitchRow(
                title: 'Use 24-Hour Format',
                value: _use24Hour,
                onChanged: _busy
                    ? null
                    : (v) =>
                        unawaited(_run(() => _dt.setUse24HourFormat(v))),
              ),
            ],
          ),
          SettingsGroup(
            borderGradientCenter:
                CyberBorderGradientCenter.bottomLeftTopRight,
            children: [
              SettingsSwitchRow(
                title: 'Automatic Time Zone',
                value: _autoTimezone,
                onChanged:
                    _busy ? null : (v) => unawaited(_setAutoTimezone(v)),
              ),
              SettingsNavRow(
                title: 'Time Zone',
                value: _timezone,
                onTap: _autoTimezone || _busy
                    ? null
                    : () => pushSettingsPage(
                          context,
                          _TimezonePickerPage(
                            current: _timezone,
                            controller: _dt,
                            onSelected: (tz) => unawaited(
                              _run(() => _dt.setTimezone(tz)),
                            ),
                          ),
                        ),
              ),
            ],
          ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SettingsDimens.inset,
                SettingsDimens.helpGap,
                SettingsDimens.inset,
                SettingsDimens.inset,
              ),
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

String ntpServerLabel(NtpServerPreset preset) {
  switch (preset.labelKey) {
    case 'ntpPool':
      return 'NTP Pool';
    case 'cloudflare':
      return 'Cloudflare';
    case 'google':
      return 'Google';
    case 'aliyun':
      return 'Aliyun';
    case 'windows':
      return 'Windows';
    case 'apple':
      return 'Apple';
    case 'tencent':
      return 'Tencent';
    case 'cnPool':
      return 'China NTP Pool';
    default:
      return preset.id;
  }
}

class _NtpServerPickerPage extends StatelessWidget {
  const _NtpServerPickerPage({
    required this.currentId,
    required this.presets,
    required this.onSelected,
  });

  final String currentId;
  final List<NtpServerPreset> presets;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Time Server',
      body: SettingsScrollView(
        children: [
          SettingsGroup(
            borderGradientCenter:
                CyberBorderGradientCenter.bottomLeftTopRight,
            children: [
              for (final p in presets)
                SettingsOptionTile(
                  title: '${ntpServerLabel(p)} (${p.id})',
                  selected: p.id == currentId,
                  onTap: () {
                    onSelected(p.id);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimezonePickerPage extends StatefulWidget {
  const _TimezonePickerPage({
    required this.current,
    required this.onSelected,
    required this.controller,
  });

  final String current;
  final ValueChanged<String> onSelected;
  final DateTimeController controller;

  @override
  State<_TimezonePickerPage> createState() => _TimezonePickerPageState();
}

class _TimezonePickerPageState extends State<_TimezonePickerPage> {
  final _searchCtrl = TextEditingController();
  final _ime = CyberImeSession.shared;
  List<TimezoneEntry> _all = const [];
  List<TimezoneEntry> _filtered = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final entries = await widget.controller.listTimezoneEntries();
      if (!mounted) return;
      setState(() {
        _all = entries;
        _filtered = TimezoneCatalog.filter(entries, _searchCtrl.text);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _onSearchChanged() {
    setState(() {
      _filtered = TimezoneCatalog.filter(_all, _searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Time Zone',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SettingsDimens.inset,
              SettingsDimens.inset,
              SettingsDimens.inset,
              SettingsDimens.groupGap,
            ),
            child: CyberImeTextField(
              fieldType: CyberImeFieldType.text,
              controller: _searchCtrl,
              session: _ime,
              style: const TextStyle(color: CyberColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by name or UTC offset',
                hintStyle: const TextStyle(color: CyberColors.textSecondary),
                prefixIcon: const Icon(
                  Icons.search,
                  color: CyberColors.textSecondary,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: CyberColors.borderMid),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: CyberColors.buttonPrimaryAccent,
                  ),
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SettingsDimens.inset),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(
                    child: Text(
                      '…',
                      style: TextStyle(color: CyberColors.textSecondary),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SettingsDimens.inset,
                      0,
                      SettingsDimens.inset,
                      SettingsDimens.inset,
                    ),
                    child: SettingsPanel(
                      borderGradientCenter:
                          CyberBorderGradientCenter.topLeftBottomRight,
                      child: _filtered.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                'No Time Zones Found',
                                style: const TextStyle(
                                  color: CyberColors.textPrimary,
                                ),
                              ),
                            )
                          : ListView.separated(
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              itemCount: _filtered.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: SettingsDimens.sectionDividerHeight,
                                thickness: SettingsDimens.sectionDividerHeight,
                                indent: 20,
                                endIndent: 20,
                                color: SettingsDimens.sectionDividerColor,
                              ),
                              itemBuilder: (context, index) {
                                final e = _filtered[index];
                                return SettingsOptionTile(
                                  title: e.utcOffsetLabel.isEmpty
                                      ? e.id
                                      : '${e.id}  (${e.utcOffsetLabel})',
                                  selected: e.id == widget.current,
                                  onTap: () {
                                    widget.onSelected(e.id);
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
