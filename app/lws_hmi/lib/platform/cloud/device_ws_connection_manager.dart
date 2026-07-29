import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/cloud/cloud_http_client.dart';
import 'package:lws_hmi/platform/cloud/device_ws_envelope.dart';
import 'package:lws_hmi/platform/lws_trace.dart';

enum DeviceWsState {
  disconnected,
  connecting,
  connected,
  offlineAuthError,
}

typedef DeviceWsMessageHandler = Future<void> Function(DeviceWsEnvelope envelope);

/// Outbound device WebSocket with reconnect / auth latch / forced-disconnect.
final class DeviceWsConnectionManager {
  DeviceWsConnectionManager({
    required this.cloudHttp,
    this.onMessage,
    this.onStateChanged,
    this.onAuthError,
  });

  final CloudHttpClient cloudHttp;
  DeviceWsMessageHandler? onMessage;
  void Function(DeviceWsState state)? onStateChanged;
  void Function()? onAuthError;

  WebSocket? _socket;
  Uri? _url;
  DeviceWsState _state = DeviceWsState.disconnected;
  bool _forcedDisconnect = false;
  bool _authErrorLatch = false;
  bool _disposed = false;
  int _attempt = 0;
  Timer? _reconnectTimer;
  StreamSubscription? _sub;

  DeviceWsState get state => _state;
  bool get forcedDisconnectSuppressed => _forcedDisconnect;
  bool get authErrorLatched => _authErrorLatch;

  Future<void> connect(Uri wsUrl) async {
    if (_disposed) {
      return;
    }
    _url = wsUrl;
    if (_forcedDisconnect || _authErrorLatch) {
      lwsTrace('device-ws: connect skipped (suppressed)');
      return;
    }
    await _open();
  }

  /// User-driven reconnect after registration dialog.
  Future<void> reconnectClearingAuthLatch() async {
    _authErrorLatch = false;
    _forcedDisconnect = false;
    _attempt = 0;
    if (_url != null) {
      await _open();
    }
  }

  Future<void> disconnect({bool forced = false}) async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (forced) {
      _forcedDisconnect = true;
    }
    await _closeSocket();
    _setState(DeviceWsState.disconnected);
  }

  Future<void> send(DeviceWsEnvelope envelope) async {
    final socket = _socket;
    if (socket == null || _state != DeviceWsState.connected) {
      return;
    }
    try {
      socket.add(envelope.encode());
    } catch (e) {
      debugPrint('device-ws: send failed: $e');
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    await _closeSocket();
  }

  Future<void> _open() async {
    if (_disposed || _url == null) {
      return;
    }
    await _closeSocket();
    _setState(DeviceWsState.connecting);
    HttpClient? client;
    try {
      client = await cloudHttp.openClient(
        timeout: const Duration(seconds: 20),
      );
      final socket = await WebSocket.connect(
        _url.toString(),
        customClient: client,
      ).timeout(const Duration(seconds: 20));
      // WebSocket takes ownership; do not force-close client here.
      client = null;
      _socket = socket;
      _attempt = 0;
      _setState(DeviceWsState.connected);
      _sub = socket.listen(
        _onData,
        onError: (Object e) {
          debugPrint('device-ws: stream error: $e');
          unawaited(_handleFailure(auth: false));
        },
        onDone: () {
          final code = socket.closeCode;
          final auth = code == 401 || code == 4401;
          unawaited(_handleFailure(auth: auth));
        },
        cancelOnError: true,
      );
    } on HandshakeException catch (e) {
      debugPrint('device-ws: handshake failed: $e');
      final auth = e.toString().contains('401');
      await _handleFailure(auth: auth);
    } catch (e) {
      final msg = e.toString();
      debugPrint('device-ws: connect failed: $e');
      final auth = msg.contains('401') || msg.contains('HTTP status code: 401');
      await _handleFailure(auth: auth);
    } finally {
      client?.close(force: true);
    }
  }

  void _onData(dynamic data) {
    if (data is! String) {
      return;
    }
    final envelope = DeviceWsEnvelope.tryParse(data);
    if (envelope == null) {
      lwsTrace('device-ws: discard malformed frame');
      return;
    }
    final handler = onMessage;
    if (handler != null) {
      unawaited(handler(envelope));
    }
  }

  Future<void> _handleFailure({required bool auth}) async {
    await _closeSocket();
    if (_disposed) {
      return;
    }
    if (auth) {
      _authErrorLatch = true;
      _setState(DeviceWsState.offlineAuthError);
      onAuthError?.call();
      return;
    }
    _setState(DeviceWsState.disconnected);
    if (_forcedDisconnect || _authErrorLatch || _url == null) {
      return;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _attempt++;
    final seconds = (_attempt * 2).clamp(2, 60);
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      unawaited(_open());
    });
  }

  Future<void> _closeSocket() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;
  }

  void _setState(DeviceWsState next) {
    if (_state == next) {
      return;
    }
    _state = next;
    onStateChanged?.call(next);
  }
}
