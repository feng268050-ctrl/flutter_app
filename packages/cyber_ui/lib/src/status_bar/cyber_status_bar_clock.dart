import 'dart:async';

import 'package:flutter/material.dart';

/// Compact status-bar clock (`HH:mm`, optional weekday + date on the left).
///
/// Polls once per second and only rebuilds when the displayed text changes
/// (minute rollover, midnight date change, or a manual wall-clock jump).
class CyberStatusBarClock extends StatefulWidget {
  const CyberStatusBarClock({
    super.key,
    this.style,
    this.now,
    this.use24HourFormat = true,
    this.showDate = false,
  });

  final TextStyle? style;

  /// Injected for tests / OS wall clock; defaults to [DateTime.now].
  final DateTime Function()? now;

  /// When false, shows 12-hour time via [TimeOfDay.format].
  final bool use24HourFormat;

  /// When true, prefixes localized weekday + month + day (e.g. `Wed Aug 5`).
  /// Quick / Engineer equipment bars keep this false (time only).
  final bool showDate;

  @override
  State<CyberStatusBarClock> createState() => _CyberStatusBarClockState();
}

class _CyberStatusBarClockState extends State<CyberStatusBarClock> {
  Timer? _timer;
  late String _text;

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  String _formatTime(DateTime t) {
    try {
      final tod = TimeOfDay.fromDateTime(t);
      return MaterialLocalizations.of(context).formatTimeOfDay(
        tod,
        alwaysUse24HourFormat: widget.use24HourFormat,
      );
    } catch (_) {
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
  }

  /// `Wed Aug 5` / localized medium date (weekday + month + day).
  String _formatDatePrefix(DateTime t) {
    try {
      // DefaultMaterialLocalizations: "Wed, Aug 5"; drop commas to match
      // product chrome ("Wed Aug 5"). Other locales usually have no comma.
      return MaterialLocalizations.of(context)
          .formatMediumDate(t)
          .replaceAll(',', '');
    } catch (_) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${weekdays[t.weekday - 1]} ${months[t.month - 1]} ${t.day}';
    }
  }

  String _format(DateTime t) {
    final time = _formatTime(t);
    if (!widget.showDate) {
      return time;
    }
    return '${_formatDatePrefix(t)} $time';
  }

  @override
  void initState() {
    super.initState();
    _text = '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _text = _format(_now));
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _onTick() {
    if (!mounted) {
      return;
    }
    final next = _format(_now);
    if (next != _text) {
      setState(() => _text = next);
    }
  }

  @override
  void didUpdateWidget(CyberStatusBarClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.now != widget.now ||
        oldWidget.use24HourFormat != widget.use24HourFormat ||
        oldWidget.showDate != widget.showDate) {
      _onTick();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _onTick();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = widget.style ??
        theme.textTheme.titleMedium?.copyWith(
          color: theme.appBarTheme.foregroundColor ??
              theme.colorScheme.onSurface,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    return Text(
      _text,
      key: const ValueKey('cyber-status-bar-clock'),
      style: style,
    );
  }
}
