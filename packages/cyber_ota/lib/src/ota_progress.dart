import 'ota_phase.dart';

/// Ingress source for an OTA session.
enum OtaIngressKind {
  cloud,
  host,
  local;

  String get wireName => name;

  static OtaIngressKind? fromWireName(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    for (final kind in OtaIngressKind.values) {
      if (kind.wireName == value) {
        return kind;
      }
    }
    return null;
  }
}

/// Progress snapshot emitted by [OtaSession] (UI / cloud WS).
final class OtaProgress {
  const OtaProgress({
    required this.phase,
    this.percent = 0,
    this.bytesReceived = 0,
    this.bytesTotal = 0,
    this.ingress,
    this.message = '',
    this.errorCode = '',
    this.updatedAtMs,
  });

  final OtaPhase phase;
  final int percent;
  final int bytesReceived;
  final int bytesTotal;
  final OtaIngressKind? ingress;
  final String message;
  final String errorCode;
  final int? updatedAtMs;

  OtaProgress copyWith({
    OtaPhase? phase,
    int? percent,
    int? bytesReceived,
    int? bytesTotal,
    OtaIngressKind? ingress,
    String? message,
    String? errorCode,
    int? updatedAtMs,
  }) {
    return OtaProgress(
      phase: phase ?? this.phase,
      percent: percent ?? this.percent,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      bytesTotal: bytesTotal ?? this.bytesTotal,
      ingress: ingress ?? this.ingress,
      message: message ?? this.message,
      errorCode: errorCode ?? this.errorCode,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toJson({int? updatedAtMsOverride}) {
    final ts = updatedAtMsOverride ?? updatedAtMs ?? DateTime.now().millisecondsSinceEpoch;
    return <String, dynamic>{
      'phase': phase.wireName,
      'percent': percent,
      'bytes_received': bytesReceived,
      'bytes_total': bytesTotal,
      if (ingress != null) 'ingress': ingress!.wireName,
      'message': message,
      'error_code': errorCode,
      'updated_at_ms': ts,
    };
  }

  factory OtaProgress.fromJson(Map<String, dynamic> json) {
    return OtaProgress(
      phase: OtaPhase.fromWireName(json['phase'] as String?) ?? OtaPhase.idle,
      percent: _asInt(json['percent']),
      bytesReceived: _asInt(json['bytes_received']),
      bytesTotal: _asInt(json['bytes_total']),
      ingress: OtaIngressKind.fromWireName(json['ingress'] as String?),
      message: json['message'] as String? ?? '',
      errorCode: json['error_code'] as String? ?? '',
      updatedAtMs: json['updated_at_ms'] as int?,
    );
  }

  static int _asInt(Object? value) {
    if (value == null) {
      return 0;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }
}
