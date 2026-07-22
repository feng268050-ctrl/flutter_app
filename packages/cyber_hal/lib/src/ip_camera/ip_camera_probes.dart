import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cyber_hal/src/ip_camera/ip_camera_models.dart';

/// Default RTSP service port for IP cameras in this product line.
const int kDefaultIpCameraRtspPort = 554;

/// ICMP host reachability (`ping -c 1`). Used as baseline / fallback probe.
Future<bool> icmpIpCameraProbe(String cameraHost) async {
  final host = cameraHost.trim();
  if (host.isEmpty) {
    return false;
  }
  if (!Platform.isLinux && !Platform.isMacOS) {
    return false;
  }
  try {
    // Linux: -W seconds; macOS: -W milliseconds.
    final args = Platform.isLinux
        ? <String>['-c', '1', '-W', '1', host]
        : <String>['-c', '1', '-W', '1000', host];
    final result = await Process.run('ping', args);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

/// Short TCP connect to [port] then close — RTSP port liveness only.
///
/// Does not speak RTSP; MUST NOT open media sessions on `/PR0` or `/PR1`.
IpCameraProbe tcpRtspPortProbe({
  int port = kDefaultIpCameraRtspPort,
  Duration timeout = const Duration(seconds: 1),
  Future<Socket> Function(String host, int port, {Duration? timeout})?
      connect,
}) {
  final connectFn = connect ??
      ((String host, int port, {Duration? timeout}) {
        return Socket.connect(host, port, timeout: timeout);
      });
  return (String cameraHost) async {
    final host = cameraHost.trim();
    if (host.isEmpty) {
      return false;
    }
    Socket? socket;
    try {
      socket = await connectFn(host, port, timeout: timeout);
      return true;
    } catch (_) {
      return false;
    } finally {
      try {
        await socket?.close();
      } catch (_) {}
    }
  };
}

/// Lightweight RTSP `OPTIONS` without media `SETUP`/`PLAY`.
///
/// Request-URI is session-level (`*` or `rtsp://host/`) — never `/PR0` or `/PR1`.
IpCameraProbe rtspOptionsProbe({
  int port = kDefaultIpCameraRtspPort,
  Duration timeout = const Duration(seconds: 1),
  Future<Socket> Function(String host, int port, {Duration? timeout})?
      connect,
}) {
  final connectFn = connect ??
      ((String host, int port, {Duration? timeout}) {
        return Socket.connect(host, port, timeout: timeout);
      });
  return (String cameraHost) async {
    final host = cameraHost.trim();
    if (host.isEmpty) {
      return false;
    }
    Socket? socket;
    try {
      socket = await connectFn(host, port, timeout: timeout);
      final request = 'OPTIONS * RTSP/1.0\r\n'
          'CSeq: 1\r\n'
          'User-Agent: cyber_hal-health\r\n'
          '\r\n';
      socket.add(utf8.encode(request));
      await socket.flush();

      final response = await _readUntilBlankLine(socket).timeout(timeout);
      // Any RTSP status line counts as stack alive (2xx preferred; 4xx still
      // proves the RTSP server answered without media SETUP).
      return response.startsWith('RTSP/1.0 ');
    } catch (_) {
      return false;
    } finally {
      try {
        await socket?.close();
      } catch (_) {}
    }
  };
}

/// Prefer product path/relay readiness; when ready, run [hostProbe].
///
/// [isPathOrRelayReady] MUST NOT open camera `/PR0`/`/PR1`. When it reports
/// false, the composed probe fails immediately (no extra camera client).
IpCameraProbe relayInformedProbe({
  required bool Function() isPathOrRelayReady,
  required IpCameraProbe hostProbe,
}) {
  return (String cameraHost) async {
    if (!isPathOrRelayReady()) {
      return false;
    }
    return hostProbe(cameraHost);
  };
}

Future<String> _readUntilBlankLine(Socket socket) async {
  final buffer = StringBuffer();
  final completer = Completer<String>();
  late StreamSubscription<List<int>> sub;
  sub = socket.listen(
    (chunk) {
      buffer.write(utf8.decode(chunk, allowMalformed: true));
      final text = buffer.toString();
      if (text.contains('\r\n\r\n') || text.contains('\n\n')) {
        if (!completer.isCompleted) {
          completer.complete(text);
        }
      }
    },
    onError: (Object e, StackTrace st) {
      if (!completer.isCompleted) {
        completer.completeError(e, st);
      }
    },
    onDone: () {
      if (!completer.isCompleted) {
        completer.complete(buffer.toString());
      }
    },
    cancelOnError: true,
  );
  try {
    return await completer.future;
  } finally {
    await sub.cancel();
  }
}
