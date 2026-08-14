import 'dart:async';
import 'dart:math' as math;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:lws_hmi/features/home/application/custom_home_layout_store.dart';
import 'package:lws_hmi/features/home/domain/custom_home_layout.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_l10n.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/settings/application/common_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/length_unit_convert.dart';
import 'package:lws_hmi/features/statistics/application/stats_metric_format.dart';
import 'package:lws_hmi/features/statistics/domain/stats_aggregate_models.dart';
import 'package:lws_hmi/features/statistics/domain/stats_aggregate_repository.dart';
import 'package:lws_hmi/features/statistics/infrastructure/sqlite_stats_aggregate_repository.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/word_boundary_label.dart';

/// The four persisted Custom Home slots rendered on the product Home page.
///
/// The layout store contains only position/type. Numeric values are calculated
/// here from the single-row [StatsAggregate] so a layout save never duplicates
/// or mutates statistics.
class CustomHomeStatisticsPanel extends StatefulWidget {
  const CustomHomeStatisticsPanel({
    super.key,
    required this.cardWidth,
    required this.cardHeight,
    required this.cardGap,
    this.layoutStore,
    this.repository,
    this.deferFrost = false,
  });

  final double cardWidth;
  final double cardHeight;
  final double cardGap;
  final CustomHomeLayoutStore? layoutStore;
  final StatsAggregateRepository? repository;

  /// When true, skip frost capture + SQLite until cleared (boot KPI).
  final bool deferFrost;

  @override
  State<CustomHomeStatisticsPanel> createState() =>
      CustomHomeStatisticsPanelState();
}

class CustomHomeStatisticsPanelState extends State<CustomHomeStatisticsPanel> {
  late final CustomHomeLayoutStore _layoutStore =
      widget.layoutStore ?? CustomHomeLayoutStore();
  late final StatsAggregateRepository _repository =
      widget.repository ?? SqliteStatsAggregateRepository();
  late final bool _ownsRepository = widget.repository == null;

  List<CustomHomeMetric> _metrics = CustomHomeLayout.defaults.take(4).toList();
  StatsAggregate? _aggregate;

  @override
  void initState() {
    super.initState();
    if (!widget.deferFrost) {
      unawaited(refresh());
    }
  }

  @override
  void didUpdateWidget(CustomHomeStatisticsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deferFrost && !widget.deferFrost) {
      unawaited(refresh());
    }
  }

  /// Re-reads the saved layout and aggregate after Settings is popped.
  Future<void> refresh() async {
    _layoutStore.warmRead();
    final metrics = _layoutStore.metrics.take(4).toList(growable: false);
    StatsAggregate? aggregate;
    try {
      await _repository.refreshWeekAnchors(DateTime.now());
      aggregate = await _repository.load();
    } catch (_) {
      // Keep cards visible with zero/empty values while storage is unavailable.
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _metrics = metrics;
      _aggregate = aggregate;
    });
  }

  @override
  void dispose() {
    if (_ownsRepository) {
      unawaited(_repository.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unitWire = CommonSettingsScope.maybeOf(context)?.unitWire;
    final cards = _metrics
        .map((metric) => _HomeStatisticCard(
              key: ValueKey('home-stat-${metric.name}'),
              metric: metric,
              value: _displayValue(l10n, metric, _aggregate, unitWire),
              width: widget.cardWidth,
              height: widget.cardHeight,
              deferFrost: widget.deferFrost,
            ))
        .toList(growable: false);
    return Row(
      children: [
        cards[0],
        SizedBox(width: widget.cardGap),
        cards[1],
        const Spacer(),
        cards[2],
        SizedBox(width: widget.cardGap),
        cards[3],
      ],
    );
  }
}

_HomeStatisticDisplay _displayValue(
  AppLocalizations l10n,
  CustomHomeMetric metric,
  StatsAggregate? aggregate,
  String? unitWire,
) {
  final totalLaserSeconds = aggregate?.laserOnSecondsTotal ?? 0;
  final modeSeconds = switch (metric) {
    CustomHomeMetric.weldRatio => aggregate?.weldSecondsTotal ?? 0,
    CustomHomeMetric.cutRatio => aggregate?.cutSecondsTotal ?? 0,
    CustomHomeMetric.cleanRatio => aggregate?.cleanSecondsTotal ?? 0,
    _ => 0,
  };

  return switch (metric) {
    // Titles match lws-ui `HomeLayoutUtils.typeToTitle`.
    CustomHomeMetric.wireConsumption => () {
        final wire = LengthUnitConvert.formatWireConsumption(
          aggregate?.wireFeedLengthMmTotal ?? 0,
          unitWire: unitWire,
        );
        return _HomeStatisticDisplay(
          title: l10n.warnInfoWeldingConsumables,
          number: wire.number,
          unit: wire.unit,
        );
      }(),
    CustomHomeMetric.laserOnDuration => _durationDisplay(
        title: l10n.warnInfoLightTime,
        seconds: totalLaserSeconds,
      ),
    CustomHomeMetric.jobRuntime => _durationDisplay(
        title: l10n.warnInfoLastWork,
        seconds: aggregate?.jobRuntimeSecondsTotal ?? 0,
      ),
    CustomHomeMetric.weldRatio => _HomeStatisticDisplay(
        title: l10n.weldingProportionText,
        number: _ratioPercent(modeSeconds, totalLaserSeconds).toString(),
        unit: '%',
        isRatio: true,
      ),
    CustomHomeMetric.cutRatio => _HomeStatisticDisplay(
        title: l10n.cuttingProportionText,
        number: _ratioPercent(modeSeconds, totalLaserSeconds).toString(),
        unit: '%',
        isRatio: true,
      ),
    CustomHomeMetric.cleanRatio => _HomeStatisticDisplay(
        title: l10n.washProportionText,
        number: _ratioPercent(modeSeconds, totalLaserSeconds).toString(),
        unit: '%',
        isRatio: true,
      ),
    CustomHomeMetric.weekOverWeekLaser => _HomeStatisticDisplay(
        title: l10n.warnInfoLightTimeInfo,
        number: weekOverWeekLaserPercent(aggregate).toString(),
        unit: '%',
      ),
    CustomHomeMetric.favoriteMaterial => _HomeStatisticDisplay(
        title: l10n.warnInfoWeldingConsumablesInfo,
        number: _materialName(l10n, aggregate?.favoriteMaterialType),
      ),
  };
}

_HomeStatisticDisplay _durationDisplay({
  required String title,
  required int seconds,
}) {
  final formatted = formatCustomHomeDurationSeconds(seconds);
  return _HomeStatisticDisplay(
    title: title,
    number: formatted.number,
    unit: formatted.unit,
  );
}

/// Custom Home time metrics: under 1h → minutes; 1h and above → whole hours
/// (e.g. 75 min → `1` + `h`).
@visibleForTesting
({String number, String unit}) formatCustomHomeDurationSeconds(int seconds) =>
    formatStatsDurationSeconds(seconds);

int _ratioPercent(int portionSeconds, int totalSeconds) {
  if (totalSeconds <= 0 || portionSeconds <= 0) {
    return 0;
  }
  return (portionSeconds * 100 / totalSeconds).truncate();
}

/// Week-over-week laser-on increase % for Custom Home "较上周增加出光时长".
///
/// Aligns with lws-ui intent: last week 0 → 100/0; equal → 0; increase →
/// truncated growth %; decrease → 0 (never a negative percentage).
@visibleForTesting
int weekOverWeekLaserPercent(StatsAggregate? aggregate) {
  if (aggregate == null) {
    return 0;
  }
  final currentWeek =
      (aggregate.laserOnSecondsTotal - aggregate.weekAnchorLaserOnSecondsTotal)
          .clamp(0, 1 << 31);
  final previousWeek = (aggregate.weekAnchorLaserOnSecondsTotal -
          aggregate.prevWeekAnchorLaserOnSecondsTotal)
      .clamp(0, 1 << 31);
  // Last week had no laser-on time.
  if (previousWeek == 0) {
    return currentWeek > 0 ? 100 : 0;
  }
  // Equal or down vs last week → 0% (card is "increase", not signed delta).
  if (currentWeek <= previousWeek) {
    return 0;
  }
  return ((currentWeek - previousWeek) * 100 / previousWeek).truncate();
}

String _materialName(AppLocalizations l10n, int? storageValue) {
  if (storageValue == null) {
    return '—';
  }
  try {
    return MaterialType.fromStorageValue(storageValue).localizedLabel(l10n);
  } on FormatException {
    return '—';
  }
}

final class _HomeStatisticDisplay {
  const _HomeStatisticDisplay({
    required this.title,
    required this.number,
    this.unit,
    this.isRatio = false,
  });

  final String title;
  final String number;
  final String? unit;
  final bool isRatio;
}

final class _HomeStatisticCard extends StatelessWidget {
  const _HomeStatisticCard({
    super.key,
    required this.metric,
    required this.value,
    required this.width,
    required this.height,
    this.deferFrost = false,
  });

  final CustomHomeMetric metric;
  final _HomeStatisticDisplay value;
  final double width;
  final double height;
  final bool deferFrost;

  @override
  Widget build(BuildContext context) {
    final compact = width < 160 || height < 100;
    final titleSize =
        (height * 0.19).clamp(12.0, 22.0); // micro → sectionTitle
    final numberSize =
        (height * 0.52).clamp(28.0, 52.0); // pageTitle → criticalTitle
    final unitSize =
        (height * 0.27).clamp(16.0, 28.0); // supporting → pageTitle
    final ratio = value.isRatio;
    return SizedBox(
      width: width,
      height: height,
      child: CyberCard(
        // firstFrame: capture + bake Gaussian once; paint is RawImage only
        // (cyber_ui bake-in). Safe over looping WebP plates.
        sampleMode: CyberBlurSampleMode.firstFrame,
        intensity: deferFrost
            ? CyberBlurIntensity.transparent
            : CyberBlurIntensity.low,
        blurTint: CyberBlurTint.dark,
        borderRadius: BorderRadius.circular(18),
        borderColor: const Color(0x99CBD3F3),
        borderWidth: 1.2,
        child: Padding(
          // Equal inset on all four sides so arc-to-edge gaps match.
          padding: EdgeInsets.all(height * 0.1),
          child: Column(
            crossAxisAlignment:
                ratio ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ratio
                    ? Align(
                        alignment: Alignment.topCenter,
                        child: _RatioArcGauge(
                          percent: double.tryParse(value.number) ?? 0,
                          color: _ratioProgressColor(metric),
                          cardWidth: width,
                          cardHeight: height,
                        ),
                      )
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: RichText(
                            maxLines: 1,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: value.number,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: numberSize,
                                    height: 1,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (value.unit != null)
                                  TextSpan(
                                    text: ' ${value.unit}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: unitSize,
                                      height: 1,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
              WordBoundaryLabel(
                text: value.title,
                textAlign: ratio ? TextAlign.center : TextAlign.start,
                maxLines: compact ? 1 : 2,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleSize,
                  height: 1.05,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 180° upper semicircle (∩). Radius = longest card side / 4.
class _RatioArcGauge extends StatelessWidget {
  const _RatioArcGauge({
    required this.percent,
    required this.color,
    required this.cardWidth,
    required this.cardHeight,
  });

  final double percent;
  final Color color;
  final double cardWidth;
  final double cardHeight;

  /// Longest card edge ÷ 4 — card outer size stays unchanged.
  double get _radius => math.max(cardWidth, cardHeight) / 4;

  @override
  Widget build(BuildContext context) {
    final radius = _radius;
    // Thicker ∩ band than the initial 0.14×radius (was clamped ≤8).
    final stroke = (radius * 0.26).clamp(8.0, 16.0);
    // Full stroke clearance above the peak so CyberCard clip does not crop it.
    final gaugeW = radius * 2 + stroke;
    final gaugeH = radius + stroke;
    final value = percent.clamp(0.0, 100.0);
    final labelSize = (radius * 0.44).clamp(16.0, 28.0);
    return SizedBox(
        width: gaugeW,
        height: gaugeH,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(gaugeW, gaugeH),
              painter: _HomeRatioArcPainter(
                percent: value,
                radius: radius,
                strokeWidth: stroke,
                progressColor: color,
                trackColor: const Color(0x66FFFFFF),
              ),
            ),
            // Sit under the ∩ arc, above the chord.
            Positioned(
              left: 0,
              right: 0,
              bottom: stroke * 0.15,
              child: Text(
                '${value.round()}%',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: labelSize,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
    );
  }
}

/// Flutter arc: 0 = +X, clockwise. Left → top → right (∩).
class _HomeRatioArcPainter extends CustomPainter {
  _HomeRatioArcPainter({
    required this.percent,
    required this.radius,
    required this.strokeWidth,
    required this.progressColor,
    required this.trackColor,
  });

  final double percent;
  final double radius;
  final double strokeWidth;
  final Color progressColor;
  final Color trackColor;

  static const _startAngle = math.pi;
  static const _sweepAngle = math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    // Chord on the bottom; peak stays inside the paint bounds.
    final center = Offset(size.width / 2, size.height - strokeWidth / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final t = (percent / 100).clamp(0.0, 1.0);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawArc(rect, _startAngle, _sweepAngle, false, trackPaint);

    if (t > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;
      canvas.drawArc(rect, _startAngle, _sweepAngle * t, false, progressPaint);
    }

    final tipAngle = _startAngle + _sweepAngle * t;
    final tip = Offset(
      center.dx + radius * math.cos(tipAngle),
      center.dy + radius * math.sin(tipAngle),
    );
    canvas.drawCircle(
      tip,
      strokeWidth * 0.55,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _HomeRatioArcPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}

Color _ratioProgressColor(CustomHomeMetric metric) => switch (metric) {
      // Match Work Info / lws-ui weld·cut·clean accent colors.
      CustomHomeMetric.weldRatio => const Color(0xFFFF0000),
      CustomHomeMetric.cutRatio => const Color(0xFF00A4F2),
      CustomHomeMetric.cleanRatio => const Color(0xFFFF8000),
      _ => const Color(0xFF00A4F2),
    };
