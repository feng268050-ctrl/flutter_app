/// One historical rising-edge alarm row.
final class AlarmLogEntry {
  const AlarmLogEntry({
    required this.code,
    required this.title,
    required this.timestamp,
    this.label,
  });

  final String code;
  final String title;
  final DateTime timestamp;
  final String? label;

  String get displayLabel =>
      (label != null && label!.trim().isNotEmpty) ? label!.trim() : title;

  Map<String, Object?> toJson() => {
        'code': code,
        'title': title,
        'timestamp': timestamp.toUtc().toIso8601String(),
        if (label != null) 'label': label,
      };

  factory AlarmLogEntry.fromJson(Map<String, Object?> json) {
    return AlarmLogEntry(
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      label: json['label'] as String?,
    );
  }
}

/// Persist rising-edge history (App implements file/SQLite).
abstract interface class AlarmLogRepository {
  Future<void> insertRising(AlarmLogEntry entry);

  Future<List<AlarmLogEntry>> query({int? limit});

  Future<void> clear();

  /// Newest-first snapshot stream for Monitor.
  Stream<List<AlarmLogEntry>> watch({int? limit});
}
