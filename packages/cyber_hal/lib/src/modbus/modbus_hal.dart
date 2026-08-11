import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:cyber_hal/src/core/errors.dart';
import 'package:cyber_hal/src/modbus/modbus_config.dart';
import 'package:cyber_hal/src/modbus/modbus_format.dart';
import 'package:cyber_hal/src/modbus/modbus_rtu_transport.dart';
import 'package:cyber_hal/src/profile/board_profile.dart';

/// One attribute whose decoded value changed, was primed, or is a timed reminder.
final class ModbusAttributeChange {
  const ModbusAttributeChange({
    required this.id,
    required this.value,
    this.previous,
    this.kind = ModbusChangeKind.changed,
  });

  final String id;
  final Object? value;
  final Object? previous;

  /// [ModbusChangeKind.reminder] means value is still active and HAL re-notified
  /// after [ModbusAttributeMeta.remindIntervalMs] / poll default — not a value edge.
  final ModbusChangeKind kind;

  bool get isReminder => kind == ModbusChangeKind.reminder;

  @override
  String toString() =>
      'ModbusAttributeChange($kind $id: $previous → $value)';
}

/// Why a watch item was emitted.
enum ModbusChangeKind {
  /// First snapshot after subscribe (`previous` is null).
  primed,

  /// Decoded value differed from cache.
  changed,

  /// Value still "active" (e.g. alarm bool true); timed re-notify for product UX.
  reminder,
}

/// Per-group (or aggregate) read health for C001-class UI input.
final class ModbusHealth {
  const ModbusHealth({
    this.groupId,
    required this.ok,
    this.truncated = false,
    this.message,
  });

  final String? groupId;
  final bool ok;
  final bool truncated;
  final String? message;

  @override
  String toString() =>
      'ModbusHealth(group=$groupId ok=$ok truncated=$truncated msg=$message)';
}

/// Config-driven Modbus HAL (attribute catalog + RTU transport + poll/watch).
abstract class ModbusHal {
  ModbusConfig get config;

  List<ModbusAttributeConfig> listAttributes();

  Future<Object?> readAttribute(String id);

  Future<void> writeAttribute(String id, Object? value);

  /// Write contiguous holding registers (FC16) at [address] without group merge/read.
  ///
  /// Used for control-board OTA frames that must match lws-ui length (info ≈10
  /// words, data = header+payload, end ≈14) — not the full catalog group span.
  Future<void> writeHoldingRegisters(int address, List<int> words);

  /// Decoded attribute id → value for attributes in [groupId].
  Future<Map<String, Object?>> readGroup(String groupId);

  /// Encode [values] (attribute id → decoded value) into the group word map and
  /// write contiguous holding registers (FC16). Unspecified attributes keep
  /// last-read / zero-filled words when a prior group cache exists or a read
  /// succeeds; otherwise unset words are written as `0`.
  Future<void> writeGroup(String groupId, Map<String, Object?> values);

  /// Start continuous group polling.
  ///
  /// Idempotent while already polling: a second call on the same instance is a
  /// no-op (does not restart the timer or change [groupIds]). After
  /// [stopPolling], a later [startPolling] may start again (e.g. exclusive
  /// session resume).
  Future<void> startPolling({Iterable<String>? groupIds});

  Future<void> stopPolling();

  /// Change-only attribute stream. Never emits an empty list.
  ///
  /// First emission after subscribe is a prime of current cache
  /// (`previous == null`) when cache is non-empty; otherwise waits for the
  /// next successful poll cycle.
  Stream<List<ModbusAttributeChange>> watchAttributes({
    Iterable<String>? ids,
  });

  Stream<ModbusHealth> watchHealth();

  /// Override [ModbusHealthWindowConfig.mode] at runtime (`slide_window` /
  /// Runtime mode string (`slide_window` | `immediate`). Product Apps may feed
  /// this from opaque properties.ini keys.
  ///
  /// Pass `null` or empty to clear the override and use config JSON again.
  void applyHealthWindowMode(String? mode);

  /// Pause poll, run [body], restart poll if it was active.
  Future<T> exclusiveSession<T>(Future<T> Function() body);

  Future<void> close();

  factory ModbusHal.fromConfig(
    ModbusConfig config, {
    ModbusRtuTransport? transport,
  }) = _LinuxModbusHal;

  /// Load JSON from a filesystem path (async — no `readAsStringSync`).
  static Future<ModbusHal> fromConfigFile(
    String path, {
    ModbusRtuTransport? transport,
  }) async {
    final source = await File(path).readAsString();
    return ModbusHal.fromConfig(
      ModbusConfig.fromJsonString(source),
      transport: transport,
    );
  }

  /// Load JSON from a Flutter asset (product App typically owns `modbus.json`).
  static Future<ModbusHal> fromAsset({
    required String asset,
    AssetBundle? bundle,
  }) async {
    final source = await (bundle ?? rootBundle).loadString(asset);
    return ModbusHal.fromConfig(ModbusConfig.fromJsonString(source));
  }

  /// Prefer [BoardProfile.resolvedModbusAsset] when set (D22).
  /// Applies optional [BoardHelperKeys.modbusRtuDevice] over the asset transport.
  static Future<ModbusHal> fromProfile(
    BoardProfile profile, {
    AssetBundle? bundle,
  }) async {
    final asset = profile.resolvedModbusAsset;
    if (asset == null || asset.isEmpty) {
      throw const HalIoException(
        'board profile missing configs.modbus asset path',
      );
    }
    final source = await (bundle ?? rootBundle).loadString(asset);
    var config = ModbusConfig.fromJsonString(source);
    final deviceOverride = profile.helper(BoardHelperKeys.modbusRtuDevice);
    if (deviceOverride != null && deviceOverride.isNotEmpty) {
      config = config.withTransportDevice(deviceOverride);
    }
    return ModbusHal.fromConfig(config);
  }
}

/// Device-information slice (ynh960 Demo attribute ids).
class ModbusDeviceInfoSnapshot {
  const ModbusDeviceInfoSnapshot({
    required this.gunheadSn,
    required this.controlCardVersion,
    required this.laserVersion,
    required this.wireFeederVersion,
  });

  final String gunheadSn;
  final String controlCardVersion;
  final String laserVersion;
  final String wireFeederVersion;

  static const ModbusDeviceInfoSnapshot unavailable = ModbusDeviceInfoSnapshot(
    gunheadSn: kModbusUnavailableDisplay,
    controlCardVersion: kModbusUnavailableDisplay,
    laserVersion: kModbusUnavailableDisplay,
    wireFeederVersion: kModbusUnavailableDisplay,
  );
}

/// Welding-gun sensor temperatures (ynh960 Demo attribute ids).
class ModbusAlarmTemperaturesSnapshot {
  const ModbusAlarmTemperaturesSnapshot({
    required this.motorTemperature,
    required this.motorDriverTemperature,
    required this.protectiveMirrorTemperature,
    required this.collimatorTemperature,
  });

  final String motorTemperature;
  final String motorDriverTemperature;
  final String protectiveMirrorTemperature;
  final String collimatorTemperature;

  static const ModbusAlarmTemperaturesSnapshot unavailable =
      ModbusAlarmTemperaturesSnapshot(
    motorTemperature: kModbusUnavailableDisplay,
    motorDriverTemperature: kModbusUnavailableDisplay,
    protectiveMirrorTemperature: kModbusUnavailableDisplay,
    collimatorTemperature: kModbusUnavailableDisplay,
  );
}

/// ynh960-oriented helpers over [ModbusHal] attribute ids (not register addresses).
extension Ynh960ModbusReads on ModbusHal {
  Future<ModbusDeviceInfoSnapshot> readDeviceInfo() async {
    try {
      final controlCard = await readAttribute('device.control_card_version');
      final laser = await readAttribute('device.laser_sw_version');
      final wire = await readAttribute('device.wire_feeder_sw_version');
      final sn = await readAttribute('device.gun_head_sn');
      if (controlCard == null || laser == null || wire == null || sn == null) {
        return ModbusDeviceInfoSnapshot.unavailable;
      }
      return ModbusDeviceInfoSnapshot(
        controlCardVersion: decimalRegister(controlCard as int),
        laserVersion: laser as String,
        wireFeederVersion: decimalRegister(wire as int),
        gunheadSn: sn as String,
      );
    } catch (_) {
      return ModbusDeviceInfoSnapshot.unavailable;
    }
  }

  Future<ModbusAlarmTemperaturesSnapshot> readAlarmTemperatures() async {
    try {
      final motor = await readAttribute('telemetry.gun_motor_temp');
      final drive = await readAttribute('telemetry.gun_motor_drive_temp');
      final cover = await readAttribute('telemetry.protective_cover_temp');
      final collimator = await readAttribute('telemetry.collimator_temp');
      if (motor == null || drive == null || cover == null || collimator == null) {
        return ModbusAlarmTemperaturesSnapshot.unavailable;
      }
      // Config decode may apply scale 0.1; display helper accepts raw or scaled.
      return ModbusAlarmTemperaturesSnapshot(
        motorTemperature: formatTemperatureDisplay(motor),
        motorDriverTemperature: formatTemperatureDisplay(drive),
        protectiveMirrorTemperature: formatTemperatureDisplay(cover),
        collimatorTemperature: formatTemperatureDisplay(collimator),
      );
    } catch (_) {
      return ModbusAlarmTemperaturesSnapshot.unavailable;
    }
  }
}

final class _AttrCacheEntry {
  _AttrCacheEntry(this.value);

  Object? value;
}

final class _GroupWordCache {
  _GroupWordCache({
    required this.start,
    required this.words,
  });

  final int start;
  final List<int> words;
}

final class _WatchListener {
  _WatchListener({
    required this.ids,
    required this.controller,
  });

  final Set<String>? ids;
  final StreamController<List<ModbusAttributeChange>> controller;
  bool primed = false;

  /// Attribute ids already pushed to this subscriber (prime / change / catch-up).
  ///
  /// Needed when the first prime only covers a subset of the cache (e.g. status
  /// group before data) and later polls see unchanged values — without catch-up
  /// those attrs would never be delivered until they change.
  final Set<String> deliveredIds = {};
}

final class _LinuxModbusHal implements ModbusHal {
  _LinuxModbusHal(this.config, {ModbusRtuTransport? transport})
      : _rtu = transport ?? ModbusRtuTransport(config.transport);

  @override
  final ModbusConfig config;

  final ModbusRtuTransport _rtu;

  final Map<String, _AttrCacheEntry> _attrCache = {};
  final Map<String, _GroupWordCache> _groupWords = {};
  final List<_WatchListener> _watchers = [];
  final StreamController<ModbusHealth> _healthController =
      StreamController<ModbusHealth>.broadcast();

  Timer? _pollTimer;
  List<String>? _pollGroupIds;
  bool _polling = false;
  bool _cycleBusy = false;
  bool _exclusive = false;
  bool _commandBusy = false;

  /// Serializes [exclusiveSession] so concurrent callers cannot nest
  /// stop/start polling (nested sessions used to leave polling permanently off).
  Future<void> _exclusiveChain = Future<void>.value();

  /// Recent group-cycle outcomes for slide_window health (true = failure).
  final List<bool> _healthFailures = [];

  /// Runtime override for [ModbusHealthWindowConfig.mode] (App-supplied).
  String? _healthModeOverride;

  /// Last watch emit time per attribute (edge or reminder) for remind intervals.
  final Map<String, DateTime> _lastNotifyAt = {};

  @override
  List<ModbusAttributeConfig> listAttributes() =>
      List.unmodifiable(config.attributes);

  @override
  Future<Object?> readAttribute(String id) async {
    final attr = config.attributeById(id);
    if (attr == null) {
      throw HalNotFoundException('modbus attribute not found: $id');
    }
    if (attr.access != 'r' && attr.access != 'rw') {
      throw HalUnsupportedException('modbus attribute $id is not readable');
    }

    final cachedWords = _wordsForAttribute(attr);
    if (cachedWords != null) {
      return _decode(attr, cachedWords);
    }

    final words = await _readRegisters(
      space: attr.register.space,
      start: attr.register.address,
      count: attr.register.count,
    );
    if (words == null || words.isEmpty) {
      throw const HalIoException('modbus read failed');
    }
    final value = _decode(attr, words);
    _attrCache[id] = _AttrCacheEntry(value);
    return value;
  }

  @override
  Future<void> writeAttribute(String id, Object? value) async {
    final attr = config.attributeById(id);
    if (attr == null) {
      throw HalNotFoundException('modbus attribute not found: $id');
    }
    if (attr.access != 'w' && attr.access != 'rw') {
      throw HalUnsupportedException('modbus attribute $id is not writable');
    }
    if (attr.register.space.toLowerCase() != 'holding') {
      throw const HalUnsupportedException(
        'modbus write only supported for holding registers',
      );
    }
    final canSingle = config.capabilities.writeSingle;
    final canMultiple = config.capabilities.writeMultiple == true;
    if (!canSingle && !canMultiple) {
      throw const HalUnsupportedException(
        'modbus write_single/write_multiple not advertised',
      );
    }

    final words = await _encodeAttributeWords(attr, value);
    _commandBusy = true;
    try {
      final ok = await _writeHolding(attr.register.address, words);
      if (!ok) {
        throw const HalIoException('modbus write failed');
      }
      _attrCache[id] = _AttrCacheEntry(value);
      _patchGroupCache(attr, words);
      // field_1 / bit RMW writes share one holding word — refresh sibling
      // bit attrs so watch primes do not resurrect a stale off/on.
      _refreshOverlappingAttrCache(attr, words);
    } finally {
      _commandBusy = false;
    }
  }

  @override
  Future<void> writeHoldingRegisters(int address, List<int> words) async {
    if (words.isEmpty) {
      return;
    }
    if (config.capabilities.writeMultiple != true) {
      throw const HalUnsupportedException(
        'modbus write_multiple not advertised',
      );
    }
    final normalized = [for (final w in words) w & 0xFFFF];
    _commandBusy = true;
    try {
      final ok = await _writeHolding(address, normalized);
      if (!ok) {
        throw const HalIoException('modbus writeHoldingRegisters failed');
      }
    } finally {
      _commandBusy = false;
    }
  }

  @override
  Future<void> writeGroup(String groupId, Map<String, Object?> values) async {
    final group = config.groupById(groupId);
    if (group == null) {
      throw HalNotFoundException('modbus group not found: $groupId');
    }
    if (group.space.toLowerCase() != 'holding') {
      throw const HalUnsupportedException(
        'modbus writeGroup only supported for holding groups',
      );
    }
    if (config.capabilities.writeMultiple != true) {
      throw const HalUnsupportedException(
        'modbus write_multiple not advertised',
      );
    }
    if (values.isEmpty) {
      return;
    }

    var base = List<int>.filled(group.count, 0);
    final cached = _groupWords[groupId];
    if (cached != null && cached.words.length >= group.count) {
      base = List<int>.from(cached.words.take(group.count));
    } else if (config.capabilities.readHolding) {
      final read = await _readRegisters(
        space: group.space,
        start: group.start,
        count: group.count,
      );
      if (read != null && read.length >= group.count) {
        base = List<int>.from(read.take(group.count));
      }
    }

    for (final entry in values.entries) {
      final attr = config.attributeById(entry.key);
      if (attr == null) {
        throw HalNotFoundException('modbus attribute not found: ${entry.key}');
      }
      if (attr.access != 'w' && attr.access != 'rw') {
        throw HalUnsupportedException(
          'modbus attribute ${entry.key} is not writable',
        );
      }
      if (attr.group != null && attr.group != groupId) {
        throw HalIoException(
          'modbus attribute ${entry.key} is not in group $groupId',
        );
      }
      if (attr.register.space.toLowerCase() != group.space.toLowerCase()) {
        throw HalIoException(
          'modbus attribute ${entry.key} space mismatch for group $groupId',
        );
      }
      final offset = attr.register.address - group.start;
      if (offset < 0 || offset + attr.register.count > group.count) {
        throw HalIoException(
          'modbus attribute ${entry.key} outside group $groupId range',
        );
      }
      final encoded = await _encodeAttributeWords(
        attr,
        entry.value,
        baseWord: base[offset],
      );
      for (var i = 0; i < encoded.length; i++) {
        base[offset + i] = encoded[i];
      }
      _attrCache[attr.id] = _AttrCacheEntry(entry.value);
    }

    _commandBusy = true;
    try {
      final ok = await _writeHolding(group.start, base);
      if (!ok) {
        throw const HalIoException('modbus writeGroup failed');
      }
      _groupWords[groupId] = _GroupWordCache(start: group.start, words: base);
      _syncAttrCacheFromGroupWords(groupId);
    } finally {
      _commandBusy = false;
    }
  }

  @override
  Future<Map<String, Object?>> readGroup(String groupId) async {
    final group = config.groupById(groupId);
    if (group == null) {
      throw HalNotFoundException('modbus group not found: $groupId');
    }
    final words = await _readRegisters(
      space: group.space,
      start: group.start,
      count: group.count,
    );
    if (words == null || words.length < group.count) {
      // On-demand reads must not drive C001; only continuous poll health does.
      throw const HalIoException('modbus group read failed');
    }
    _groupWords[groupId] = _GroupWordCache(start: group.start, words: words);
    final result = <String, Object?>{};
    for (final attr in config.attributesForGroup(groupId)) {
      final slice = _sliceWords(words, group.start, attr);
      if (slice == null) continue;
      final value = _decode(attr, slice);
      _attrCache[attr.id] = _AttrCacheEntry(value);
      result[attr.id] = value;
    }
    // readGroup updates cache without producing poll dirty sets — flush any
    // undelivered watched attrs so late watchers / partial primes catch up.
    if (_watchers.isNotEmpty) {
      _dispatchWatch(const [], hadSuccessfulRead: true);
    }
    return result;
  }

  @override
  Future<void> startPolling({Iterable<String>? groupIds}) async {
    // One active poll scheduler per HAL instance. Do not stop+restart.
    if (_polling) {
      return;
    }
    final ordered = _resolveContinuousOrder(groupIds);
    if (ordered.isEmpty) {
      return;
    }
    _pollGroupIds = List<String>.from(ordered);
    _polling = true;
    final interval = Duration(milliseconds: config.poll.intervalMs);
    _pollTimer = Timer.periodic(interval, (_) {
      unawaited(_pollCycle());
    });
    // Kick an immediate cycle so watchers do not wait a full interval.
    unawaited(_pollCycle());
  }

  @override
  Future<void> stopPolling() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _polling = false;
    _pollGroupIds = null;
    // Wait briefly if a cycle is mid-flight.
    var spins = 0;
    while (_cycleBusy && spins < 50) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      spins++;
    }
  }

  @override
  Stream<List<ModbusAttributeChange>> watchAttributes({
    Iterable<String>? ids,
  }) {
    late final StreamController<List<ModbusAttributeChange>> controller;
    late final _WatchListener listener;
    controller = StreamController<List<ModbusAttributeChange>>.broadcast(
      onListen: () {
        final prime = _buildPrime(listener.ids);
        if (prime != null && prime.isNotEmpty) {
          listener.primed = true;
          _markDelivered(listener, prime);
          controller.add(prime);
        }
      },
      onCancel: () {
        _watchers.remove(listener);
      },
    );
    listener = _WatchListener(
      ids: ids?.toSet(),
      controller: controller,
    );
    _watchers.add(listener);
    return controller.stream;
  }

  @override
  Stream<ModbusHealth> watchHealth() => _healthController.stream;

  @override
  Future<T> exclusiveSession<T>(Future<T> Function() body) {
    final gate = Completer<void>();
    final previous = _exclusiveChain;
    _exclusiveChain = gate.future;
    return previous.catchError((_) {}).then((_) async {
      final wasPolling = _polling;
      final groups = _pollGroupIds == null
          ? null
          : List<String>.from(_pollGroupIds!);
      _exclusive = true;
      await stopPolling();
      try {
        return await body();
      } finally {
        _exclusive = false;
        try {
          if (wasPolling) {
            await startPolling(groupIds: groups);
          }
        } finally {
          if (!gate.isCompleted) {
            gate.complete();
          }
        }
      }
    });
  }

  @override
  Future<void> close() async {
    await stopPolling();
    for (final w in List<_WatchListener>.from(_watchers)) {
      await w.controller.close();
    }
    _watchers.clear();
    await _healthController.close();
    await _rtu.close();
  }

  Future<void> _pollCycle() async {
    if (!_polling) return;
    if (_exclusive || _cycleBusy || _commandBusy) {
      if (config.poll.discardIfBusy) return;
    }
    final groups = _pollGroupIds;
    if (groups == null || groups.isEmpty) return;

    _cycleBusy = true;
    final cycleChanges = <ModbusAttributeChange>[];
    var anyGroupOk = false;
    var anyGroupFail = false;

    try {
      for (var i = 0; i < groups.length; i++) {
        if (!_polling || _exclusive) break;
        final groupId = groups[i];
        final group = config.groupById(groupId);
        if (group == null) continue;

        final words = await _readRegisters(
          space: group.space,
          start: group.start,
          count: group.count,
        );

        if (words == null || words.length < group.count) {
          anyGroupFail = true;
          _recordHealthFailure(true);
        } else {
          anyGroupOk = true;
          _recordHealthFailure(false);
          _groupWords[groupId] = _GroupWordCache(
            start: group.start,
            words: words,
          );
          cycleChanges.addAll(_diffGroupAttributes(groupId, words));
        }

        if (i < groups.length - 1) {
          final gap = config.transport.commandIntervalMs;
          if (gap > 0) {
            await Future<void>.delayed(Duration(milliseconds: gap));
          }
        }
      }

      cycleChanges.addAll(_collectReminders());

      if (cycleChanges.isNotEmpty || anyGroupOk) {
        _dispatchWatch(cycleChanges, hadSuccessfulRead: anyGroupOk);
      }

      // C001 input: emit only aggregate window health (never per-group).
      _emitAggregateHealth(anySample: anyGroupOk || anyGroupFail);
    } finally {
      _cycleBusy = false;
    }
  }

  void _dispatchWatch(
    List<ModbusAttributeChange> dirty, {
    required bool hadSuccessfulRead,
  }) {
    if (_watchers.isEmpty) return;
    for (final w in List<_WatchListener>.from(_watchers)) {
      if (w.controller.isClosed) continue;
      if (!w.primed) {
        if (!hadSuccessfulRead && _attrCache.isEmpty) continue;
        final prime = _buildPrime(w.ids);
        if (prime != null && prime.isNotEmpty) {
          w.primed = true;
          _markDelivered(w, prime);
          w.controller.add(prime);
        }
        continue;
      }
      final filtered = _filterChanges(dirty, w.ids);
      final catchUp = _catchUpUndelivered(w);
      final batch = _mergeWatchBatch(filtered, catchUp);
      if (batch.isNotEmpty) {
        _markDelivered(w, batch);
        w.controller.add(batch);
      }
    }
  }

  List<ModbusAttributeChange>? _buildPrime(Set<String>? ids) {
    if (_attrCache.isEmpty) return null;
    final out = <ModbusAttributeChange>[];
    final now = DateTime.now();
    for (final entry in _attrCache.entries) {
      if (ids != null && !ids.contains(entry.key)) continue;
      out.add(
        ModbusAttributeChange(
          id: entry.key,
          value: entry.value.value,
          previous: null,
          kind: ModbusChangeKind.primed,
        ),
      );
      if (_isActiveAlarmValue(entry.value.value)) {
        _lastNotifyAt[entry.key] = now;
      }
    }
    return out.isEmpty ? null : out;
  }

  /// Cached attrs in [w]'s filter that were never pushed to this subscriber.
  List<ModbusAttributeChange> _catchUpUndelivered(_WatchListener w) {
    if (_attrCache.isEmpty) return const [];
    final out = <ModbusAttributeChange>[];
    final now = DateTime.now();
    for (final entry in _attrCache.entries) {
      if (w.ids != null && !w.ids!.contains(entry.key)) continue;
      if (w.deliveredIds.contains(entry.key)) continue;
      out.add(
        ModbusAttributeChange(
          id: entry.key,
          value: entry.value.value,
          previous: null,
          kind: ModbusChangeKind.primed,
        ),
      );
      if (_isActiveAlarmValue(entry.value.value)) {
        _lastNotifyAt[entry.key] = now;
      }
    }
    return out;
  }

  /// Prefer dirty (change/reminder) over catch-up for the same id.
  List<ModbusAttributeChange> _mergeWatchBatch(
    List<ModbusAttributeChange> dirty,
    List<ModbusAttributeChange> catchUp,
  ) {
    if (catchUp.isEmpty) return dirty;
    if (dirty.isEmpty) return catchUp;
    final dirtyIds = {for (final c in dirty) c.id};
    final merged = List<ModbusAttributeChange>.from(dirty);
    for (final c in catchUp) {
      if (!dirtyIds.contains(c.id)) {
        merged.add(c);
      }
    }
    return merged;
  }

  void _markDelivered(
    _WatchListener w,
    List<ModbusAttributeChange> batch,
  ) {
    for (final c in batch) {
      w.deliveredIds.add(c.id);
    }
  }

  List<ModbusAttributeChange> _filterChanges(
    List<ModbusAttributeChange> changes,
    Set<String>? ids,
  ) {
    if (ids == null) return changes;
    return changes.where((c) => ids.contains(c.id)).toList();
  }

  List<ModbusAttributeChange> _diffGroupAttributes(
    String groupId,
    List<int> words,
  ) {
    final group = config.groupById(groupId)!;
    final changes = <ModbusAttributeChange>[];
    final now = DateTime.now();
    for (final attr in config.attributesForGroup(groupId)) {
      final slice = _sliceWords(words, group.start, attr);
      if (slice == null) continue;
      final value = _decode(attr, slice);
      final prevEntry = _attrCache[attr.id];
      final previous = prevEntry?.value;
      _attrCache[attr.id] = _AttrCacheEntry(value);
      if (prevEntry == null || !_valuesEqual(previous, value)) {
        changes.add(
          ModbusAttributeChange(
            id: attr.id,
            value: value,
            previous: previous,
            kind: ModbusChangeKind.changed,
          ),
        );
        if (_isActiveAlarmValue(value)) {
          _lastNotifyAt[attr.id] = now;
        } else {
          _lastNotifyAt.remove(attr.id);
        }
      }
    }
    return changes;
  }

  /// Timed re-notify for attributes that stay active (alarm bool true).
  List<ModbusAttributeChange> _collectReminders() {
    if (!config.poll.alarmRemind.enabled) return const [];
    final now = DateTime.now();
    final out = <ModbusAttributeChange>[];
    for (final attr in config.attributes) {
      final intervalMs = config.remindIntervalMsFor(attr);
      if (intervalMs == null) continue;
      final cached = _attrCache[attr.id]?.value;
      if (!_isActiveAlarmValue(cached)) {
        _lastNotifyAt.remove(attr.id);
        continue;
      }
      final last = _lastNotifyAt[attr.id];
      if (last == null) {
        _lastNotifyAt[attr.id] = now;
        continue;
      }
      if (now.difference(last).inMilliseconds < intervalMs) continue;
      _lastNotifyAt[attr.id] = now;
      out.add(
        ModbusAttributeChange(
          id: attr.id,
          value: cached,
          previous: cached,
          kind: ModbusChangeKind.reminder,
        ),
      );
    }
    return out;
  }

  bool _isActiveAlarmValue(Object? value) => value == true;

  bool _valuesEqual(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is num && b is num) return a == b;
    return a == b;
  }

  List<String> _resolveContinuousOrder(Iterable<String>? groupIds) {
    final continuous = config.groups.entries
        .where((e) => e.value.isContinuous)
        .map((e) => e.key)
        .toSet();
    final selected = groupIds == null
        ? continuous
        : continuous.intersection(groupIds.toSet());
    if (selected.isEmpty) return const [];

    final chainTargets = <String>{};
    for (final id in selected) {
      final chain = config.groups[id]?.chain;
      if (chain != null && selected.contains(chain)) {
        chainTargets.add(chain);
      }
    }
    final roots = selected.where((id) => !chainTargets.contains(id)).toList()
      ..sort();

    final ordered = <String>[];
    for (final root in roots) {
      String? cur = root;
      while (cur != null && selected.contains(cur) && !ordered.contains(cur)) {
        ordered.add(cur);
        cur = config.groups[cur]?.chain;
      }
    }
    return ordered;
  }

  List<int>? _wordsForAttribute(ModbusAttributeConfig attr) {
    // Prefer explicit group cache.
    final groupId = attr.group;
    if (groupId != null) {
      final cached = _groupWords[groupId];
      if (cached != null) {
        return _sliceWords(cached.words, cached.start, attr);
      }
    }
    // Fall back to any group whose range covers the register.
    for (final entry in _groupWords.entries) {
      final group = config.groupById(entry.key);
      if (group == null) continue;
      if (group.space.toLowerCase() != attr.register.space.toLowerCase()) {
        continue;
      }
      final end = group.start + group.count;
      if (attr.register.address >= group.start &&
          attr.register.address + attr.register.count <= end) {
        return _sliceWords(entry.value.words, entry.value.start, attr);
      }
    }
    return null;
  }

  List<int>? _sliceWords(
    List<int> words,
    int groupStart,
    ModbusAttributeConfig attr,
  ) {
    final offset = attr.register.address - groupStart;
    if (offset < 0 || offset + attr.register.count > words.length) {
      return null;
    }
    return words.sublist(offset, offset + attr.register.count);
  }

  Future<List<int>?> _readRegisters({
    required String space,
    required int start,
    required int count,
  }) async {
    final normalized = space.toLowerCase();
    _commandBusy = true;
    try {
      switch (normalized) {
        case 'input':
          if (!config.capabilities.readInput) {
            throw const HalUnsupportedException(
              'modbus read_input not advertised',
            );
          }
          return await _rtu.readInputRegisters(start, count);
        case 'holding':
          if (!config.capabilities.readHolding) {
            throw const HalUnsupportedException(
              'modbus read_holding not advertised',
            );
          }
          return await _rtu.readHoldingRegisters(start, count);
        default:
          throw HalUnsupportedException('modbus space not supported: $space');
      }
    } finally {
      _commandBusy = false;
    }
  }

  Future<bool> _writeHolding(int address, List<int> words) async {
    if (words.isEmpty) {
      return false;
    }
    final canSingle = config.capabilities.writeSingle;
    final canMultiple = config.capabilities.writeMultiple == true;
    if (words.length == 1 && canSingle && !canMultiple) {
      return _rtu.writeSingleRegister(address, words.first);
    }
    if (canMultiple) {
      return _rtu.writeMultipleRegisters(address, words);
    }
    if (canSingle && words.length == 1) {
      return _rtu.writeSingleRegister(address, words.first);
    }
    throw const HalUnsupportedException(
      'modbus write_multiple required for multi-register write',
    );
  }

  void _patchGroupCache(ModbusAttributeConfig attr, List<int> words) {
    final groupId = attr.group;
    if (groupId == null) return;
    final group = config.groupById(groupId);
    final cached = _groupWords[groupId];
    if (group == null || cached == null) return;
    final offset = attr.register.address - cached.start;
    if (offset < 0 || offset + words.length > cached.words.length) return;
    for (var i = 0; i < words.length; i++) {
      cached.words[i + offset] = words[i];
    }
  }

  /// Re-decode every attribute fully covered by [words] at [written]'s address.
  ///
  /// Writing `control.field_1` (u16) must also refresh `control.wire_manual_mode`
  /// and other bit siblings; otherwise [watchAttributes] primes from a stale
  /// bit cache while hardware already has the new word.
  void _refreshOverlappingAttrCache(
    ModbusAttributeConfig written,
    List<int> words,
  ) {
    final space = written.register.space.toLowerCase();
    final start = written.register.address;
    final end = start + words.length;
    for (final other in config.attributes) {
      if (other.register.space.toLowerCase() != space) {
        continue;
      }
      final oStart = other.register.address;
      final oCount = other.register.count;
      if (oStart < start || oStart + oCount > end) {
        continue;
      }
      final offset = oStart - start;
      final slice = words.sublist(offset, offset + oCount);
      _attrCache[other.id] = _AttrCacheEntry(_decode(other, slice));
    }
  }

  void _syncAttrCacheFromGroupWords(String groupId) {
    final cached = _groupWords[groupId];
    if (cached == null) {
      return;
    }
    for (final attr in config.attributesForGroup(groupId)) {
      final slice = _sliceWords(cached.words, cached.start, attr);
      if (slice == null) {
        continue;
      }
      _attrCache[attr.id] = _AttrCacheEntry(_decode(attr, slice));
    }
  }

  /// Encode a decoded attribute value into register word(s).
  ///
  /// For [bit] types, [baseWord] (or a fresh holding read) is RMW'd.
  Future<List<int>> _encodeAttributeWords(
    ModbusAttributeConfig attr,
    Object? value, {
    int? baseWord,
  }) async {
    final type = attr.decode.type.toLowerCase();
    switch (type) {
      case 'u16':
        return [_encodeScaledUnsigned(value, attr.decode.scale)];
      case 's16':
        return [_encodeScaledSigned(value, attr.decode.scale)];
      case 'u16_pair_be':
        if (value is! String) {
          throw HalIoException(
            'modbus u16_pair_be write expects hex string, got $value',
          );
        }
        return _encodeHexPair(value);
      case 'u16_array':
        if (value is! List) {
          throw HalIoException(
            'modbus u16_array write expects List<int>, got $value',
          );
        }
        if (value.length != attr.register.count) {
          throw HalIoException(
            'modbus u16_array length ${value.length} != ${attr.register.count}',
          );
        }
        return [
          for (final v in value)
            switch (v) {
              int i => i & 0xFFFF,
              num n => n.toInt() & 0xFFFF,
              _ => throw HalIoException('modbus u16_array element not int: $v'),
            },
        ];
      case 'bit':
        final bit = attr.decode.bit ?? 0;
        final active = switch (value) {
          bool b => b,
          int i => i != 0,
          num n => n != 0,
          _ => throw HalIoException(
              'modbus bit write expects bool, got $value',
            ),
        };
        final wantSet = attr.decode.activeHigh ? active : !active;
        var word = baseWord;
        if (word == null) {
          final cached = _wordsForAttribute(attr);
          if (cached != null && cached.isNotEmpty) {
            word = cached.first;
          } else {
            final read = await _readRegisters(
              space: attr.register.space,
              start: attr.register.address,
              count: 1,
            );
            word = (read != null && read.isNotEmpty) ? read.first : 0;
          }
        }
        final mask = 1 << bit;
        final next = wantSet ? (word | mask) : (word & ~mask);
        return [next & 0xFFFF];
      default:
        throw HalUnsupportedException(
          'modbus encode type not supported: $type',
        );
    }
  }

  int _encodeScaledUnsigned(Object? value, num? scale) {
    final raw = _unscaleToInt(value, scale);
    if (raw < 0 || raw > 0xFFFF) {
      throw HalIoException('modbus u16 encode out of range: $raw');
    }
    return raw & 0xFFFF;
  }

  int _encodeScaledSigned(Object? value, num? scale) {
    final raw = _unscaleToInt(value, scale);
    if (raw < -32768 || raw > 32767) {
      throw HalIoException('modbus s16 encode out of range: $raw');
    }
    return raw & 0xFFFF;
  }

  int _unscaleToInt(Object? value, num? scale) {
    final num n = switch (value) {
      int v => v,
      num v => v,
      _ => throw HalIoException('modbus encode expects num, got $value'),
    };
    if (scale == null || scale == 0 || scale == 1) {
      return n.round();
    }
    return (n / scale).round();
  }

  List<int> _encodeHexPair(String hex) {
    final cleaned = hex.trim().toLowerCase().replaceFirst(RegExp(r'^0x'), '');
    if (cleaned.isEmpty || cleaned.length > 8) {
      throw HalIoException('modbus u16_pair_be invalid hex: $hex');
    }
    final padded = cleaned.padLeft(8, '0');
    final high = int.parse(padded.substring(0, 4), radix: 16);
    final low = int.parse(padded.substring(4, 8), radix: 16);
    return [high & 0xFFFF, low & 0xFFFF];
  }

  @override
  void applyHealthWindowMode(String? mode) {
    final trimmed = mode?.trim() ?? '';
    if (trimmed.isEmpty) {
      _healthModeOverride = null;
      return;
    }
    if (trimmed != 'slide_window' && trimmed != 'immediate') {
      return;
    }
    _healthModeOverride = trimmed;
  }

  ModbusHealthWindowConfig? _effectiveHealthWindow() {
    final base = config.poll.health;
    if (base == null) {
      return null;
    }
    final override = _healthModeOverride;
    if (override == null || override == base.mode) {
      return base;
    }
    return base.copyWith(mode: override);
  }

  void _recordHealthFailure(bool failed) {
    final window = _effectiveHealthWindow();
    if (window == null) return;
    _healthFailures.add(failed);
    while (_healthFailures.length > window.windowSize) {
      _healthFailures.removeAt(0);
    }
  }

  bool _isWindowUnhealthy(ModbusHealthWindowConfig window) {
    if (window.mode == 'immediate') {
      return _healthFailures.isNotEmpty && _healthFailures.last;
    }
    if (_healthFailures.length < window.failureThreshold) return false;
    final failures = _healthFailures.where((f) => f).length;
    return failures >= window.failureThreshold;
  }

  void _emitAggregateHealth({required bool anySample}) {
    final window = _effectiveHealthWindow();
    if (window == null || !anySample) {
      return;
    }
    final unhealthy = _isWindowUnhealthy(window);
    final failCount = _healthFailures.where((f) => f).length;
    _emitHealth(
      ModbusHealth(
        ok: !unhealthy,
        truncated: unhealthy,
        message: unhealthy
            ? 'health window: $failCount/${window.windowSize} failures'
            : null,
      ),
    );
  }

  void _emitHealth(ModbusHealth health) {
    if (!_healthController.isClosed) {
      _healthController.add(health);
    }
  }

  Object? _decode(ModbusAttributeConfig attr, List<int> words) {
    final type = attr.decode.type.toLowerCase();
    switch (type) {
      case 'u16':
        final v = words.first & 0xFFFF;
        return _applyScale(v, attr.decode.scale);
      case 's16':
        final v = toSignedRegister16(words.first);
        return _applyScale(v, attr.decode.scale);
      case 'u16_pair_be':
        if (words.length < 2) {
          throw const HalIoException('modbus u16_pair_be needs 2 registers');
        }
        return hexConcatRegisters(words[0], words[1]);
      case 'u16_array':
        return [for (final w in words) w & 0xFFFF];
      case 'bit':
        final bit = attr.decode.bit ?? 0;
        final word = words.first & 0xFFFF;
        final set = ((word >> bit) & 1) == 1;
        return attr.decode.activeHigh ? set : !set;
      default:
        throw HalUnsupportedException(
          'modbus decode type not supported: $type',
        );
    }
  }

  Object _applyScale(num value, num? scale) {
    if (scale == null || scale == 1) {
      return value is int ? value : value.toInt();
    }
    return value * scale;
  }
}
