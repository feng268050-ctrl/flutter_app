import 'package:lws_hmi/features/settings/application/length_unit_convert.dart';
import 'package:lws_hmi/features/statistics/domain/stats_aggregate_models.dart';

/// Derived Monitor Work Info values from [StatsAggregate].
///
/// Mirrors lws-ui `WorkInfoFragment` ← `Home.build` / `WireConsumptionDisplayUtil`
/// (ratios over weld+cut+clean; laser-on hours; wire m/ft; job runtime minutes).
final class WorkInformationDisplay {
  const WorkInformationDisplay({
    required this.weldRatioPercent,
    required this.cutRatioPercent,
    required this.cleanRatioPercent,
    required this.laserOnHours,
    required this.wireNumber,
    required this.wireUnit,
    required this.jobRuntimeMinutes,
  });

  final int weldRatioPercent;
  final int cutRatioPercent;
  final int cleanRatioPercent;

  /// Integer hours (`laserOnSecondsTotal ~/ 3600`).
  final String laserOnHours;

  /// Wire length number (metric mm/m or imperial feet).
  final String wireNumber;
  final String wireUnit;

  /// Integer minutes (`jobRuntimeSecondsTotal ~/ 60`).
  final String jobRuntimeMinutes;

  static const empty = WorkInformationDisplay(
    weldRatioPercent: 0,
    cutRatioPercent: 0,
    cleanRatioPercent: 0,
    laserOnHours: '0',
    wireNumber: '0',
    wireUnit: 'mm',
    jobRuntimeMinutes: '0',
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
        laserOnHours: '0',
        wireNumber: '0',
        wireUnit: wire.unit,
        jobRuntimeMinutes: '0',
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
    return WorkInformationDisplay(
      weldRatioPercent: ratioPercent(weld, sum),
      cutRatioPercent: ratioPercent(cut, sum),
      cleanRatioPercent: ratioPercent(clean, sum),
      laserOnHours: (laserOn < 0 ? 0 : laserOn ~/ 3600).toString(),
      wireNumber: wire.number,
      wireUnit: wire.unit,
      jobRuntimeMinutes: (aggregate.jobRuntimeSecondsTotal < 0
              ? 0
              : aggregate.jobRuntimeSecondsTotal ~/ 60)
          .toString(),
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
