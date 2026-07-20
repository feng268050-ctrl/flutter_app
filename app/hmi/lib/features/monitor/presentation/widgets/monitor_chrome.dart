import 'package:flutter/material.dart';
import 'package:lws_hmi/features/home/application/temp_series.dart';
import 'package:lws_hmi/features/monitor/domain/active_alarm.dart';

/// Shared Material chrome for Monitor tabs (stand-in for lws-ui More Monitor).
class MonitorPlaceholderPane extends StatelessWidget {
  const MonitorPlaceholderPane({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.white70,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class MonitorHealthBanner extends StatelessWidget {
  const MonitorHealthBanner({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF5D4037),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message?.trim().isNotEmpty == true
                    ? message!
                    : 'Modbus communication fault',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MonitorSectionCard extends StatelessWidget {
  const MonitorSectionCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.42),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: child,
      ),
    );
  }
}

class MonitorTempRow extends StatelessWidget {
  const MonitorTempRow({super.key, required this.label, required this.series});

  final String label;
  final TempSeries series;

  @override
  Widget build(BuildContext context) {
    final over = series.display.contains('OVER TEMP');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 16,
              ),
            ),
          ),
          if (series.trend == TempTrend.up)
            const Icon(Icons.arrow_drop_up, color: Color(0xFFE53935), size: 24)
          else if (series.trend == TempTrend.down)
            const Icon(
              Icons.arrow_drop_down,
              color: Color(0xFF43A047),
              size: 24,
            ),
          Text(
            series.display,
            style: TextStyle(
              color: over ? const Color(0xFFFF8A80) : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class MonitorAlarmRow extends StatelessWidget {
  const MonitorAlarmRow({super.key, required this.alarm});

  final ActiveAlarm alarm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              alarm.code,
              style: const TextStyle(
                color: Color(0xFFFF8A80),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              alarm.label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
