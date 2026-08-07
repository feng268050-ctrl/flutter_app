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
    final ratios = ratioPercents(weld: weld, cut: cut, clean: clean);
    return WorkInformationDisplay(
      weldRatioPercent: ratios.weld,
      cutRatioPercent: ratios.cut,
      cleanRatioPercent: ratios.clean,
      laserOnNumber: laser.number,
      laserOnUnit: laser.unit,
      wireNumber: wire.number,
      wireUnit: wire.unit,
      jobRuntimeNumber: job.number,
      jobRuntimeUnit: job.unit,
    );
  }
}

/// Weld / cut / clean integer percents that always sum to 100 when [sum] > 0.
///
/// Plain truncation (lws-ui `Home.newRatio`) can leave 98–99% on real totals
/// (e.g. board sample 2247/72/102 → 92+2+4). Largest-remainder distributes the
/// leftover points by fractional part so Monitor Work Info gauges add to 100%.
({int weld, int cut, int clean}) ratioPercents({
  required int weld,
  required int cut,
  required int clean,
}) {
  final sum = weld + cut + clean;
  if (sum <= 0) {
    return (weld: 0, cut: 0, clean: 0);
  }
  final parts = <int>[weld, cut, clean];
  final floors = List<int>.generate(3, (i) {
    if (parts[i] <= 0) {
      return 0;
    }
    return (parts[i] * 100 / sum).truncate();
  });
  var rem = 100 - floors.fold<int>(0, (a, b) => a + b);
  if (rem <= 0) {
    return (weld: floors[0], cut: floors[1], clean: floors[2]);
  }
  final fracs = List<double>.generate(3, (i) {
    if (parts[i] <= 0) {
      return -1;
    }
    return (parts[i] * 100 / sum) - floors[i];
  });
  final order = <int>[0, 1, 2]
    ..sort((a, b) {
      final c = fracs[b].compareTo(fracs[a]);
      if (c != 0) {
        return c;
      }
      // Stable tie-break: larger absolute portion first.
      return parts[b].compareTo(parts[a]);
    });
  for (final i in order) {
    if (rem <= 0) {
      break;
    }
    if (parts[i] <= 0) {
      continue;
    }
    floors[i]++;
    rem--;
  }
  return (weld: floors[0], cut: floors[1], clean: floors[2]);
}

/// Truncated portion/total percent; 0 when either side is non-positive.
///
/// Prefer [ratioPercents] when all three Work Info gauges must sum to 100.
int ratioPercent(int portionSeconds, int totalSeconds) {
  if (totalSeconds <= 0 || portionSeconds <= 0) {
    return 0;
  }
  return (portionSeconds * 100 / totalSeconds).truncate();
}
