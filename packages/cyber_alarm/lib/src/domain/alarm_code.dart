/// Severity for warn presentation / future prioritization.
enum AlarmSeverity {
  critical,
  high,
  medium,
  low,
  unknown,
}

/// One product alarm code entry (dialog copy keys + severity).
final class AlarmCodeEntry {
  const AlarmCodeEntry({
    required this.code,
    required this.severity,
    required this.title,
    required this.body,
    this.label,
  });

  /// Stable product code (e.g. `H001`).
  final String code;

  final AlarmSeverity severity;

  /// Dialog title (or localization key resolved by App).
  final String title;

  /// Dialog body (or localization key resolved by App).
  final String body;

  /// Short list label; defaults to [title] when null.
  final String? label;

  String get displayLabel =>
      (label != null && label!.trim().isNotEmpty) ? label!.trim() : title;

  /// Soft-fail placeholder when catalog miss.
  factory AlarmCodeEntry.unknown(String code, {String? labelHint}) {
    final hint = labelHint?.trim();
    return AlarmCodeEntry(
      code: code,
      severity: AlarmSeverity.unknown,
      title: code,
      body: hint != null && hint.isNotEmpty
          ? hint
          : 'Unknown alarm $code',
      label: hint,
    );
  }
}
