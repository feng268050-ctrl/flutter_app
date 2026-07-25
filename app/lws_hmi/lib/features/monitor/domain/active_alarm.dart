/// One active Modbus alarm for Monitor list UI.
final class ActiveAlarm {
  const ActiveAlarm({
    required this.id,
    required this.code,
    required this.label,
  });

  final String id;
  final String code;
  final String label;
}

/// Catalog meta used to render [ActiveAlarm] rows.
final class AlarmCatalogEntry {
  const AlarmCatalogEntry({
    required this.id,
    required this.code,
    required this.label,
  });

  final String id;
  final String code;
  final String label;
}
