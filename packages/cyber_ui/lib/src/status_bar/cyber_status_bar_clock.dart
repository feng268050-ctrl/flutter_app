import 'dart:async';

import 'package:flutter/material.dart';

/// Compact minute-resolution `HH:mm` clock for page status bars.
class CyberStatusBarClock extends StatefulWidget {
  const CyberStatusBarClock({
    super.key,
    this.style,
    this.now,
  });

  final TextStyle? style;

  /// Injected for tests; defaults to [DateTime.now].
  final DateTime Function()? now;

  @override
  State<CyberStatusBarClock> createState() => _CyberStatusBarClockState();
}

class _CyberStatusBarClockState extends State<CyberStatusBarClock> {
  Timer? _timer;
  late String _text;

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  static String _format(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  void initState() {
    super.initState();
    _text = _format(_now);
    _scheduleNextTick();
  }

  void _scheduleNextTick() {
    _timer?.cancel();
    final now = _now;
    final next = DateTime(now.year, now.month, now.day, now.hour, now.minute)
        .add(const Duration(minutes: 1));
    final delay = next.difference(now) + const Duration(milliseconds: 50);
    _timer = Timer(delay, () {
      if (!mounted) {
        return;
      }
      setState(() => _text = _format(_now));
      _scheduleNextTick();
    });
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
