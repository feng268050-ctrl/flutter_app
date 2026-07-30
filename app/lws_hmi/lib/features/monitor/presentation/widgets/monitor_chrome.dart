import 'package:flutter/material.dart';
import 'package:lws_hmi/features/home/application/temp_series.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:cyber_ui/cyber_ui.dart';

/// Design tokens aligned with lws-ui Monitor / Frost glass stand-ins.
abstract final class MonitorDimens {
  static const pad = 24.0;
  static const corner = 18.0;
  static const metricH = 88.0;
  static const leftPanelW = 740.0;
  static const leftPanelH = 608.0;
  static const logPanelW = 468.0;
  static const gaugeCardW = 604.0;
  static const gaugeCardH = 344.0;
  static const gaugeSide = 220.0;
  static const tileW = 290.0;
  static const tileH = 102.0;
  static const workRingH = 250.0;
  static const aiInfoW = 360.0;
  /// Alarm section titles (base 24 + tab-3 content bump).
  static const sectionTitleSize = 28.0;
  /// Metric/comm labels — Alarm left panel (+8 vs original 13).
  static const metricLabelSize = 21.0;
  /// Temperature values — Alarm left panel (+8 vs original 18).
  static const metricValueSize = 26.0;
  /// lws-ui `@color/warn_text`.
  static const labelColor = Color(0xFFB0B1C2);
}

class MonitorGlassCard extends StatelessWidget {
  const MonitorGlassCard({
    super.key,
    required this.child,
    this.height,
    this.width,
    this.padding = const EdgeInsets.all(MonitorDimens.pad),
    this.margin,
    this.borderGradientCenter =
        CyberBorderGradientCenter.topLeftBottomRight,
  });

  final Widget child;
  final double? height;
  final double? width;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final CyberBorderGradientCenter borderGradientCenter;

  @override
  Widget build(BuildContext context) {
    final theme = CyberGlassTheme.of(context);
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: CyberOutlinedPanel(
        clipBehavior: Clip.antiAlias,
        outline: CyberPanelOutline(
          style: CyberPanelOutlineStyle.frostGradient,
          tone: theme.tone,
          // Match EngineerFrostPanel bright-edge stroke (1.5).
          width: 1.5,
          cornerRadius: MonitorDimens.corner,
          gradientCenter: borderGradientCenter,
        ),
        // Same frosted panel fill as SettingsPanel / SettingsGroup.
        color: Colors.white.withOpacity(0.06),
        child: SizedBox(
          width: width,
          height: height,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class MonitorSectionHeader extends StatelessWidget {
  const MonitorSectionHeader(this.title, {super.key});

  final String title;

  /// lws-ui `section_header_divider_height`.
  static const dividerHeight = 1.0;

  /// lws-ui SectionHeader `dividerTopSpacing` default (`frost_dialog_content_padding`).
  static const dividerTopSpacing = 24.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: MonitorDimens.sectionTitleSize,
              fontWeight: FontWeight.w400,
              height: 1.1,
            ),
          ),
          const SizedBox(height: dividerTopSpacing),
          // lws-ui `frost_divider_start_aligned`: left (center) → right (edge).
          const SizedBox(
            height: dividerHeight,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    CyberColors.dividerCenter,
                    Color(0x00000000),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Maps Alarm / metric cards onto Cyber status light (Icon variant).
enum MonitorIndicatorKind { idle, success, failure }

class MonitorStatusIcon extends StatelessWidget {
  const MonitorStatusIcon({super.key, required this.kind, this.size = 28});

  final MonitorIndicatorKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final state = switch (kind) {
      MonitorIndicatorKind.idle => CyberStatusState.idle,
      MonitorIndicatorKind.success => CyberStatusState.success,
      MonitorIndicatorKind.failure => CyberStatusState.failure,
    };
    return CyberStatusIndicator(
      state: state,
      variant: CyberStatusVariant.icon,
      size: size,
    );
  }
}

/// Machine Status tiles — Cyber status light Dot variant.
class MonitorStatusDot extends StatelessWidget {
  const MonitorStatusDot({super.key, required this.on, this.size = 28});

  final bool? on;
  final double size;

  @override
  Widget build(BuildContext context) {
    // On → green center; unknown/off → idle gray (lws-ui machine tiles).
    final state =
        on == true ? CyberStatusState.success : CyberStatusState.idle;
    return CyberStatusIndicator(
      state: state,
      variant: CyberStatusVariant.dot,
      size: size,
    );
  }
}

/// Alarm metric card: value above label + status icon (102dp).
class MonitorMetricCard extends StatelessWidget {
  const MonitorMetricCard({
    super.key,
    required this.value,
    required this.label,
    this.fault = false,
    this.hasValue = true,
  });

  final String value;
  final String label;
  final bool fault;
  final bool hasValue;

  @override
  Widget build(BuildContext context) {
    // Missing sample → idle (empty); known fault → red; else green.
    final kind = !hasValue
        ? MonitorIndicatorKind.idle
        : (fault ? MonitorIndicatorKind.failure : MonitorIndicatorKind.success);
    return MonitorGlassCard(
      height: MonitorDimens.metricH,
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 24,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: fault ? const Color(0xFFFF8A80) : Colors.white,
                          fontSize: MonitorDimens.metricValueSize,
                          fontWeight: FontWeight.w400,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      color: MonitorDimens.labelColor,
                      fontSize: MonitorDimens.metricLabelSize,
                      fontWeight: FontWeight.w400,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          MonitorStatusIcon(kind: kind),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Comm-status row card (label + icon).
class MonitorCommCard extends StatelessWidget {
  const MonitorCommCard({
    super.key,
    required this.label,
    required this.kind,
  });

  final String label;
  final MonitorIndicatorKind kind;

  @override
  Widget build(BuildContext context) {
    return MonitorGlassCard(
      height: MonitorDimens.metricH,
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  color: MonitorDimens.labelColor,
                  fontSize: MonitorDimens.metricLabelSize,
                  fontWeight: FontWeight.w400,
                  height: 1.15,
                ),
              ),
            ),
          ),
          MonitorStatusIcon(kind: kind),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class MonitorTempMetricCard extends StatelessWidget {
  const MonitorTempMetricCard({
    super.key,
    required this.series,
    required this.label,
    required this.overTemp,
  });

  final TempSeries series;
  final String label;
  final bool overTemp;

  @override
  Widget build(BuildContext context) {
    final hasValue = series.display != '-' && !series.display.startsWith('OVER');
    final value = overTemp && series.display.contains('°C')
        ? series.display.split(' · ').first
        : series.display;
    final l10n = AppLocalizations.of(context)!;
    return MonitorMetricCard(
      value: overTemp && !hasValue ? l10n.overTempLabel : value,
      label: label,
      fault: overTemp,
      hasValue: hasValue || overTemp,
    );
  }
}

class MonitorHealthBanner extends StatelessWidget {
  const MonitorHealthBanner({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = CyberGlassTheme.of(context);
    return CyberOutlinedPanel(
      clipBehavior: Clip.antiAlias,
      outline: CyberPanelOutline(
        style: CyberPanelOutlineStyle.frostGradient,
        tone: theme.tone,
        width: 1.5,
        cornerRadius: 12,
        gradientCenter: CyberBorderGradientCenter.topBottom,
      ),
      color: Colors.white.withOpacity(0.06),
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
                    : l10n.modbusCommunicationFault,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MonitorAlarmLogRow extends StatelessWidget {
  const MonitorAlarmLogRow({
    super.key,
    required this.code,
    required this.label,
    this.timestamp,
  });

  final String code;
  final String label;
  final DateTime? timestamp;

  @override
  Widget build(BuildContext context) {
    final time = timestamp;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              code,
              style: const TextStyle(
                color: Color(0xFFFF8A80),
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 19,
                  ),
                ),
                if (time != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(time.toLocal()),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 16,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }
}

class MonitorStatusTile extends StatelessWidget {
  const MonitorStatusTile({
    super.key,
    required this.label,
    this.on,
    this.height,
    this.borderGradientCenter =
        CyberBorderGradientCenter.topLeftBottomRight,
  });

  final String label;
  final bool? on;
  final double? height;
  final CyberBorderGradientCenter borderGradientCenter;

  @override
  Widget build(BuildContext context) {
    return MonitorGlassCard(
      height: height ?? MonitorDimens.tileH,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      borderGradientCenter: borderGradientCenter,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
          MonitorStatusDot(on: on),
        ],
      ),
    );
  }
}

class MonitorWorkDataCard extends StatelessWidget {
  const MonitorWorkDataCard({
    super.key,
    required this.title,
    required this.value,
    this.suffix = '',
    this.borderGradientCenter =
        CyberBorderGradientCenter.topLeftBottomRight,
  });

  final String title;
  final String value;
  final String suffix;
  final CyberBorderGradientCenter borderGradientCenter;

  @override
  Widget build(BuildContext context) {
    return MonitorGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      borderGradientCenter: borderGradientCenter,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tight = constraints.maxHeight < 140;
          // Work Info tab: +2 over prior 16/22, 28/40, 16/24.
          final titleSize = tight ? 18.0 : 24.0;
          final valueSize = tight ? 30.0 : 42.0;
          final suffixSize = tight ? 18.0 : 26.0;
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: titleSize),
                  ),
                  SizedBox(height: tight ? 6 : 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: valueSize,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (suffix.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Padding(
                          padding: EdgeInsets.only(bottom: tight ? 2 : 6),
                          child: Text(
                            suffix,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: suffixSize,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
