import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:lws_hmi/device/display_value.dart';
import 'package:lws_hmi/modbus/modbus_crc.dart';
import 'package:lws_hmi/modbus/modbus_format.dart';
import 'package:lws_hmi/modbus/posix_serial_port.dart';
import 'package:lws_hmi/modbus/register_address.dart';
import 'package:lws_hmi/platform/lws_trace.dart';

/// Serial parameters mirrored from lws-ui `SerialPortConfig` (8-N-1, 115200).
class ModbusSerialConfig {
  static const String devicePath = '/dev/ttyS5';
  static const int baudRate = 115200;
  static const int dataBits = 8;
  static const int stopBits = 1;
  static const int slaveAddress = 0x01;
  static const Duration responseTimeout = Duration(milliseconds: 500);
}

/// Device-information slice read via Modbus input registers (FC 0x04).
class ModbusDeviceInfoSnapshot {
  const ModbusDeviceInfoSnapshot({
    required this.gunheadSn,
    required this.firmwareVersion,
    required this.laserVersion,
    required this.wireFeederVersion,
  });

  final String gunheadSn;
  final String firmwareVersion;
  final String laserVersion;
  final String wireFeederVersion;

  static const ModbusDeviceInfoSnapshot unavailable = ModbusDeviceInfoSnapshot(
    gunheadSn: kUnavailableDisplay,
    firmwareVersion: kUnavailableDisplay,
    laserVersion: kUnavailableDisplay,
    wireFeederVersion: kUnavailableDisplay,
  );
}

/// Monitor → Alarm Information welding-gun sensor temperatures.
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
    motorTemperature: kUnavailableDisplay,
    motorDriverTemperature: kUnavailableDisplay,
    protectiveMirrorTemperature: kUnavailableDisplay,
    collimatorTemperature: kUnavailableDisplay,
  );
}

/// Minimal Modbus RTU client for P2 device-info + alarm temperature reads.
///
/// Linux uses [PosixSerialPort] (libc + stty) because Buildroot's libserialport
/// 0.1.1 fails `sp_open` on kernel 6.1+ with ENOTTY (removed termiox ioctls).
class ModbusRtuClient {
  ModbusRtuClient({
    this.devicePath = ModbusSerialConfig.devicePath,
    this.slaveAddress = ModbusSerialConfig.slaveAddress,
  });

  final String devicePath;
  final int slaveAddress;

  PosixSerialPort? _posix;
  SerialPort? _libserial;
  bool _openFailed = false;

  bool get isOpen =>
      (_posix?.isOpen ?? false) || (_libserial?.isOpen == true);

  /// Soft-open: missing port or permissions set [isOpen] false without throwing.
  Future<bool> open() async {
    if (isOpen) {
      return true;
    }
    if (_openFailed) {
      return false;
    }

    if (Platform.isLinux) {
      final posix = PosixSerialPort(devicePath);
      if (posix.open(
        baudRate: ModbusSerialConfig.baudRate,
        dataBits: ModbusSerialConfig.dataBits,
        stopBits: ModbusSerialConfig.stopBits,
      )) {
        _posix = posix;
        return true;
      }
      posix.close();
      debugPrint(
        'Modbus: PosixSerialPort open failed; trying flutter_libserialport',
      );
    }

    try {
      debugPrint(
        'Modbus: opening $devicePath via libserialport; '
        'available=${SerialPort.availablePorts}',
      );
      final port = SerialPort(devicePath);
      if (!port.openReadWrite()) {
        debugPrint(
          'Modbus: openReadWrite failed: ${SerialPort.lastError}',
        );
        port.dispose();
        _openFailed = true;
        return false;
      }
      port.config = SerialPortConfig()
        ..baudRate = ModbusSerialConfig.baudRate
        ..bits = ModbusSerialConfig.dataBits
        ..stopBits = ModbusSerialConfig.stopBits
        ..parity = SerialPortParity.none
        ..setFlowControl(SerialPortFlowControl.none);
      _libserial = port;
      debugPrint(
        'Modbus: opened $devicePath @ ${ModbusSerialConfig.baudRate} 8N1',
      );
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

  /// Reads P2 Device Information Modbus fields; failures → `-`.
  Future<ModbusDeviceInfoSnapshot> readDeviceInfo() async {
    if (!await open()) {
      return ModbusDeviceInfoSnapshot.unavailable;
    }
    try {
      final firmwareRegs = await _readInputRegisters(
        DeviceStatusRegisterAddress.deviceSoftwareVersion,
        1,
      );
      final infoRegs = await _readInputRegisters(
        DeviceInfoRegisterAddress.laserHardwareVersionHigh,
        10,
      );
      if (firmwareRegs == null || infoRegs == null || infoRegs.length < 10) {
        return ModbusDeviceInfoSnapshot.unavailable;
      }

      final laserHigh =
          infoRegs[DeviceInfoRegisterAddress.laserSoftwareVersionHigh -
              DeviceInfoRegisterAddress.laserHardwareVersionHigh];
      final laserLow =
          infoRegs[DeviceInfoRegisterAddress.laserSoftwareVersionLow -
              DeviceInfoRegisterAddress.laserHardwareVersionHigh];
      final wire =
          infoRegs[DeviceInfoRegisterAddress.wireFeederSoftwareVersion -
              DeviceInfoRegisterAddress.laserHardwareVersionHigh];
      final snHigh = infoRegs[DeviceInfoRegisterAddress.gunHeadSnHigh -
          DeviceInfoRegisterAddress.laserHardwareVersionHigh];
      final snLow = infoRegs[DeviceInfoRegisterAddress.gunHeadSnLow -
          DeviceInfoRegisterAddress.laserHardwareVersionHigh];

      return ModbusDeviceInfoSnapshot(
        firmwareVersion: decimalRegister(firmwareRegs.first),
        laserVersion: hexConcatRegisters(laserHigh, laserLow),
        wireFeederVersion: decimalRegister(wire),
        gunheadSn: hexConcatRegisters(snHigh, snLow),
      );
    } catch (_) {
      return ModbusDeviceInfoSnapshot.unavailable;
    }
  }

  /// Reads four welding-gun sensor temperatures (Alarm Information panel).
  Future<ModbusAlarmTemperaturesSnapshot> readAlarmTemperatures() async {
    if (!await open()) {
      return ModbusAlarmTemperaturesSnapshot.unavailable;
    }
    try {
      final regs = await _readInputRegisters(
        DeviceDataRegisterAddress.gunMotorTemperature,
        4,
      );
      if (regs == null || regs.length < 4) {
        return ModbusAlarmTemperaturesSnapshot.unavailable;
      }
      return ModbusAlarmTemperaturesSnapshot(
        motorTemperature:
            formatSensorTemperatureCelsius(toSignedRegister16(regs[0])),
        motorDriverTemperature:
            formatSensorTemperatureCelsius(toSignedRegister16(regs[1])),
        protectiveMirrorTemperature:
            formatSensorTemperatureCelsius(toSignedRegister16(regs[2])),
        collimatorTemperature:
            formatSensorTemperatureCelsius(toSignedRegister16(regs[3])),
      );
    } catch (_) {
      return ModbusAlarmTemperaturesSnapshot.unavailable;
    }
  }

  Future<List<int>?> _readInputRegisters(int startAddress, int count) async {
    if (!isOpen) {
      return null;
    }

    final request = appendModbusCrc(<int>[
      slaveAddress & 0xFF,
      0x04,
      (startAddress >> 8) & 0xFF,
      startAddress & 0xFF,
      (count >> 8) & 0xFF,
      count & 0xFF,
    ]);

    // Drain stale RX briefly (ignore failures).
    _readChunk(256, timeoutMs: 1);

    final written = _writeChunk(
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

    final expectedLen = 5 + count * 2; // addr + fc + byteCount + data + crc
    final buffer = <int>[];
    final deadline = DateTime.now().add(ModbusSerialConfig.responseTimeout);

    while (buffer.length < expectedLen && DateTime.now().isBefore(deadline)) {
      final chunk = _readChunk(expectedLen - buffer.length, timeoutMs: 50);
      if (chunk.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        continue;
      }
      buffer.addAll(chunk);
      if (buffer.length >= 5 && (buffer[1] & 0x80) != 0) {
        // Exception response: addr, fc|0x80, ex, crc_lo, crc_hi
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
    if (buffer[0] != (slaveAddress & 0xFF) || buffer[1] != 0x04) {
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

  int _writeChunk(Uint8List data, {required int timeoutMs}) {
    final posix = _posix;
    if (posix != null) {
      return posix.write(data, timeoutMs: timeoutMs);
    }
    final port = _libserial;
    if (port == null || !port.isOpen) {
      return 0;
    }
    return port.write(data, timeout: timeoutMs);
  }

  Uint8List _readChunk(int maxBytes, {required int timeoutMs}) {
    final posix = _posix;
    if (posix != null) {
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
