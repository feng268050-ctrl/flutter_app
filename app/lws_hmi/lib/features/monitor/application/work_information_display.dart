import 'package:lws_hmi/features/settings/application/length_unit_convert.dart';
import 'package:lws_hmi/features/statistics/application/stats_metric_format.dart';
import 'package:lws_hmi/features/statistics/domain/stats_aggregate_models.dart';

/// Derived Monitor Work Info values from [StatsAggregate].
///
/// Aligns with Custom Home: duration min→h at 1h; wire mm→m at 1 m
/// ([LengthUnitConvert.formatWireConsumption]).
final class WorkInformationDisplay {
  const WorkInformationDisplay({
    required this.weldRatioPercent,
    required this.cutRatioPercent,
    required this.cleanRatioPercent,
    required this.laserOnNumber,
    required this.laserOnUnit,
    required this.wireNumber,
    required this.wireUnit,
    required this.jobRuntimeNumber,
    required this.jobRuntimeUnit,
  });

  final int weldRatioPercent;
  final int cutRatioPercent;
  final int cleanRatioPercent;

  /// Laser-on duration number (`min` under 1h, `h` at/above).
  final String laserOnNumber;
  final String laserOnUnit;

  /// Wire length number (metric mm/m or imperial feet).
  final String wireNumber;
  final String wireUnit;

  /// Last job runtime number (`min` under 1h, `h` at/above).
  final String jobRuntimeNumber;
  final String jobRuntimeUnit;

  static const empty = WorkInformationDisplay(
    weldRatioPercent: 0,
    cutRatioPercent: 0,
    cleanRatioPercent: 0,
    laserOnNumber: '0',
    laserOnUnit: 'min',
    wireNumber: '0',
    wireUnit: 'mm',
    jobRuntimeNumber: '0',
    jobRuntimeUnit: 'min',
  );

  factory WorkInformationDisplay.fromAggregate(
    StatsAggregate? aggregate, {
    String? unitWire,
  }) {
    if (aggregate == null) {
      final wire =
          LengthUnitConvert.formatWireConsumption(0, unitWire: unitWire);
      return WorkInformationDisplay(
        weldRatioPercent: 0,
        cutRatioPercent: 0,
        cleanRatioPercent: 0,
        laserOnNumber: '0',
        laserOnUnit: 'min',
        wireNumber: '0',
        wireUnit: wire.unit,
        jobRuntimeNumber: '0',
        jobRuntimeUnit: 'min',
      );
    }
    final weld = aggregate.weldSecondsTotal;
    final cut = aggregate.cutSecondsTotal;
    final clean = aggregate.cleanSecondsTotal;
    // lws-ui ratios use weld+cut+wash; hours use the same sum / 3600.
    // Prefer persisted laserOnSecondsTotal when it matches the migration model.
    final sum = weld + cut + clean;
    final laserOn = aggregate.laserOnSecondsTotal > 0
        ? aggregate.laserOnSecondsTotal
        : sum;
    final wire = LengthUnitConvert.formatWireConsumption(
      aggregate.wireFeedLengthMmTotal,
      unitWire: unitWire,
    );
    final laser = formatStatsDurationSeconds(laserOn);
    final job = formatStatsDurationSeconds(aggregate.jobRuntimeSecondsTotal);
    return WorkInformationDisplay(
      weldRatioPercent: ratioPercent(weld, sum),
      cutRatioPercent: ratioPercent(cut, sum),
      cleanRatioPercent: ratioPercent(clean, sum),
      laserOnNumber: laser.number,
      laserOnUnit: laser.unit,
      wireNumber: wire.number,
      wireUnit: wire.unit,
      jobRuntimeNumber: job.number,
      jobRuntimeUnit: job.unit,
    );
  }
}

/// Truncated portion/total percent; 0 when either side is non-positive.
int ratioPercent(int portionSeconds, int totalSeconds) {
  if (totalSeconds <= 0 || portionSeconds <= 0) {
    return 0;
  }
  return (portionSeconds * 100 / totalSeconds).truncate();
}
