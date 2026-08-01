import 'dart:async';

import 'package:flutter/material.dart';

/// Compact `HH:mm` clock for page status bars.
///
/// Polls once per second and only rebuilds when the displayed minute changes
/// (or when [now] jumps after a manual wall-clock set).
class CyberStatusBarClock extends StatefulWidget {
  const CyberStatusBarClock({
    super.key,
    this.style,
    this.now,
    this.use24HourFormat = true,
  });

  final TextStyle? style;

  /// Injected for tests / OS wall clock; defaults to [DateTime.now].
  final DateTime Function()? now;

  /// When false, shows 12-hour time via [TimeOfDay.format].
  final bool use24HourFormat;

  @override
  State<CyberStatusBarClock> createState() => _CyberStatusBarClockState();
}

class _CyberStatusBarClockState extends State<CyberStatusBarClock> {
  Timer? _timer;
  late String _text;

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  String _format(DateTime t) {
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
        oldWidget.use24HourFormat != widget.use24HourFormat) {
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
