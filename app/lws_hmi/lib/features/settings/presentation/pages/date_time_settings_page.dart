import 'dart:async';

import 'package:cyber_hal/datetime.dart';
import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';

/// Date & Time hub — Automatic sync + NTP server + auto timezone + manual rows.
class DateTimeSettingsPage extends StatefulWidget {
  const DateTimeSettingsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<DateTimeSettingsPage> createState() => _DateTimeSettingsPageState();
}

class _DateTimeSettingsPageState extends State<DateTimeSettingsPage> {
  TimeSyncMode _mode = TimeSyncMode.network;
  String _timezone = 'Asia/Shanghai';
  String _ntpServerId = NtpServerCatalog.defaultId;
  bool _autoTimezone = false;
  bool _use24Hour = true;
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
      await widget.services.wallClock.refresh();
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
    final geoFailedMsg =
        AppLocalizations.of(context)?.dateTimeTimezoneGeoFailed;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final r = await _dt.setAutoTimezone(enabled);
      await _load();
      await widget.services.wallClock.refresh();
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

  Future<void> _pickDate(AppLocalizations l10n) async {
    final picked = await showCyberDatePicker(
      context: context,
      title: l10n.dateTimeSetDate,
      initial: _now,
      confirmLabel: l10n.confirmText,
      cancelLabel: l10n.cancelText,
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

  Future<void> _pickTime(AppLocalizations l10n) async {
    final picked = await showCyberTimePicker(
      context: context,
      title: l10n.dateTimeSetTime,
      initial: TimeOfDay.fromDateTime(_now),
      confirmLabel: l10n.confirmText,
      cancelLabel: l10n.cancelText,
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
    final l10n = AppLocalizations.of(context)!;
    final automatic = _mode == TimeSyncMode.network;
    final ntpPreset = NtpServerCatalog.byId(_ntpServerId) ??
        NtpServerCatalog.presets.first;
    final syncChildren = <Widget>[
      SettingsSwitchRow(
        title: l10n.dateTimeAutomatic,
        value: automatic,
        onChanged: _busy ? null : (v) => unawaited(_setAutomatic(v)),
      ),
    ];
    if (automatic) {
      syncChildren.add(
        SettingsNavRow(
          title: l10n.dateTimeNtpServer,
          value: ntpServerLabel(l10n, ntpPreset),
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
      title: l10n.dateTimeSettings,
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
                title: l10n.dateTimeSetDate,
                value: _dateLabel,
                onTap: automatic || _busy
                    ? null
                    : () => unawaited(_pickDate(l10n)),
              ),
              SettingsNavRow(
                title: l10n.dateTimeSetTime,
                value: _timeLabel,
                onTap: automatic || _busy
                    ? null
                    : () => unawaited(_pickTime(l10n)),
              ),
              SettingsSwitchRow(
                title: l10n.dateTimeUse24HourFormat,
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
                title: l10n.dateTimeAutoTimeZone,
                value: _autoTimezone,
                onChanged:
                    _busy ? null : (v) => unawaited(_setAutoTimezone(v)),
              ),
              SettingsNavRow(
                title: l10n.dateTimeSetTimeZone,
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

String ntpServerLabel(AppLocalizations l10n, NtpServerPreset preset) {
  switch (preset.labelKey) {
    case 'ntpPool':
      return l10n.dateTimeNtpPool;
    case 'cloudflare':
      return l10n.dateTimeNtpCloudflare;
    case 'google':
      return l10n.dateTimeNtpGoogle;
    case 'aliyun':
      return l10n.dateTimeNtpAliyun;
    case 'windows':
      return l10n.dateTimeNtpWindows;
    case 'apple':
      return l10n.dateTimeNtpApple;
    case 'tencent':
      return l10n.dateTimeNtpTencent;
    case 'cnPool':
      return l10n.dateTimeNtpCnPool;
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
    final l10n = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: l10n.dateTimeNtpServer,
      body: SettingsScrollView(
        children: [
          SettingsGroup(
            borderGradientCenter:
                CyberBorderGradientCenter.bottomLeftTopRight,
            children: [
              for (final p in presets)
                SettingsOptionTile(
                  title: '${ntpServerLabel(l10n, p)} (${p.id})',
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
    final l10n = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: l10n.dateTimeSetTimeZone,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SettingsDimens.inset,
              SettingsDimens.inset,
              SettingsDimens.inset,
              SettingsDimens.helpGap,
            ),
            child: CyberImeTextField(
              fieldType: CyberImeFieldType.text,
              controller: _searchCtrl,
              session: _ime,
              style: context.hmiTypography.body.copyWith(
                color: CyberColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: l10n.timezoneSearchHint,
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
                                AppLocalizations.of(context)
                                        ?.noTimeZonesFound ??
                                    'No Time Zones Found',
                                style: context.hmiTypography.body.copyWith(
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

// --- Cyber date / time pickers (lws-ui frost NumberPicker parity) ---

/// Dialog width matching lws-ui `frost_dialog_date_picker_width` (568dp).
const _kPickerDialogWidth = 568.0;
const _kDateWheelHeight = 220.0;
const _kTimeWheelHeight = 180.0;
const _kPickerItemExtent = 48.0;

Future<DateTime?> showCyberDatePicker({
  required BuildContext context,
  required String title,
  required DateTime initial,
  required String confirmLabel,
  required String cancelLabel,
  int firstYear = 2000,
  int lastYear = 2099,
}) {
  return showCyberDialog<DateTime>(
    context: context,
    builder: (ctx) => _CyberDatePickerBody(
      title: title,
      initial: initial,
      firstYear: firstYear,
      lastYear: lastYear,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
  );
}

Future<TimeOfDay?> showCyberTimePicker({
  required BuildContext context,
  required String title,
  required TimeOfDay initial,
  required String confirmLabel,
  required String cancelLabel,
}) {
  return showCyberDialog<TimeOfDay>(
    context: context,
    builder: (ctx) => _CyberTimePickerBody(
      title: title,
      initial: initial,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
  );
}

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

class _CyberDatePickerBody extends StatefulWidget {
  const _CyberDatePickerBody({
    required this.title,
    required this.initial,
    required this.firstYear,
    required this.lastYear,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final DateTime initial;
  final int firstYear;
  final int lastYear;
  final String confirmLabel;
  final String cancelLabel;

  @override
  State<_CyberDatePickerBody> createState() => _CyberDatePickerBodyState();
}

class _CyberDatePickerBodyState extends State<_CyberDatePickerBody> {
  late int _year;
  late int _month;
  late int _day;
  late FixedExtentScrollController _yearCtrl;
  late FixedExtentScrollController _monthCtrl;
  late FixedExtentScrollController _dayCtrl;

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year.clamp(widget.firstYear, widget.lastYear);
    _month = widget.initial.month.clamp(1, 12);
    _day = widget.initial.day.clamp(1, _daysInMonth(_year, _month));
    _yearCtrl = FixedExtentScrollController(initialItem: _year - widget.firstYear);
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  void _clampDay() {
    final maxDay = _daysInMonth(_year, _month);
    if (_day <= maxDay) return;
    _day = maxDay;
    _dayCtrl.dispose();
    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
  }

  @override
  Widget build(BuildContext context) {
    final yearCount = widget.lastYear - widget.firstYear + 1;
    final dayCount = _daysInMonth(_year, _month);
    final pickerWheelStyle = context.hmiTypography.dialogTitle.copyWith(
      fontWeight: FontWeight.w500,
      color: CyberColors.textPrimary,
    );
    final pickerSeparatorStyle = context.hmiTypography.displayAction.copyWith(
      color: CyberColors.textPrimary,
      height: 1,
    );
    return SizedBox(
      width: _kPickerDialogWidth,
      child: CyberPromptContent(
        title: widget.title,
        body: SizedBox(
          height: _kDateWheelHeight,
          child: CupertinoTheme(
            data: const CupertinoThemeData(brightness: Brightness.dark),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: CupertinoPicker(
                    scrollController: _yearCtrl,
                    itemExtent: _kPickerItemExtent,
                    magnification: 1.08,
                    useMagnifier: true,
                    onSelectedItemChanged: (i) {
                      setState(() {
                        _year = widget.firstYear + i;
                        _clampDay();
                      });
                    },
                    children: [
                      for (var i = 0; i < yearCount; i++)
                        Center(
                          child: Text(
                            '${widget.firstYear + i}',
                            style: pickerWheelStyle,
                          ),
                        ),
                    ],
                  ),
                ),
                Text('-', style: pickerSeparatorStyle),
                Expanded(
                  flex: 3,
                  child: CupertinoPicker(
                    scrollController: _monthCtrl,
                    itemExtent: _kPickerItemExtent,
                    magnification: 1.08,
                    useMagnifier: true,
                    onSelectedItemChanged: (i) {
                      setState(() {
                        _month = i + 1;
                        _clampDay();
                      });
                    },
                    children: [
                      for (var m = 1; m <= 12; m++)
                        Center(
                          child: Text(
                            m.toString().padLeft(2, '0'),
                            style: pickerWheelStyle,
                          ),
                        ),
                    ],
                  ),
                ),
                Text('-', style: pickerSeparatorStyle),
                Expanded(
                  flex: 3,
                  child: CupertinoPicker(
                    key: ValueKey('day-$dayCount'),
                    scrollController: _dayCtrl,
                    itemExtent: _kPickerItemExtent,
                    magnification: 1.08,
                    useMagnifier: true,
                    onSelectedItemChanged: (i) {
                      setState(() => _day = i + 1);
                    },
                    children: [
                      for (var d = 1; d <= dayCount; d++)
                        Center(
                          child: Text(
                            d.toString().padLeft(2, '0'),
                            style: pickerWheelStyle,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          HmiButton(
            label: widget.cancelLabel,
            size: HmiButtonSize.medium,
            variant: CyberButtonVariant.secondary,
            onPressed: () => Navigator.pop(context),
          ),
          HmiButton(
            label: widget.confirmLabel,
            size: HmiButtonSize.medium,
            variant: CyberButtonVariant.primary,
            onPressed: () {
              Navigator.pop(context, DateTime(_year, _month, _day));
            },
          ),
        ],
      ),
    );
  }
}

class _CyberTimePickerBody extends StatefulWidget {
  const _CyberTimePickerBody({
    required this.title,
    required this.initial,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final TimeOfDay initial;
  final String confirmLabel;
  final String cancelLabel;

  @override
  State<_CyberTimePickerBody> createState() => _CyberTimePickerBodyState();
}

class _CyberTimePickerBodyState extends State<_CyberTimePickerBody> {
  late int _hour;
  late int _minute;
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;

  @override
  void initState() {
    super.initState();
    _hour = widget.initial.hour.clamp(0, 23);
    _minute = widget.initial.minute.clamp(0, 59);
    _hourCtrl = FixedExtentScrollController(initialItem: _hour);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pickerWheelStyle = context.hmiTypography.dialogTitle.copyWith(
      fontWeight: FontWeight.w500,
      color: CyberColors.textPrimary,
    );
    final pickerSeparatorStyle = context.hmiTypography.criticalTitle.copyWith(
      color: CyberColors.textPrimary,
      height: 1,
    );
    return SizedBox(
      width: _kPickerDialogWidth,
      child: CyberPromptContent(
        title: widget.title,
        body: SizedBox(
          height: _kTimeWheelHeight,
          child: CupertinoTheme(
            data: const CupertinoThemeData(brightness: Brightness.dark),
            child: Row(
              children: [
                const Spacer(flex: 2),
                Expanded(
                  flex: 3,
                  child: CupertinoPicker(
                    scrollController: _hourCtrl,
                    itemExtent: _kPickerItemExtent,
                    magnification: 1.08,
                    useMagnifier: true,
                    onSelectedItemChanged: (i) => setState(() => _hour = i),
                    children: [
                      for (var h = 0; h < 24; h++)
                        Center(
                          child: Text(
                            h.toString().padLeft(2, '0'),
                            style: pickerWheelStyle,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    ':',
                    style: pickerSeparatorStyle,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: CupertinoPicker(
                    scrollController: _minuteCtrl,
                    itemExtent: _kPickerItemExtent,
                    magnification: 1.08,
                    useMagnifier: true,
                    onSelectedItemChanged: (i) => setState(() => _minute = i),
                    children: [
                      for (var m = 0; m < 60; m++)
                        Center(
                          child: Text(
                            m.toString().padLeft(2, '0'),
                            style: pickerWheelStyle,
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
        actions: [
          HmiButton(
            label: widget.cancelLabel,
            size: HmiButtonSize.medium,
            variant: CyberButtonVariant.secondary,
            onPressed: () => Navigator.pop(context),
          ),
          HmiButton(
            label: widget.confirmLabel,
            size: HmiButtonSize.medium,
            variant: CyberButtonVariant.primary,
            onPressed: () {
              Navigator.pop(context, TimeOfDay(hour: _hour, minute: _minute));
            },
          ),
        ],
      ),
    );
  }
}
