import 'dart:convert';

/// Unified device WebSocket envelope (`v` / `type` / `id` / `ts` / `payload`).
final class DeviceWsEnvelope {
  const DeviceWsEnvelope({
    required this.v,
    required this.type,
    required this.id,
    required this.ts,
    this.payload,
  });

  final int v;
  final String type;
  final String id;
  final int ts;
  final Object? payload;

  static const otaTypes = <String>{
    'command.check_update',
    'command.update_system',
    'device.update_progress',
  };

  bool get isOtaRelated => otaTypes.contains(type);

  Map<String, Object?> toJson() => {
        'v': v,
        'type': type,
        'id': id,
        'ts': ts,
        if (payload != null) 'payload': payload,
      };

  String encode() => jsonEncode(toJson());

  static DeviceWsEnvelope? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final map = Map<String, dynamic>.from(decoded);
      final type = map['type']?.toString();
      if (type == null || type.isEmpty) {
        return null;
      }
      final v = map['v'] is num ? (map['v'] as num).toInt() : 1;
      // lws-ui: PROTOCOL_VERSION must be 1.
      if (v != 1) {
        return null;
      }
      final id = map['id']?.toString() ?? '';
      final ts = map['ts'] is num
          ? (map['ts'] as num).toInt()
          : DateTime.now().millisecondsSinceEpoch;
      return DeviceWsEnvelope(
        v: v,
        type: type,
        id: id,
        ts: ts,
        payload: map['payload'],
      );
    } catch (_) {
      return null;
    }
  }

  static DeviceWsEnvelope build({
    required String type,
    String? id,
    Object? payload,
    int v = 1,
  }) {
    return DeviceWsEnvelope(
      v: v,
      type: type,
      id: id ??
          'hmi-${DateTime.now().millisecondsSinceEpoch}-'
              '${type.hashCode.abs()}',
      ts: DateTime.now().millisecondsSinceEpoch,
      payload: payload,
    );
  }
}
