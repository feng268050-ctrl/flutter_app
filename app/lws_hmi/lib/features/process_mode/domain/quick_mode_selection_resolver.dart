import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';

/// Resolves Quick Mode gear / thickness (or swing width) after mode or material
/// switch — port of lws-ui `QuickModeSelectionResolver`.
abstract final class QuickModeSelectionResolver {
  static T? preferCarryThenLocal<T>(T? carry, T? local) => carry ?? local;

  static int indexOfGear(List<int> list, int? preferredGear) {
    if (preferredGear == null) {
      return -1;
    }
    return list.indexOf(preferredGear);
  }

  static int indexOfDimension(
    List<double> list,
    double? preferred,
  ) {
    if (preferred == null) {
      return -1;
    }
    final preferredKey = dimensionKey(preferred);
    for (var i = 0; i < list.length; i++) {
      if (dimensionKey(list[i]) == preferredKey) {
        return i;
      }
    }
    return -1;
  }

  /// Picks a right-dimension index that inherits [preferred] when a matching
  /// process row exists for [gear]; otherwise the first dimension that pairs
  /// with that gear.
  static int resolveDimensionIndex({
    required List<double> dimensionList,
    required List<ProcessPreset> dataList,
    required MaterialType? materialType,
    required int? gear,
    required double? preferred,
    required bool swingWidth,
  }) {
    if (dimensionList.isEmpty) {
      return 0;
    }
    final preferredIndex = indexOfDimension(dimensionList, preferred);
    if (preferredIndex >= 0 &&
        hasProcessRow(
          dataList: dataList,
          materialType: materialType,
          gear: gear,
          dimensionValue: dimensionList[preferredIndex],
          swingWidth: swingWidth,
        )) {
      return preferredIndex;
    }
    for (var i = 0; i < dimensionList.length; i++) {
      if (hasProcessRow(
        dataList: dataList,
        materialType: materialType,
        gear: gear,
        dimensionValue: dimensionList[i],
        swingWidth: swingWidth,
      )) {
        return i;
      }
    }
    return 0;
  }

  static bool hasProcessRow({
    required List<ProcessPreset> dataList,
    required MaterialType? materialType,
    required int? gear,
    required double? dimensionValue,
    required bool swingWidth,
  }) {
    if (gear == null) {
      return false;
    }
    final want = dimensionKey(dimensionValue);
    for (final row in dataList) {
      if (row.materialType != materialType) {
        continue;
      }
      if (row.gear != gear) {
        continue;
      }
      final got = swingWidth
          ? dimensionKey(row.parameters.values['process.swing_width'])
          : dimensionKey(row.thickness);
      if (got == want) {
        return true;
      }
    }
    return false;
  }

  static double dimensionKey(double? value) => value ?? 0;

  static double? swingWidthOf(ProcessPreset preset) =>
      preset.parameters.values['process.swing_width'];
}
