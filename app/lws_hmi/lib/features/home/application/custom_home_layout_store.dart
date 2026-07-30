import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/home/domain/custom_home_layout.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// Persists only card order. Statistics remain in the aggregate SQLite row.
final class CustomHomeLayoutStore extends ChangeNotifier {
  CustomHomeLayoutStore({String? preferencePath})
      : preferencePath =
            preferencePath ?? '${OsPaths.varHmi}/custom-home-layout.json';

  final String preferencePath;
  List<CustomHomeMetric> _metrics = List.of(CustomHomeLayout.defaults);

  List<CustomHomeMetric> get metrics => List.unmodifiable(_metrics);

  void warmRead() {
    try {
      final file = File(preferencePath);
      if (!file.existsSync()) return;
      _apply(jsonDecode(file.readAsStringSync()));
    } catch (error) {
      debugPrint('custom-home-layout: read failed: $error');
    }
  }

  Future<void> saveOrder(List<CustomHomeMetric> metrics) async {
    if (!_isValid(metrics)) return;
    _metrics = List.of(metrics);
    try {
      final file = File(preferencePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({
        'metrics': _metrics.map((metric) => metric.name).toList(),
      }));
    } catch (error) {
      debugPrint('custom-home-layout: save failed: $error');
      rethrow;
    }
    notifyListeners();
  }

  void _apply(Object? value) {
    if (value is! Map<String, dynamic> || value['metrics'] is! List) return;
    final parsed = <CustomHomeMetric>[];
    for (final raw in value['metrics'] as List) {
      if (raw is! String) return;
      final metric = CustomHomeMetric.values.where((e) => e.name == raw);
      if (metric.isEmpty) return;
      parsed.add(metric.first);
    }
    if (_isValid(parsed)) _metrics = parsed;
  }

  static bool _isValid(List<CustomHomeMetric> metrics) =>
      metrics.length == CustomHomeMetric.values.length &&
      metrics.toSet().length == CustomHomeMetric.values.length;
}
