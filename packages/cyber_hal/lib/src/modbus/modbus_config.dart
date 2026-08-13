import 'dart:convert';

import 'package:cyber_hal/src/core/errors.dart';

/// Parsed modbus config document (schema v1).
final class ModbusConfig {
  const ModbusConfig({
    required this.version,
    required this.transport,
    required this.attributes,
    this.capabilities = const ModbusCapabilities(),
    this.poll = const ModbusPollConfig(),
    this.groups = const {},
  });

  final int version;
  final ModbusTransport transport;
  final List<ModbusAttributeConfig> attributes;
  final ModbusCapabilities capabilities;
  final ModbusPollConfig poll;
  final Map<String, ModbusGroupConfig> groups;

  ModbusAttributeConfig? attributeById(String id) {
    for (final a in attributes) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Effective remind interval for [attr], or null if reminders disabled.
  int? remindIntervalMsFor(ModbusAttributeConfig attr) {
    final policy = poll.alarmRemind;
    if (!policy.enabled) return null;
    final meta = attr.meta;
    if (meta?.remindIntervalMs != null) {
      final v = meta!.remindIntervalMs!;
      return v > 0 ? v : null;
    }
    // Default reminders only for attributes tagged with an alarm_code.
    if (meta?.alarmCode != null && policy.defaultIntervalMs > 0) {
      return policy.defaultIntervalMs;
    }
    return null;
  }

  ModbusGroupConfig? groupById(String id) => groups[id];

  /// Attributes belonging to [groupId] (explicit `group` or register range).
  List<ModbusAttributeConfig> attributesForGroup(String groupId) {
    final group = groups[groupId];
    if (group == null) return const [];
    final end = group.start + group.count;
    return attributes.where((a) {
      if (a.group == groupId) return true;
      if (a.group != null) return false;
      return a.register.space.toLowerCase() == group.space.toLowerCase() &&
          a.register.address >= group.start &&
          a.register.address < end;
    }).toList();
  }

  factory ModbusConfig.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version is! int) {
      throw const HalIoException('modbus config missing version');
    }
    final transportRaw = json['transport'];
    if (transportRaw is! Map<String, dynamic>) {
      throw const HalIoException('modbus config missing transport');
    }
    final attrsRaw = json['attributes'];
    if (attrsRaw is! List) {
      throw const HalIoException('modbus config missing attributes');
    }
    final capsRaw = json['capabilities'];
    final pollRaw = json['poll'];
    final groupsRaw = json['groups'];

    final groups = <String, ModbusGroupConfig>{};
    if (groupsRaw is Map<String, dynamic>) {
      for (final entry in groupsRaw.entries) {
        final value = entry.value;
        if (value is! Map<String, dynamic>) {
          throw HalIoException('modbus group ${entry.key} invalid');
        }
        groups[entry.key] = ModbusGroupConfig.fromJson(entry.key, value);
      }
    }

    return ModbusConfig(
      version: version,
      transport: ModbusTransport.fromJson(transportRaw),
      attributes: attrsRaw
          .map((e) => ModbusAttributeConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      capabilities: capsRaw is Map<String, dynamic>
          ? ModbusCapabilities.fromJson(capsRaw)
          : const ModbusCapabilities(),
      poll: pollRaw is Map<String, dynamic>
          ? ModbusPollConfig.fromJson(pollRaw)
          : const ModbusPollConfig(),
      groups: groups,
    );
  }

  factory ModbusConfig.fromJsonString(String source) =>
      ModbusConfig.fromJson(jsonDecode(source) as Map<String, dynamic>);

  /// Board helper override for the RTU serial path (sim USB-serial, etc.).
  ModbusConfig withTransportDevice(String device) {
    if (device.isEmpty || device == transport.device) return this;
    return ModbusConfig(
      version: version,
      transport: ModbusTransport(
        type: transport.type,
        device: device,
        baud: transport.baud,
        dataBits: transport.dataBits,
        parity: transport.parity,
        stopBits: transport.stopBits,
        unitId: transport.unitId,
        timeoutMs: transport.timeoutMs,
        commandIntervalMs: transport.commandIntervalMs,
      ),
      attributes: attributes,
      capabilities: capabilities,
      poll: poll,
      groups: groups,
    );
  }
}

final class ModbusTransport {
  const ModbusTransport({
    required this.type,
    required this.device,
    required this.baud,
    this.dataBits = 8,
    this.parity = 'none',
    this.stopBits = 1,
    this.unitId = 1,
    this.timeoutMs = 500,
    this.commandIntervalMs = 50,
  });

  final String type;
  final String device;
  final int baud;
  final int dataBits;
  final String parity;
  final int stopBits;
  final int unitId;
  final int timeoutMs;
  final int commandIntervalMs;

  factory ModbusTransport.fromJson(Map<String, dynamic> json) {
    final device = json['device'] as String?;
    final baud = json['baud'] as int?;
    if (device == null || baud == null) {
      throw const HalIoException('modbus transport missing device/baud');
    }
    return ModbusTransport(
      type: json['type'] as String? ?? 'rtu',
      device: device,
      baud: baud,
      dataBits: json['data_bits'] as int? ?? 8,
      parity: json['parity'] as String? ?? 'none',
      stopBits: json['stop_bits'] as int? ?? 1,
      unitId: json['unit_id'] as int? ?? 1,
      timeoutMs: json['timeout_ms'] as int? ?? 500,
      commandIntervalMs: json['command_interval_ms'] as int? ?? 50,
    );
  }
}

final class ModbusCapabilities {
  const ModbusCapabilities({
    this.readHolding = false,
    this.readInput = true,
    this.writeSingle = false,
    this.writeMultiple,
  });

  final bool readHolding;
  final bool readInput;
  final bool writeSingle;
  final bool? writeMultiple;

  factory ModbusCapabilities.fromJson(Map<String, dynamic> json) =>
      ModbusCapabilities(
        readHolding: json['read_holding'] as bool? ?? false,
        readInput: json['read_input'] as bool? ?? true,
        writeSingle: json['write_single'] as bool? ?? false,
        writeMultiple: json['write_multiple'] as bool?,
      );
}

final class ModbusPollConfig {
  const ModbusPollConfig({
    this.intervalMs = 100,
    this.discardIfBusy = true,
    this.health,
    this.alarmRemind = const ModbusAlarmRemindConfig(),
  });

  final int intervalMs;
  final bool discardIfBusy;
  final ModbusHealthWindowConfig? health;

  /// Default timed re-notify while alarm-like attributes stay active.
  final ModbusAlarmRemindConfig alarmRemind;

  factory ModbusPollConfig.fromJson(Map<String, dynamic> json) {
    final healthRaw = json['health'];
    final remindRaw = json['alarm_remind'];
    return ModbusPollConfig(
      intervalMs: json['interval_ms'] as int? ?? 100,
      discardIfBusy: json['discard_if_busy'] as bool? ?? true,
      health: healthRaw is Map<String, dynamic>
          ? ModbusHealthWindowConfig.fromJson(healthRaw)
          : null,
      alarmRemind: remindRaw is Map<String, dynamic>
          ? ModbusAlarmRemindConfig.fromJson(remindRaw)
          : const ModbusAlarmRemindConfig(),
    );
  }
}

/// Global default for alarm attribute reminders (overridable per attribute meta).
final class ModbusAlarmRemindConfig {
  const ModbusAlarmRemindConfig({
    this.enabled = false,
    this.defaultIntervalMs = 30000,
  });

  final bool enabled;

  /// Used when an attribute has no `meta.remind_interval_ms` but has `alarm_code`
  /// (or explicit remind). `0` disables default reminders.
  final int defaultIntervalMs;

  factory ModbusAlarmRemindConfig.fromJson(Map<String, dynamic> json) =>
      ModbusAlarmRemindConfig(
        enabled: json['enabled'] as bool? ?? false,
        defaultIntervalMs: json['default_interval_ms'] as int? ?? 30000,
      );
}

final class ModbusHealthWindowConfig {
  const ModbusHealthWindowConfig({
    this.windowSize = 5,
    this.failureThreshold = 3,
    this.mode = 'slide_window',
  });

  /// Legacy JSON `window_size`. Ignored: consecutive [failureThreshold] is
  /// the only slide_window gate (kept so older assets still parse).
  final int windowSize;

  /// For `slide_window`: consecutive trailing failures required to mark
  /// unhealthy. For `immediate`: unused (any latest failure trips).
  final int failureThreshold;

  /// `slide_window` (default) or `immediate`.
  final String mode;

  ModbusHealthWindowConfig copyWith({
    int? windowSize,
    int? failureThreshold,
    String? mode,
  }) {
    return ModbusHealthWindowConfig(
      windowSize: windowSize ?? this.windowSize,
      failureThreshold: failureThreshold ?? this.failureThreshold,
      mode: mode ?? this.mode,
    );
  }

  factory ModbusHealthWindowConfig.fromJson(Map<String, dynamic> json) =>
      ModbusHealthWindowConfig(
        windowSize: json['window_size'] as int? ?? 5,
        failureThreshold: json['failure_threshold'] as int? ?? 3,
        mode: json['mode'] as String? ?? 'slide_window',
      );
}

final class ModbusGroupConfig {
  const ModbusGroupConfig({
    required this.id,
    required this.space,
    required this.start,
    required this.count,
    required this.mode,
    this.chain,
  });

  final String id;
  final String space;
  final int start;
  final int count;
  final String mode; // continuous | on_demand
  final String? chain;

  bool get isContinuous => mode.toLowerCase() == 'continuous';

  factory ModbusGroupConfig.fromJson(String id, Map<String, dynamic> json) {
    final space = json['space'] as String? ?? 'input';
    final start = parseModbusAddress(json['start']);
    final count = json['count'] as int?;
    if (count == null || count <= 0) {
      throw HalIoException('modbus group $id missing count');
    }
    final mode = json['mode'] as String? ?? 'continuous';
    return ModbusGroupConfig(
      id: id,
      space: space,
      start: start,
      count: count,
      mode: mode,
      chain: json['chain'] as String?,
    );
  }
}

final class ModbusAttributeConfig {
  const ModbusAttributeConfig({
    required this.id,
    required this.access,
    required this.register,
    required this.decode,
    this.group,
    this.meta,
  });

  final String id;
  final String access;
  final ModbusRegisterBinding register;
  final ModbusDecode decode;
  final String? group;
  final ModbusAttributeMeta? meta;

  factory ModbusAttributeConfig.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) {
      throw const HalIoException('modbus attribute missing id');
    }
    final register = json['register'];
    final decode = json['decode'];
    if (register is! Map<String, dynamic> || decode is! Map<String, dynamic>) {
      throw HalIoException('modbus attribute $id missing register/decode');
    }
    final metaRaw = json['meta'];
    return ModbusAttributeConfig(
      id: id,
      access: json['access'] as String? ?? 'r',
      register: ModbusRegisterBinding.fromJson(register),
      decode: ModbusDecode.fromJson(decode),
      group: json['group'] as String?,
      meta: metaRaw is Map<String, dynamic>
          ? ModbusAttributeMeta.fromJson(metaRaw)
          : null,
    );
  }
}

final class ModbusAttributeMeta {
  const ModbusAttributeMeta({
    this.label,
    this.alarmCode,
    this.remindIntervalMs,
  });

  final String? label;
  final String? alarmCode;

  /// While value stays active, re-emit watch events at this interval (ms).
  /// `null` → use [ModbusAlarmRemindConfig.defaultIntervalMs] when [alarmCode]
  /// is set; `0` → no reminder for this attribute.
  final int? remindIntervalMs;

  factory ModbusAttributeMeta.fromJson(Map<String, dynamic> json) =>
      ModbusAttributeMeta(
        label: json['label'] as String?,
        alarmCode: json['alarm_code'] as String?,
        remindIntervalMs: json['remind_interval_ms'] as int?,
      );
}

final class ModbusRegisterBinding {
  const ModbusRegisterBinding({
    required this.space,
    required this.address,
    this.count = 1,
  });

  final String space;
  final int address;
  final int count;

  factory ModbusRegisterBinding.fromJson(Map<String, dynamic> json) {
    final space = json['space'] as String? ?? 'input';
    return ModbusRegisterBinding(
      space: space,
      address: parseModbusAddress(json['address']),
      count: json['count'] as int? ?? 1,
    );
  }
}

final class ModbusDecode {
  const ModbusDecode({
    required this.type,
    this.scale,
    this.unit,
    this.bit,
    this.activeHigh = true,
  });

  final String type;
  final num? scale;
  final String? unit;
  final int? bit;
  final bool activeHigh;

  factory ModbusDecode.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    if (type == null || type.isEmpty) {
      throw const HalIoException('modbus decode missing type');
    }
    return ModbusDecode(
      type: type,
      scale: json['scale'] as num?,
      unit: json['unit'] as String?,
      bit: json['bit'] as int?,
      activeHigh: json['active_high'] as bool? ?? true,
    );
  }
}

/// Parse decimal or `0x`/`0X` hex address fields.
int parseModbusAddress(Object? raw) {
  if (raw is int) {
    return raw;
  }
  if (raw is String) {
    if (raw.startsWith('0x') || raw.startsWith('0X')) {
      return int.parse(raw.substring(2), radix: 16);
    }
    return int.parse(raw);
  }
  throw const HalIoException('modbus register missing address');
}
