import 'dart:convert';

import 'package:cyber_hal/src/core/errors.dart';

/// Parsed gpio config document (schema v1).
final class GpioConfig {
  const GpioConfig({
    required this.version,
    required this.backend,
    required this.lines,
    this.defaults = const GpioDefaults(),
    this.capabilities = const GpioCapabilities(),
  });

  final int version;
  final String backend;
  final List<GpioLineConfig> lines;
  final GpioDefaults defaults;
  final GpioCapabilities capabilities;

  GpioLineConfig? lineById(String id) {
    for (final line in lines) {
      if (line.id == id) return line;
    }
    return null;
  }

  factory GpioConfig.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version is! int) {
      throw const HalIoException('gpio config missing version');
    }
    final backend = json['backend'] as String? ?? 'sysfs_innohi';
    final linesRaw = json['lines'];
    if (linesRaw is! List) {
      throw const HalIoException('gpio config missing lines');
    }
    final lines = linesRaw
        .map((e) => GpioLineConfig.fromJson(e as Map<String, dynamic>))
        .toList();

    final defaultsRaw = json['defaults'];
    final capsRaw = json['capabilities'];

    return GpioConfig(
      version: version,
      backend: backend,
      lines: lines,
      defaults: defaultsRaw is Map<String, dynamic>
          ? GpioDefaults.fromJson(defaultsRaw)
          : const GpioDefaults(),
      capabilities: capsRaw is Map<String, dynamic>
          ? GpioCapabilities.fromJson(capsRaw)
          : const GpioCapabilities(),
    );
  }

  factory GpioConfig.fromJsonString(String source) =>
      GpioConfig.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

final class GpioDefaults {
  const GpioDefaults({
    this.activeLow = false,
    this.blinkOnMs = 1000,
    this.blinkOffMs = 1000,
  });

  final bool activeLow;
  final int blinkOnMs;
  final int blinkOffMs;

  factory GpioDefaults.fromJson(Map<String, dynamic> json) => GpioDefaults(
        activeLow: json['active_low'] as bool? ?? false,
        blinkOnMs: json['blink_on_ms'] as int? ?? 1000,
        blinkOffMs: json['blink_off_ms'] as int? ?? 1000,
      );
}

final class GpioCapabilities {
  const GpioCapabilities({
    this.setLevel = true,
    this.blink = true,
    this.readLevel = true,
  });

  final bool setLevel;
  final bool blink;
  final bool readLevel;

  factory GpioCapabilities.fromJson(Map<String, dynamic> json) =>
      GpioCapabilities(
        setLevel: json['set_level'] as bool? ?? true,
        blink: json['blink'] as bool? ?? true,
        readLevel: json['read_level'] as bool? ?? true,
      );
}

final class GpioLineConfig {
  const GpioLineConfig({
    required this.id,
    this.label,
    this.path,
    this.fallbackLinuxGpio,
    this.roles = const [],
  });

  final String id;
  final String? label;
  final String? path;
  final int? fallbackLinuxGpio;
  final List<String> roles;

  factory GpioLineConfig.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) {
      throw const HalIoException('gpio line missing id');
    }
    return GpioLineConfig(
      id: id,
      label: json['label'] as String?,
      path: json['path'] as String?,
      fallbackLinuxGpio: json['fallback_linux_gpio'] as int?,
      roles: (json['roles'] as List?)?.map((e) => '$e').toList() ?? const [],
    );
  }
}
