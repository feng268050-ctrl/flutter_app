import 'dart:async';

import 'package:cyber_hal/sys_info.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';

enum _MetricTrend { none, up, down }

/// Global engineering status card: one SysInfo metric per row.
class SystemStatusCard extends StatefulWidget {
  const SystemStatusCard({super.key});

  @override
  State<SystemStatusCard> createState() => _SystemStatusCardState();
}

class _SystemStatusCardState extends State<SystemStatusCard> {
  static const _rowHeight = 26.0;
  static const _arrowSlot = 18.0;

  StreamSubscription<SysInfoUpdate>? _sub;
  SysInfoSnapshot? _snap;
  bool _started = false;

  final Map<String, double?> _prev = {};
  final Map<String, _MetricTrend> _trend = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    final services = AppScope.maybeOf(context);
    if (services == null) {
      return;
    }
    _started = true;
    _sub = services.sysInfo.watch(interval: const Duration(seconds: 1)).listen(
      (update) {
        if (!mounted) {
          return;
        }
        setState(() {
          _snap = update.snapshot;
          _updateTrends(update.snapshot);
        });
      },
    );
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  void _updateTrends(SysInfoSnapshot snap) {
    _sample('UI', snap.uiFps);
    _sample('RAST', snap.rasterFps);
    _sample('PANEL', snap.panelRefreshHz);
    _sample('SoC', snap.socThermal?.temperatureCelsius);
    _sample('GPU', snap.gpuThermal?.temperatureCelsius);
    _sample('MEM', _memoryUsedBytes(snap)?.toDouble());
    _sample('LOAD', snap.loadAverage?.one);
    _sample('UP', snap.uptime?.inSeconds.toDouble());
  }

  void _sample(String key, double? value) {
    final prev = _prev[key];
    if (value == null) {
      _trend[key] = _MetricTrend.none;
      _prev[key] = null;
      return;
    }
    if (prev != null) {
      if (value > prev) {
        _trend[key] = _MetricTrend.up;
      } else if (value < prev) {
        _trend[key] = _MetricTrend.down;
      }
      // Equal → keep last non-none trend (or stay none).
    }
    _prev[key] = value;
  }

  static int? _memoryUsedBytes(SysInfoSnapshot snap) {
    final total = snap.memoryTotalBytes;
    final avail = snap.memoryAvailableBytes;
    if (total == null || avail == null) {
      return null;
    }
    return total - avail;
  }

  static String _fps(double? v) => v == null ? '--' : v.toStringAsFixed(0);

  static String _temp(ThermalZone? z) {
    final t = z?.temperatureCelsius;
    if (t == null) {
      return '--';
    }
    return '${t.toStringAsFixed(0)}°C';
  }

  static String _memory(SysInfoSnapshot? snap) {
    if (snap == null) {
      return '--';
    }
    final total = snap.memoryTotalBytes;
    final avail = snap.memoryAvailableBytes;
    if (total == null || avail == null) {
      return '--';
    }
    final usedMb = ((total - avail) / (1024 * 1024)).round();
    final totalMb = (total / (1024 * 1024)).round();
    return '$usedMb/$totalMb MB';
  }

  static String _load(LoadAverage? load) {
    if (load == null) {
      return '--';
    }
    return load.one.toStringAsFixed(2);
  }

  static String _uptime(Duration? d) {
    if (d == null) {
      return '--';
    }
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    final mins = d.inMinutes.remainder(60);
    if (days > 0) {
      return '${days}d ${hours}h';
    }
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  Widget _arrow(_MetricTrend trend) {
    // Fixed slot so icons never change row height / width.
    IconData? icon;
    Color? color;
    switch (trend) {
      case _MetricTrend.up:
        icon = Icons.arrow_drop_up;
        color = const Color(0xFFFF5A5A);
      case _MetricTrend.down:
        icon = Icons.arrow_drop_down;
        color = const Color(0xFF3DDC84);
      case _MetricTrend.none:
        break;
    }
    return SizedBox(
      width: _arrowSlot,
      height: _rowHeight,
      child: icon == null
          ? null
          : Icon(
              icon,
              size: 22,
              color: color,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snap;
    final rows = <(String, String)>[
      ('UI', _fps(snap?.uiFps)),
      ('RAST', _fps(snap?.rasterFps)),
      ('PANEL', _fps(snap?.panelRefreshHz)),
      ('SoC', _temp(snap?.socThermal)),
      ('GPU', _temp(snap?.gpuThermal)),
      ('MEM', _memory(snap)),
      ('LOAD', _load(snap?.loadAverage)),
      ('UP', _uptime(snap?.uptime)),
    ];

    final baseStyle = context.hmiTypography.supporting.copyWith(
      height: 1.0,
      color: Colors.white.withOpacity(0.82),
      shadows: const [
        Shadow(blurRadius: 4, color: Color(0x88000000)),
      ],
    );

    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 240,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0x99101418),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: DefaultTextStyle(
            style: baseStyle,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final row in rows)
                  SizedBox(
                    height: _rowHeight,
                    child: Row(
                      children: [
                        Text(
                          row.$1,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            height: 1.0,
                          ),
                        ),
                        const Spacer(),
                        _arrow(_trend[row.$1] ?? _MetricTrend.none),
                        Text(
                          row.$2,
                          textAlign: TextAlign.right,
                          style: const TextStyle(height: 1.0),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
