import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const _kPickerDialogWidth = 568.0;
const _kDateWheelHeight = 220.0;
const _kTimeWheelHeight = 180.0;
const _kPickerItemExtent = 48.0;

const _pickerWheelStyle = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w500,
  color: CyberColors.textPrimary,
);

const _pickerSeparatorStyle = TextStyle(
  fontSize: 28,
  color: CyberColors.textPrimary,
  height: 1,
);

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
                          child: Text('${widget.firstYear + i}', style: _pickerWheelStyle),
                        ),
                    ],
                  ),
                ),
                const Text('-', style: _pickerSeparatorStyle),
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
                          child: Text(m.toString().padLeft(2, '0'), style: _pickerWheelStyle),
                        ),
                    ],
                  ),
                ),
                const Text('-', style: _pickerSeparatorStyle),
                Expanded(
                  flex: 3,
                  child: CupertinoPicker(
                    key: ValueKey('day-$dayCount'),
                    scrollController: _dayCtrl,
                    itemExtent: _kPickerItemExtent,
                    magnification: 1.08,
                    useMagnifier: true,
                    onSelectedItemChanged: (i) => setState(() => _day = i + 1),
                    children: [
                      for (var d = 1; d <= dayCount; d++)
                        Center(
                          child: Text(d.toString().padLeft(2, '0'), style: _pickerWheelStyle),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          CyberButton(
              child: Text(widget.cancelLabel),
            size: CyberButtonSize.medium,
            variant: CyberButtonVariant.secondary,
            onPressed: () => Navigator.pop(context),
          ),
          CyberButton(
              child: Text(widget.confirmLabel),
            size: CyberButtonSize.medium,
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
                          child: Text(h.toString().padLeft(2, '0'), style: _pickerWheelStyle),
                        ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(':', style: _pickerSeparatorStyle),
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
                          child: Text(m.toString().padLeft(2, '0'), style: _pickerWheelStyle),
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
          CyberButton(
              child: Text(widget.cancelLabel),
            size: CyberButtonSize.medium,
            variant: CyberButtonVariant.secondary,
            onPressed: () => Navigator.pop(context),
          ),
          CyberButton(
              child: Text(widget.confirmLabel),
            size: CyberButtonSize.medium,
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
