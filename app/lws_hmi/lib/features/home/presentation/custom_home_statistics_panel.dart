import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:lws_hmi/features/home/application/custom_home_layout_store.dart';
import 'package:lws_hmi/features/home/domain/custom_home_layout.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/settings/application/common_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/length_unit_convert.dart';
import 'package:lws_hmi/features/statistics/domain/stats_aggregate_models.dart';
import 'package:lws_hmi/features/statistics/domain/stats_aggregate_repository.dart';
import 'package:lws_hmi/features/statistics/infrastructure/sqlite_stats_aggregate_repository.dart';

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
  });

  final double cardWidth;
  final double cardHeight;
  final double cardGap;
  final CustomHomeLayoutStore? layoutStore;
  final StatsAggregateRepository? repository;

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
    unawaited(refresh());
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
    final unitWire = CommonSettingsScope.maybeOf(context)?.unit;
    final cards = _metrics
        .map((metric) => _HomeStatisticCard(
              key: ValueKey('home-stat-${metric.name}'),
              metric: metric,
              value: _displayValue(metric, _aggregate, unitWire),
              width: widget.cardWidth,
              height: widget.cardHeight,
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
    CustomHomeMetric.wireConsumption => _HomeStatisticDisplay(
        title: 'Total Wire Consumption',
        number: LengthUnitConvert.formatMm(
          (aggregate?.wireFeedLengthMmTotal ?? 0).toDouble(),
          unitWire: unitWire,
        ),
        unit: LengthUnitConvert.suffix(unitWire),
      ),
    CustomHomeMetric.laserOnDuration => _durationDisplay(
        title: 'Total Laser-on Time',
        seconds: totalLaserSeconds,
      ),
    CustomHomeMetric.jobRuntime => _durationDisplay(
        title: 'Job Runtime',
        seconds: aggregate?.jobRuntimeSecondsTotal ?? 0,
      ),
    CustomHomeMetric.weldRatio => _HomeStatisticDisplay(
        title: 'Welding Ratio',
        number: _ratioPercent(modeSeconds, totalLaserSeconds).toString(),
        unit: '%',
        isRatio: true,
      ),
    CustomHomeMetric.cutRatio => _HomeStatisticDisplay(
        title: 'Cutting Ratio',
        number: _ratioPercent(modeSeconds, totalLaserSeconds).toString(),
        unit: '%',
        isRatio: true,
      ),
    CustomHomeMetric.cleanRatio => _HomeStatisticDisplay(
        title: 'Cleaning Ratio',
        number: _ratioPercent(modeSeconds, totalLaserSeconds).toString(),
        unit: '%',
        isRatio: true,
      ),
    CustomHomeMetric.weekOverWeekLaser => _HomeStatisticDisplay(
        title: 'Laser Time vs Last Week',
        number: weekOverWeekLaserPercent(aggregate).toString(),
        unit: '%',
      ),
    CustomHomeMetric.favoriteMaterial => _HomeStatisticDisplay(
        title: 'Favorite Material',
        number: _materialName(aggregate?.favoriteMaterialType),
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
({String number, String unit}) formatCustomHomeDurationSeconds(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  if (safe >= 3600) {
    return (number: (safe ~/ 3600).toString(), unit: 'h');
  }
  return (number: (safe ~/ 60).toString(), unit: 'min');
}

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

String _materialName(int? storageValue) {
  if (storageValue == null) {
    return '—';
  }
  try {
    return MaterialType.fromStorageValue(storageValue).englishName;
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
  });

  final CustomHomeMetric metric;
  final _HomeStatisticDisplay value;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final compact = width < 160 || height < 100;
    final titleSize = (height * 0.19).clamp(13.0, 22.0);
    final numberSize = (height * 0.52).clamp(28.0, 58.0);
    final unitSize = (height * 0.27).clamp(16.0, 30.0);
    return SizedBox(
      width: width,
      height: height,
      child: CyberCard(
        // firstFrame: capture + bake Gaussian once; paint is RawImage only
        // (cyber_ui bake-in). Safe over looping WebP plates.
        sampleMode: CyberBlurSampleMode.firstFrame,
        intensity: CyberBlurIntensity.low,
        blurTint: CyberBlurTint.dark,
        borderRadius: BorderRadius.circular(18),
        borderColor: const Color(0x99CBD3F3),
        borderWidth: 1.2,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            width * 0.09,
            height * 0.10,
            width * 0.07,
            height * 0.05,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: value.isRatio
                      ? _RatioValue(
                          value: value.number,
                          numberSize: numberSize,
                        )
                      : FittedBox(
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
              Text(
                value.title,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
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

final class _RatioValue extends StatelessWidget {
  const _RatioValue({required this.value, required this.numberSize});

  final String value;
  final double numberSize;

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: 1,
      text: TextSpan(
        children: [
          TextSpan(
            text: value,
            style: TextStyle(
              color: Colors.white,
              fontSize: numberSize,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: ' %',
            style: TextStyle(
              color: Colors.white,
              fontSize: numberSize * 0.5,
              height: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
