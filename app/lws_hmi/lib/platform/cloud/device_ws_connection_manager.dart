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
    this.pingInterval = defaultPingInterval,
  });

  /// Match lws-ui OkHttp `pingInterval(30s)` — protocol ping/pong keeps
  /// proxies/NAT from idle-dropping the socket; missed pong closes → reconnect.
  static const Duration defaultPingInterval = Duration(seconds: 30);

  final CloudHttpClient cloudHttp;
  DeviceWsMessageHandler? onMessage;
  void Function(DeviceWsState state)? onStateChanged;
  void Function()? onAuthError;
  final Duration? pingInterval;

  WebSocket? _socket;
  Uri? _url;
  DeviceWsState _state = DeviceWsState.disconnected;
  bool _forcedDisconnect = false;
  bool _authErrorLatch = false;
  bool _disposed = false;
  int _attempt = 0;
  Timer? _reconnectTimer;
  StreamSubscription? _sub;
  final StreamController<DeviceWsState> _stateCtrl =
      StreamController<DeviceWsState>.broadcast();

  DeviceWsState get state => _state;
  Stream<DeviceWsState> get stateChanges => _stateCtrl.stream;
  bool get forcedDisconnectSuppressed => _forcedDisconnect;
  bool get authErrorLatched => _authErrorLatch;
  Uri? get url => _url;

  /// Open [wsUrl]. When [resumeAfterAuth] is true, clear the INVALID_SN /
  /// 401 latch so a SN that became valid (mobile registration) can connect.
  Future<void> connect(
    Uri wsUrl, {
    bool resumeAfterAuth = false,
  }) async {
    if (_disposed) {
      return;
    }
    if (resumeAfterAuth) {
      _authErrorLatch = false;
      _forcedDisconnect = false;
      _attempt = 0;
    }
    _url = wsUrl;
    if (_forcedDisconnect || _authErrorLatch) {
      debugPrint(
        'device-ws: connect skipped '
        '(forced=$_forcedDisconnect authLatch=$_authErrorLatch) url=$wsUrl',
      );
      return;
    }
    await _open();
  }

  /// User-driven reconnect after registration dialog (last URL).
  Future<void> reconnectClearingAuthLatch() async {
    _authErrorLatch = false;
    _forcedDisconnect = false;
    _attempt = 0;
    if (_url != null) {
      await _open();
    }
  }

  /// Network-recovery reconnect: keeps auth / forced latches intact.
  Future<void> reconnectIfIdle() async {
    if (_disposed ||
        _url == null ||
        _forcedDisconnect ||
        _authErrorLatch ||
        _state == DeviceWsState.connected ||
        _state == DeviceWsState.connecting ||
        _state == DeviceWsState.offlineAuthError) {
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _attempt = 0;
    await _open();
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
      debugPrint(
        'device-ws: send dropped type=${envelope.type} '
        'state=$_state socket=${socket != null}',
      );
      return;
    }
    try {
      final json = envelope.encode();
      socket.add(json);
      debugPrint(
        'device-ws: sent type=${envelope.type} id=${envelope.id} jsonLen=${json.length}',
      );
    } catch (e) {
      debugPrint('device-ws: send failed: $e');
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    await _closeSocket();
    await _stateCtrl.close();
  }

  Future<void> _open() async {
    if (_disposed || _url == null) {
      return;
    }
    if (_forcedDisconnect || _authErrorLatch) {
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
      socket.pingInterval = pingInterval;
      _socket = socket;
      _attempt = 0;
      _setState(DeviceWsState.connected);
      debugPrint(
        'device-ws: connected $_url pingInterval=$pingInterval',
      );
      _sub = socket.listen(
        _onData,
        onError: (Object e) {
          debugPrint('device-ws: stream error: $e');
          unawaited(_handleFailure(auth: false));
        },
        onDone: () {
          final code = socket.closeCode;
          final reason = socket.closeReason;
          debugPrint(
            'device-ws: closed code=$code reason=$reason url=$_url',
          );
          final auth = code == 401 || code == 4401;
          unawaited(_handleFailure(auth: auth));
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('device-ws: connect failed: $e');
      final auth = await _classifyConnectFailure(e, _url!);
      await _handleFailure(auth: auth);
    } finally {
      client?.close(force: true);
    }
  }

  /// Dart [WebSocket.connect] on HTTP 401 often throws
  /// `WebSocketException: … was not upgraded to websocket` with **no** "401"
  /// in the message — so we HTTP-GET the same path to classify INVALID_SN.
  Future<bool> _classifyConnectFailure(Object e, Uri wsUrl) async {
    final msg = e.toString();
    if (msg.contains('401') ||
        msg.contains('4401') ||
        msg.toLowerCase().contains('invalid_sn')) {
      return true;
    }
    final looksLikeFailedUpgrade = e is WebSocketException ||
        e is HandshakeException ||
        msg.contains('not upgraded') ||
        msg.contains('HandshakeException');
    if (!looksLikeFailedUpgrade) {
      return false;
    }
    try {
      final httpUrl = wsUrl.replace(
        scheme: wsUrl.scheme == 'wss' ? 'https' : 'http',
        fragment: '',
      );
      final resp = await cloudHttp.getJson(
        httpUrl,
        timeout: const Duration(seconds: 8),
      );
      if (resp.statusCode == 401) {
        return true;
      }
      final body = resp.body.toLowerCase();
      if (body.contains('invalid_sn') ||
          body.contains('invalid device serial') ||
          body.contains('"code":401')) {
        return true;
      }
    } catch (probeErr) {
      debugPrint('device-ws: auth classify probe failed: $probeErr');
    }
    return false;
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
    final prev = _state;
    _state = next;
    debugPrint('device-ws: state $prev → $next url=$_url');
    if (!_stateCtrl.isClosed) {
      _stateCtrl.add(next);
    }
    onStateChanged?.call(next);
  }
}
