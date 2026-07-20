import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:cyber_hal/src/linux/lws_trace.dart';
import 'package:cyber_hal/src/modbus/modbus_config.dart';
import 'package:cyber_hal/src/modbus/modbus_crc.dart';
import 'package:cyber_hal/src/modbus/posix_serial_port.dart';

/// Low-level Modbus RTU transport (FC 0x03 / 0x04 / 0x06 / 0x10).
///
/// Linux prefers [PosixSerialPort] because Buildroot libserialport 0.1.1 hits
/// ENOTTY on kernel 6.1+; [SerialPort] remains a non-Linux / fallback path.
class ModbusRtuTransport {
  ModbusRtuTransport(this.transport);

  final ModbusTransport transport;

  PosixSerialPort? _posix;
  SerialPort? _libserial;
  bool _openFailed = false;

  bool get isOpen =>
      (_posix?.isOpen ?? false) || (_libserial?.isOpen == true);

  Future<bool> open() async {
    if (isOpen) {
      return true;
    }
    if (_openFailed) {
      return false;
    }

    final path = transport.device;
    final baud = transport.baud;
    final dataBits = transport.dataBits;
    final stopBits = transport.stopBits;
    final parityOn = transport.parity.toLowerCase() != 'none';

    if (Platform.isLinux) {
      final posix = PosixSerialPort(path);
      if (await posix.open(
        baudRate: baud,
        dataBits: dataBits,
        stopBits: stopBits,
        parity: parityOn,
      )) {
        _posix = posix;
        return true;
      }
      posix.close();
      // Do not fall back to libserialport on Linux: its timed read/write can
      // block the UI isolate. Posix O_NONBLOCK + await is the appliance path.
      debugPrint(
        'Modbus: PosixSerialPort open failed for $path; '
        'not using libserialport on Linux',
      );
      _openFailed = true;
      return false;
    }

    try {
      debugPrint(
        'Modbus: opening $path via libserialport; '
        'available=${SerialPort.availablePorts}',
      );
      final port = SerialPort(path);
      if (!port.openReadWrite()) {
        debugPrint(
          'Modbus: openReadWrite failed: ${SerialPort.lastError}',
        );
        port.dispose();
        _openFailed = true;
        return false;
      }
      port.config = SerialPortConfig()
        ..baudRate = baud
        ..bits = dataBits
        ..stopBits = stopBits
        ..parity = parityOn ? SerialPortParity.even : SerialPortParity.none
        ..setFlowControl(SerialPortFlowControl.none);
      _libserial = port;
      debugPrint('Modbus: opened $path @ $baud 8N1');
      return true;
    } catch (e, st) {
      debugPrint('Modbus: open exception: $e\n$st');
      debugPrint('Modbus: lastError=${SerialPort.lastError}');
      _openFailed = true;
      _disposePort();
      return false;
    }
  }

  Future<void> close() async {
    _disposePort();
    _openFailed = false;
  }

  void _disposePort() {
    final posix = _posix;
    _posix = null;
    posix?.close();

    final port = _libserial;
    _libserial = null;
    if (port == null) {
      return;
    }
    try {
      if (port.isOpen) {
        port.close();
      }
    } catch (_) {}
    try {
      port.dispose();
    } catch (_) {}
  }

  Future<List<int>?> readInputRegisters(int startAddress, int count) =>
      _readRegisters(functionCode: 0x04, startAddress: startAddress, count: count);

  Future<List<int>?> readHoldingRegisters(int startAddress, int count) =>
      _readRegisters(functionCode: 0x03, startAddress: startAddress, count: count);

  Future<bool> writeSingleRegister(int address, int value) async {
    if (!isOpen && !await open()) {
      return false;
    }
    final unit = transport.unitId & 0xFF;
    final request = appendModbusCrc(<int>[
      unit,
      0x06,
      (address >> 8) & 0xFF,
      address & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
    await _readChunk(256, timeoutMs: 1);
    final written =
        await _writeChunk(Uint8List.fromList(request), timeoutMs: 200);
    if (written != request.length) {
      return false;
    }
    final expectedLen = 8;
    final buffer = <int>[];
    final deadline =
        DateTime.now().add(Duration(milliseconds: transport.timeoutMs));
    while (buffer.length < expectedLen && DateTime.now().isBefore(deadline)) {
      final chunk =
          await _readChunk(expectedLen - buffer.length, timeoutMs: 50);
      if (chunk.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        continue;
      }
      buffer.addAll(chunk);
    }
    if (buffer.length < expectedLen ||
        !verifyModbusCrc(buffer.sublist(0, expectedLen))) {
      return false;
    }
    return buffer[0] == unit && buffer[1] == 0x06;
  }

  /// FC 0x10 — write one or more contiguous holding registers.
  Future<bool> writeMultipleRegisters(int startAddress, List<int> values) async {
    if (values.isEmpty) {
      return false;
    }
    if (!isOpen && !await open()) {
      return false;
    }
    final unit = transport.unitId & 0xFF;
    final count = values.length;
    final byteCount = count * 2;
    final frame = <int>[
      unit,
      0x10,
      (startAddress >> 8) & 0xFF,
      startAddress & 0xFF,
      (count >> 8) & 0xFF,
      count & 0xFF,
      byteCount & 0xFF,
    ];
    for (final v in values) {
      final word = v & 0xFFFF;
      frame.add((word >> 8) & 0xFF);
      frame.add(word & 0xFF);
    }
    final request = appendModbusCrc(frame);
    await _readChunk(256, timeoutMs: 1);
    final written =
        await _writeChunk(Uint8List.fromList(request), timeoutMs: 200);
    if (written != request.length) {
      return false;
    }
    // Normal response: unit, FC, start hi/lo, count hi/lo, CRC → 8 bytes.
    const expectedLen = 8;
    final buffer = <int>[];
    final deadline =
        DateTime.now().add(Duration(milliseconds: transport.timeoutMs));
    while (buffer.length < expectedLen && DateTime.now().isBefore(deadline)) {
      final chunk =
          await _readChunk(expectedLen - buffer.length, timeoutMs: 50);
      if (chunk.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        continue;
      }
      buffer.addAll(chunk);
      if (buffer.length >= 5 && (buffer[1] & 0x80) != 0) {
        if (buffer.length >= 5 && verifyModbusCrc(buffer.sublist(0, 5))) {
          return false;
        }
      }
    }
    if (buffer.length < expectedLen ||
        !verifyModbusCrc(buffer.sublist(0, expectedLen))) {
      return false;
    }
    if (buffer[0] != unit || buffer[1] != 0x10) {
      return false;
    }
    final respStart = (buffer[2] << 8) | buffer[3];
    final respCount = (buffer[4] << 8) | buffer[5];
    return respStart == startAddress && respCount == count;
  }

  Future<List<int>?> _readRegisters({
    required int functionCode,
    required int startAddress,
    required int count,
  }) async {
    if (!isOpen && !await open()) {
      return null;
    }

    final unit = transport.unitId & 0xFF;
    final request = appendModbusCrc(<int>[
      unit,
      functionCode,
      (startAddress >> 8) & 0xFF,
      startAddress & 0xFF,
      (count >> 8) & 0xFF,
      count & 0xFF,
    ]);

    await _readChunk(256, timeoutMs: 1);

    final written = await _writeChunk(
      Uint8List.fromList(request),
      timeoutMs: 200,
    );
    if (written != request.length) {
      debugPrint('Modbus: short write $written/${request.length}');
      return null;
    }
    lwsTrace(
      'Modbus: TX ${request.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );

    final expectedLen = 5 + count * 2;
    final buffer = <int>[];
    final deadline =
        DateTime.now().add(Duration(milliseconds: transport.timeoutMs));

    while (buffer.length < expectedLen && DateTime.now().isBefore(deadline)) {
      final chunk =
          await _readChunk(expectedLen - buffer.length, timeoutMs: 50);
      if (chunk.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        continue;
      }
      buffer.addAll(chunk);
      if (buffer.length >= 5 && (buffer[1] & 0x80) != 0) {
        if (buffer.length >= 5 && verifyModbusCrc(buffer.sublist(0, 5))) {
          lwsTrace('Modbus: exception response $buffer');
          return null;
        }
      }
    }

    if (buffer.isNotEmpty) {
      lwsTrace(
        'Modbus: RX ${buffer.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );
    } else {
      lwsTrace('Modbus: RX <empty> (timeout)');
    }

    if (buffer.length < expectedLen ||
        !verifyModbusCrc(buffer.sublist(0, expectedLen))) {
      return null;
    }
    if (buffer[0] != unit || buffer[1] != functionCode) {
      return null;
    }
    final byteCount = buffer[2];
    if (byteCount != count * 2) {
      return null;
    }

    final values = <int>[];
    for (var i = 0; i < count; i++) {
      final hi = buffer[3 + i * 2];
      final lo = buffer[4 + i * 2];
      values.add((hi << 8) | lo);
    }
    return values;
  }

  Future<int> _writeChunk(Uint8List data, {required int timeoutMs}) async {
    final posix = _posix;
    if (posix != null) {
      return posix.write(data, timeoutMs: timeoutMs);
    }
    final port = _libserial;
    if (port == null || !port.isOpen) {
      return 0;
    }
    // Fallback only (non-Linux / Posix open failed). Prefer Posix on device.
    return port.write(data, timeout: timeoutMs);
  }

  Future<Uint8List> _readChunk(int maxBytes, {required int timeoutMs}) async {
    final posix = _posix;
    if (posix != null) {
      // One-shot O_NONBLOCK — framing waits are await Future.delayed above.
      return posix.read(maxBytes, timeoutMs: timeoutMs);
    }
    final port = _libserial;
    if (port == null || !port.isOpen) {
      return Uint8List(0);
    }
    try {
      return port.read(maxBytes, timeout: timeoutMs);
    } catch (_) {
      return Uint8List(0);
    }
  }
}
