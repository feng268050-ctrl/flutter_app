import 'dart:convert';

import 'package:cyber_hal/src/core/errors.dart';

/// How a single physical line is addressed at runtime.
enum GpioBindingScheme {
  /// `/dev/gpiochip*` via flutter_gpiod.
  gpiod,

  /// Sysfs value file (`path` and/or `label` under a class dir).
  /// JSON names: `sysfs_innohi`, `sysfs`, `sysfs_file`.
  sysfs,

  /// Classic `/sys/class/gpio` export via [GpioLineBinding.fallbackLinuxGpio].
  sysfsExport,

  /// In-memory (tests / sim).
  stub,
}

/// Parsed gpio config document (schema v1 lines and/or v2 devices).
final class GpioConfig {
  const GpioConfig({
    required this.version,
    required this.backend,
    required this.lines,
    required this.devices,
    this.defaults = const GpioDefaults(),
    this.capabilities = const GpioCapabilities(),
  });

  final int version;

  /// Document default scheme name (`gpiod`, `sysfs_innohi`, `stub`, …).
  final String backend;
  final List<GpioLineConfig> lines;
  final List<GpioDeviceConfig> devices;
  final GpioDefaults defaults;
  final GpioCapabilities capabilities;

  GpioBindingScheme get defaultScheme =>
      parseGpioBindingScheme(backend) ?? GpioBindingScheme.sysfs;

  GpioLineConfig? lineById(String id) {
    for (final line in lines) {
      if (line.id == id) return line;
    }
    return null;
  }

  GpioDeviceConfig? deviceById(String id) {
    for (final device in devices) {
      if (device.id == id) return device;
    }
    return null;
  }

  List<GpioDeviceConfig> devicesOfType(GpioDeviceType type) =>
      devices.where((d) => d.type == type).toList(growable: false);

  factory GpioConfig.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version is! int) {
      throw const HalIoException('gpio config missing version');
    }
    final backend = json['backend'] as String? ?? 'sysfs_innohi';
    final defaultsRaw = json['defaults'];
    final capsRaw = json['capabilities'];
    final defaults = defaultsRaw is Map<String, dynamic>
        ? GpioDefaults.fromJson(defaultsRaw)
        : const GpioDefaults();
    final capabilities = capsRaw is Map<String, dynamic>
        ? GpioCapabilities.fromJson(capsRaw)
        : const GpioCapabilities();

    final linesRaw = json['lines'];
    final devicesRaw = json['devices'];

    var lines = <GpioLineConfig>[];
    if (linesRaw is List) {
      lines = linesRaw
          .map((e) => GpioLineConfig.fromJson(
                e as Map<String, dynamic>,
                defaultScheme: parseGpioBindingScheme(backend),
              ))
          .toList();
    }

    var devices = <GpioDeviceConfig>[];
    if (devicesRaw is List) {
      devices = devicesRaw
          .map((e) => GpioDeviceConfig.fromJson(
                e as Map<String, dynamic>,
                defaultScheme: parseGpioBindingScheme(backend),
              ))
          .toList();
    }

    if (devices.isEmpty && lines.isNotEmpty) {
      devices = _synthesizeStatusLedFromLines(lines);
    }

    if (devices.isEmpty && lines.isEmpty) {
      throw const HalIoException('gpio config missing lines and devices');
    }

    // Ensure openLine ids exist for status-led channels (aliases + channel id).
    lines = _mergeLinesFromDevices(lines, devices);

    return GpioConfig(
      version: version,
      backend: backend,
      lines: lines,
      devices: devices,
      defaults: defaults,
      capabilities: capabilities,
    );
  }

  factory GpioConfig.fromJsonString(String source) =>
      GpioConfig.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

GpioBindingScheme? parseGpioBindingScheme(String? raw) {
  switch (raw) {
    case null:
    case '':
      return null;
    case 'gpiod':
      return GpioBindingScheme.gpiod;
    case 'sysfs_innohi':
    case 'sysfs':
    case 'sysfs_file':
      return GpioBindingScheme.sysfs;
    case 'sysfs_export':
      return GpioBindingScheme.sysfsExport;
    case 'stub':
      return GpioBindingScheme.stub;
    default:
      return null;
  }
}

List<GpioDeviceConfig> _synthesizeStatusLedFromLines(
  List<GpioLineConfig> lines,
) {
  final channels = <GpioStatusLedChannelConfig>[];
  for (final line in lines) {
    final isLed = line.id.startsWith('led_') ||
        line.roles.contains('indicator') ||
        line.roles.contains('alarm');
    if (!isLed) continue;
    final channelId = line.id.startsWith('led_')
        ? line.id.substring('led_'.length)
        : line.id;
    channels.add(
      GpioStatusLedChannelConfig(
        id: channelId,
        binding: line.binding,
        aliases: [line.id],
        roles: line.roles,
      ),
    );
  }
  if (channels.isEmpty) return const [];
  return [
    GpioDeviceConfig(
      type: GpioDeviceType.statusLed,
      id: 'chassis_rgb',
      statusLed: GpioStatusLedDeviceConfig(channels: channels),
    ),
  ];
}

List<GpioLineConfig> _mergeLinesFromDevices(
  List<GpioLineConfig> lines,
  List<GpioDeviceConfig> devices,
) {
  final byId = {for (final l in lines) l.id: l};
  void put(String id, GpioLineBinding binding, List<String> roles) {
    byId.putIfAbsent(
      id,
      () => GpioLineConfig(id: id, binding: binding, roles: roles),
    );
  }

  for (final device in devices) {
    switch (device.type) {
      case GpioDeviceType.statusLed:
        final led = device.statusLed;
        if (led == null) continue;
        for (final ch in led.channels) {
          final roles =
              ch.roles.isEmpty ? const ['indicator'] : ch.roles;
          put(ch.id, ch.binding, roles);
          for (final alias in ch.aliases) {
            put(alias, ch.binding, roles);
          }
        }
      case GpioDeviceType.buzzer:
        final line = device.buzzer?.line;
        if (line != null) put(device.id, line, const ['buzzer']);
      case GpioDeviceType.button:
        final line = device.button?.line;
        if (line != null) put(device.id, line, const ['button']);
      case GpioDeviceType.rotaryEncoder:
        final enc = device.rotaryEncoder;
        if (enc == null) continue;
        put('${device.id}_a', enc.a, const ['encoder']);
        put('${device.id}_b', enc.b, const ['encoder']);
    }
  }
  return byId.values.toList(growable: false);
}

final class GpioDefaults {
  const GpioDefaults({
    this.activeLow = false,
    this.blinkOnMs = 1000,
    this.blinkOffMs = 1000,
    this.buttonDebounceMs = 30,
    this.buttonLongPressMs = 800,
    this.encoderDebounceMs = 2,
  });

  final bool activeLow;
  final int blinkOnMs;
  final int blinkOffMs;
  final int buttonDebounceMs;
  final int buttonLongPressMs;
  final int encoderDebounceMs;

  factory GpioDefaults.fromJson(Map<String, dynamic> json) => GpioDefaults(
        activeLow: json['active_low'] as bool? ?? false,
        blinkOnMs: json['blink_on_ms'] as int? ?? 1000,
        blinkOffMs: json['blink_off_ms'] as int? ?? 1000,
        buttonDebounceMs: json['button_debounce_ms'] as int? ?? 30,
        buttonLongPressMs: json['button_long_press_ms'] as int? ?? 800,
        encoderDebounceMs: json['encoder_debounce_ms'] as int? ?? 2,
      );
}

final class GpioCapabilities {
  const GpioCapabilities({
    this.setLevel = true,
    this.blink = true,
    this.readLevel = true,
    this.statusLed,
    this.buzzer,
    this.button,
    this.rotaryEncoder,
  });

  final bool setLevel;
  final bool blink;
  final bool readLevel;
  final bool? statusLed;
  final bool? buzzer;
  final bool? button;
  final bool? rotaryEncoder;

  factory GpioCapabilities.fromJson(Map<String, dynamic> json) =>
      GpioCapabilities(
        setLevel: json['set_level'] as bool? ?? true,
        blink: json['blink'] as bool? ?? true,
        readLevel: json['read_level'] as bool? ?? true,
        statusLed: json['status_led'] as bool?,
        buzzer: json['buzzer'] as bool?,
        button: json['button'] as bool?,
        rotaryEncoder: json['rotary_encoder'] as bool?,
      );

  bool allows(GpioDeviceType type) {
    switch (type) {
      case GpioDeviceType.statusLed:
        return statusLed ?? true;
      case GpioDeviceType.buzzer:
        return buzzer ?? true;
      case GpioDeviceType.button:
        return button ?? true;
      case GpioDeviceType.rotaryEncoder:
        return rotaryEncoder ?? true;
    }
  }
}

/// Physical addressing for one line (scheme chosen at runtime).
final class GpioLineBinding {
  const GpioLineBinding({
    required this.scheme,
    this.label,
    this.path,
    this.fallbackLinuxGpio,
    this.chip,
    this.chipLabel,
    this.offset,
    this.activeLow,
  });

  final GpioBindingScheme scheme;
  final String? label;
  final String? path;
  final int? fallbackLinuxGpio;
  final String? chip;
  final String? chipLabel;
  final int? offset;
  final bool? activeLow;

  factory GpioLineBinding.fromJson(
    Map<String, dynamic> json, {
    GpioBindingScheme? defaultScheme,
  }) {
    final nested = json['gpiod'];
    final nestedMap = nested is Map<String, dynamic> ? nested : null;

    final schemeRaw = json['scheme'] as String?;
    final scheme = parseGpioBindingScheme(schemeRaw) ??
        defaultScheme ??
        (json['path'] != null || json['label'] != null
            ? GpioBindingScheme.sysfs
            : (nestedMap != null || json['chip'] != null
                ? GpioBindingScheme.gpiod
                : GpioBindingScheme.sysfs));

    return GpioLineBinding(
      scheme: scheme,
      label: json['label'] as String?,
      path: json['path'] as String?,
      fallbackLinuxGpio: json['fallback_linux_gpio'] as int? ??
          json['linux_gpio'] as int?,
      chip: json['chip'] as String? ?? nestedMap?['chip'] as String?,
      chipLabel:
          json['chip_label'] as String? ?? nestedMap?['label'] as String?,
      offset: json['offset'] as int? ?? nestedMap?['offset'] as int?,
      activeLow: json['active_low'] as bool?,
    );
  }
}

final class GpioLineConfig {
  const GpioLineConfig({
    required this.id,
    required this.binding,
    this.roles = const [],
  });

  final String id;
  final GpioLineBinding binding;
  final List<String> roles;

  String? get label => binding.label;
  String? get path => binding.path;
  int? get fallbackLinuxGpio => binding.fallbackLinuxGpio;

  factory GpioLineConfig.fromJson(
    Map<String, dynamic> json, {
    GpioBindingScheme? defaultScheme,
  }) {
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) {
      throw const HalIoException('gpio line missing id');
    }
    return GpioLineConfig(
      id: id,
      binding: GpioLineBinding.fromJson(json, defaultScheme: defaultScheme),
      roles: (json['roles'] as List?)?.map((e) => '$e').toList() ?? const [],
    );
  }
}

enum GpioDeviceType { statusLed, buzzer, button, rotaryEncoder }

GpioDeviceType? parseGpioDeviceType(String? raw) {
  switch (raw) {
    case 'status_led':
      return GpioDeviceType.statusLed;
    case 'buzzer':
      return GpioDeviceType.buzzer;
    case 'button':
      return GpioDeviceType.button;
    case 'rotary_encoder':
      return GpioDeviceType.rotaryEncoder;
    default:
      return null;
  }
}

final class GpioDeviceConfig {
  const GpioDeviceConfig({
    required this.type,
    required this.id,
    this.statusLed,
    this.buzzer,
    this.button,
    this.rotaryEncoder,
  });

  final GpioDeviceType type;
  final String id;
  final GpioStatusLedDeviceConfig? statusLed;
  final GpioBuzzerDeviceConfig? buzzer;
  final GpioButtonDeviceConfig? button;
  final GpioRotaryEncoderDeviceConfig? rotaryEncoder;

  factory GpioDeviceConfig.fromJson(
    Map<String, dynamic> json, {
    GpioBindingScheme? defaultScheme,
  }) {
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) {
      throw const HalIoException('gpio device missing id');
    }
    final type = parseGpioDeviceType(json['type'] as String?);
    if (type == null) {
      throw HalIoException('gpio device $id missing or unknown type');
    }

    switch (type) {
      case GpioDeviceType.statusLed:
        final channelsRaw = json['channels'];
        if (channelsRaw is! List || channelsRaw.isEmpty) {
          throw HalIoException('status_led $id missing channels');
        }
        final channels = channelsRaw
            .map((e) => GpioStatusLedChannelConfig.fromJson(
                  e as Map<String, dynamic>,
                  defaultScheme: defaultScheme,
                ))
            .toList();
        return GpioDeviceConfig(
          type: type,
          id: id,
          statusLed: GpioStatusLedDeviceConfig(channels: channels),
        );
      case GpioDeviceType.buzzer:
        final lineRaw = json['line'];
        if (lineRaw is! Map<String, dynamic>) {
          throw HalIoException('buzzer $id missing line');
        }
        return GpioDeviceConfig(
          type: type,
          id: id,
          buzzer: GpioBuzzerDeviceConfig(
            line: GpioLineBinding.fromJson(
              lineRaw,
              defaultScheme: defaultScheme,
            ),
          ),
        );
      case GpioDeviceType.button:
        final lineRaw = json['line'];
        if (lineRaw is! Map<String, dynamic>) {
          throw HalIoException('button $id missing line');
        }
        return GpioDeviceConfig(
          type: type,
          id: id,
          button: GpioButtonDeviceConfig(
            line: GpioLineBinding.fromJson(
              lineRaw,
              defaultScheme: defaultScheme,
            ),
            debounceMs: json['debounce_ms'] as int?,
            longPressMs: json['long_press_ms'] as int?,
          ),
        );
      case GpioDeviceType.rotaryEncoder:
        final aRaw = json['a'];
        final bRaw = json['b'];
        if (aRaw is! Map<String, dynamic> || bRaw is! Map<String, dynamic>) {
          throw HalIoException('rotary_encoder $id missing a/b');
        }
        return GpioDeviceConfig(
          type: type,
          id: id,
          rotaryEncoder: GpioRotaryEncoderDeviceConfig(
            a: GpioLineBinding.fromJson(aRaw, defaultScheme: defaultScheme),
            b: GpioLineBinding.fromJson(bRaw, defaultScheme: defaultScheme),
            debounceMs: json['debounce_ms'] as int?,
            invert: json['invert'] as bool? ?? false,
          ),
        );
    }
  }
}

final class GpioStatusLedDeviceConfig {
  const GpioStatusLedDeviceConfig({required this.channels});

  final List<GpioStatusLedChannelConfig> channels;

  GpioStatusLedChannelConfig? channelById(String id) {
    for (final ch in channels) {
      if (ch.id == id || ch.aliases.contains(id)) return ch;
    }
    return null;
  }
}

final class GpioStatusLedChannelConfig {
  const GpioStatusLedChannelConfig({
    required this.id,
    required this.binding,
    this.aliases = const [],
    this.roles = const [],
  });

  final String id;
  final GpioLineBinding binding;
  final List<String> aliases;
  final List<String> roles;

  factory GpioStatusLedChannelConfig.fromJson(
    Map<String, dynamic> json, {
    GpioBindingScheme? defaultScheme,
  }) {
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) {
      throw const HalIoException('status_led channel missing id');
    }
    return GpioStatusLedChannelConfig(
      id: id,
      binding: GpioLineBinding.fromJson(json, defaultScheme: defaultScheme),
      aliases:
          (json['aliases'] as List?)?.map((e) => '$e').toList() ?? const [],
      roles: (json['roles'] as List?)?.map((e) => '$e').toList() ?? const [],
    );
  }
}

final class GpioBuzzerDeviceConfig {
  const GpioBuzzerDeviceConfig({required this.line});

  final GpioLineBinding line;
}

final class GpioButtonDeviceConfig {
  const GpioButtonDeviceConfig({
    required this.line,
    this.debounceMs,
    this.longPressMs,
  });

  final GpioLineBinding line;
  final int? debounceMs;
  final int? longPressMs;
}

final class GpioRotaryEncoderDeviceConfig {
  const GpioRotaryEncoderDeviceConfig({
    required this.a,
    required this.b,
    this.debounceMs,
    this.invert = false,
  });

  final GpioLineBinding a;
  final GpioLineBinding b;
  final int? debounceMs;
  final bool invert;
}
