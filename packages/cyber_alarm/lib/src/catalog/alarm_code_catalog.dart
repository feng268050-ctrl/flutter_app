import 'package:cyber_alarm/src/domain/alarm_code.dart';

/// Product alarm-code catalog (model + lookup). App seeds entries.
final class AlarmCodeCatalog {
  AlarmCodeCatalog([Iterable<AlarmCodeEntry>? entries]) {
    if (entries != null) {
      addAll(entries);
    }
  }

  final Map<String, AlarmCodeEntry> _byCode = {};

  void add(AlarmCodeEntry entry) {
    _byCode[entry.code] = entry;
  }

  void addAll(Iterable<AlarmCodeEntry> entries) {
    for (final e in entries) {
      add(e);
    }
  }

  bool contains(String code) => _byCode.containsKey(code);

  /// Resolve entry; soft-fail unknown with placeholder.
  AlarmCodeEntry resolve(String code, {String? labelHint}) {
    final hit = _byCode[code];
    if (hit != null) {
      return hit;
    }
    return AlarmCodeEntry.unknown(code, labelHint: labelHint);
  }

  Iterable<AlarmCodeEntry> get entries => _byCode.values;

  int get length => _byCode.length;

  /// Join helper: every [codes] from transport meta should exist (or soft).
  List<String> missingCodes(Iterable<String> codes) {
    final missing = <String>[];
    for (final c in codes) {
      if (c.isEmpty) {
        continue;
      }
      if (!_byCode.containsKey(c)) {
        missing.add(c);
      }
    }
    return missing;
  }
}
