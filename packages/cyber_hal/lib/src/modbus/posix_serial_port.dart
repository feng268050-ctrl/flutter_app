import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart' as pkgffi;
import 'package:flutter/foundation.dart';
import 'package:cyber_hal/src/linux/lws_trace.dart';

/// Minimal Linux serial I/O via libc + `stty` (avoids libserialport termiox/ENOTTY).
///
/// Buildroot ships libserialport 0.1.1, which fails `sp_open` on kernel 6.1+
/// with errno 25 (`Inappropriate ioctl for device`) because it probes removed
/// `struct termiox` ioctls.
class PosixSerialPort {
  PosixSerialPort(this.path);

  final String path;
  int _fd = -1;

  bool get isOpen => _fd >= 0;

  /// Opens [path] for read/write and configures 8N1 via `stty`.
  bool open({
    int baudRate = 115200,
    int dataBits = 8,
    int stopBits = 1,
    bool parity = false,
  }) {
    if (isOpen) {
      return true;
    }
    if (!Platform.isLinux) {
      debugPrint('PosixSerialPort: only supported on Linux');
      return false;
    }
    if (!_configureViaStty(
      baudRate: baudRate,
      dataBits: dataBits,
      stopBits: stopBits,
      parity: parity,
    )) {
      debugPrint('PosixSerialPort: stty configure failed for $path');
      // Still attempt open — baud may already be correct.
    }

    final pathPtr = path.toNativeUtf8();
    try {
      _fd = _libc.open(
        pathPtr.cast<ffi.Char>(),
        oRdwr | oNoctty | oNonblock,
      );
    } finally {
      pkgffi.malloc.free(pathPtr);
    }
    if (_fd < 0) {
      debugPrint('PosixSerialPort: open($path) failed errno=${_libc.errno}');
      return false;
    }
    lwsTrace('PosixSerialPort: opened $path fd=$_fd @ $baudRate 8N1');
    return true;
  }

  void close() {
    if (_fd < 0) {
      return;
    }
    _libc.close(_fd);
    _fd = -1;
  }

  /// Writes [data]; returns bytes written (may be short).
  int write(Uint8List data, {int timeoutMs = 200}) {
    if (!isOpen || data.isEmpty) {
      return 0;
    }
    final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
    var offset = 0;
    final ptr = pkgffi.malloc<ffi.Uint8>(data.length);
    try {
      ptr.asTypedList(data.length).setAll(0, data);
      while (offset < data.length && DateTime.now().isBefore(deadline)) {
        final n = _libc.write(
          _fd,
          (ptr + offset).cast<ffi.Void>(),
          data.length - offset,
        );
        if (n > 0) {
          offset += n;
          continue;
        }
        if (n < 0 && _libc.errno == eAgain) {
          sleep(const Duration(milliseconds: 5));
          continue;
        }
        break;
      }
    } finally {
      pkgffi.malloc.free(ptr);
    }
    return offset;
  }

  /// Non-blocking read of up to [maxBytes]. [timeoutMs] kept for API parity;
  /// caller polls with async delays for Modbus framing.
  Uint8List read(int maxBytes, {int timeoutMs = 50}) {
    if (!isOpen || maxBytes <= 0) {
      return Uint8List(0);
    }
    final buf = pkgffi.malloc<ffi.Uint8>(maxBytes);
    try {
      final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
      do {
        final n = _libc.read(_fd, buf.cast<ffi.Void>(), maxBytes);
        if (n > 0) {
          return Uint8List.fromList(buf.asTypedList(n));
        }
        if (n < 0 && _libc.errno != eAgain) {
          break;
        }
        if (!DateTime.now().isBefore(deadline)) {
          break;
        }
        sleep(const Duration(milliseconds: 5));
      } while (true);
      return Uint8List(0);
    } finally {
      pkgffi.malloc.free(buf);
    }
  }

  bool _configureViaStty({
    required int baudRate,
    required int dataBits,
    required int stopBits,
    required bool parity,
  }) {
    final bits = switch (dataBits) {
      5 => 'cs5',
      6 => 'cs6',
      7 => 'cs7',
      _ => 'cs8',
    };
    final args = <String>[
      '-F',
      path,
      '$baudRate',
      bits,
      if (stopBits == 2) 'cstopb' else '-cstopb',
      if (parity) 'parenb' else '-parenb',
      '-ixon',
      '-ixoff',
      '-crtscts',
      'clocal',
      'raw',
      '-echo',
      'min',
      '0',
      'time',
      '1',
    ];
    try {
      final r = Process.runSync('stty', args);
      if (r.exitCode != 0) {
        debugPrint(
          'PosixSerialPort: stty exit=${r.exitCode} stderr=${r.stderr}',
        );
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('PosixSerialPort: stty exception: $e');
      return false;
    }
  }
}

// Linux aarch64 / x86_64 open flags (octal in fcntl.h).
const int oRdwr = 0x2;
const int oNoctty = 0x100;
const int oNonblock = 0x800;
const int eAgain = 11;

final _LibC _libc = _LibC(ffi.DynamicLibrary.open('libc.so.6'));

final class _LibC {
  _LibC(ffi.DynamicLibrary lib)
      : open = lib.lookupFunction<_OpenNative, _OpenDart>('open'),
        close = lib.lookupFunction<_CloseNative, _CloseDart>('close'),
        read = lib.lookupFunction<_ReadNative, _ReadDart>('read'),
        write = lib.lookupFunction<_WriteNative, _WriteDart>('write'),
        _errnoLocation =
            lib.lookupFunction<_ErrnoLocationNative, _ErrnoLocationDart>(
          '__errno_location',
        );

  final _OpenDart open;
  final _CloseDart close;
  final _ReadDart read;
  final _WriteDart write;
  final _ErrnoLocationDart _errnoLocation;

  int get errno => _errnoLocation().value;
}

typedef _OpenNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Char> path,
  ffi.Int32 flags,
);
typedef _OpenDart = int Function(ffi.Pointer<ffi.Char> path, int flags);
typedef _CloseNative = ffi.Int32 Function(ffi.Int32 fd);
typedef _CloseDart = int Function(int fd);
typedef _ReadNative = ffi.IntPtr Function(
  ffi.Int32 fd,
  ffi.Pointer<ffi.Void> buf,
  ffi.IntPtr count,
);
typedef _ReadDart = int Function(int fd, ffi.Pointer<ffi.Void> buf, int count);
typedef _WriteNative = ffi.IntPtr Function(
  ffi.Int32 fd,
  ffi.Pointer<ffi.Void> buf,
  ffi.IntPtr count,
);
typedef _WriteDart = int Function(int fd, ffi.Pointer<ffi.Void> buf, int count);
typedef _ErrnoLocationNative = ffi.Pointer<ffi.Int32> Function();
typedef _ErrnoLocationDart = ffi.Pointer<ffi.Int32> Function();
