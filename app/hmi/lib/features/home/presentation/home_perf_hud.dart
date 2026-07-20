import 'dart:async';

import 'package:cyber_hal/sys_info.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';

/// Engineering overlay: UI/raster FPS + DRM panel Hz + SoC/GPU temperature.
class HomePerfHud extends StatefulWidget {
  const HomePerfHud({super.key});

  @override
  State<HomePerfHud> createState() => _HomePerfHudState();
}

class _HomePerfHudState extends State<HomePerfHud> {
  StreamSubscription<SysInfoUpdate>? _sub;
  SysInfoSnapshot? _snap;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = AppScope.maybeOf(context);
    if (services == null || _sub != null) {
      return;
    }
    _sub = services.sysInfo.watch(interval: const Duration(seconds: 1)).listen(
      (update) {
        if (!mounted) {
          return;
        }
        setState(() => _snap = update.snapshot);
      },
    );
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  static String _fps(double? v) =>
      v == null ? '--' : v.toStringAsFixed(0);

  static String _temp(ThermalZone? z) {
    final t = z?.temperatureCelsius;
    if (t == null) {
      return '--';
    }
    return '${t.toStringAsFixed(0)}°C';
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snap;
    final text =
        'UI ${_fps(snap?.uiFps)} | RAST ${_fps(snap?.rasterFps)} | '
        'PANEL ${_fps(snap?.panelRefreshHz)} | '
        'SoC ${_temp(snap?.socThermal)} | GPU ${_temp(snap?.gpuThermal)}';
    return IgnorePointer(
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          height: 1.2,
          color: Colors.white.withOpacity(0.72),
          shadows: const [
            Shadow(blurRadius: 4, color: Color(0x88000000)),
          ],
        ),
      ),
    );
  }
}
