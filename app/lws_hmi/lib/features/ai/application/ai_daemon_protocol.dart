import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Minimal JSON-Lines framing helpers for `lws_ai_daemon` cmd/evt sockets.
final class AiDaemonProtocol {
  const AiDaemonProtocol();

  static String newId() {
    final r = Random.secure();
    final ms = DateTime.now().millisecondsSinceEpoch;
    return 'd${ms}_${r.nextInt(1 << 32)}';
  }

  static Map<String, Object?> pingRequest({String? id, int? tsMs}) {
    return cmd('ping', id: id, tsMs: tsMs);
  }

  /// Build a JSON-Lines cmd request (`type` + optional fields + `id`/`ts_ms`).
  static Map<String, Object?> cmd(
    String type, {
    Map<String, Object?> fields = const {},
    String? id,
    int? tsMs,
  }) {
    return <String, Object?>{
      'v': 1,
      'type': type,
      'id': id ?? newId(),
      'ts_ms': tsMs ?? DateTime.now().millisecondsSinceEpoch,
      ...fields,
    };
  }

  static String encodeLine(Map<String, Object?> obj) => '${jsonEncode(obj)}\n';

  /// Parse one JSON object from a line (trailing whitespace OK).
  static Map<String, dynamic>? tryDecodeLine(String line) {
    final t = line.trim();
    if (t.isEmpty) return null;
    final decoded = jsonDecode(t);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  static bool isDaemonReady(Map<String, dynamic> evt) =>
      evt['type']?.toString() == 'daemon_ready';

  static bool isPingAck(Map<String, dynamic> resp, {required String id}) {
    if (resp['id']?.toString() != id) return false;
    final type = resp['type']?.toString();
    if (type == 'ping_ack') return resp['ok'] != false;
    return type == 'pong' || (resp['ok'] == true && type == 'ping');
  }
}

/// Thin Unix-socket client for cmd (req/resp) and evt (publish) channels.
final class AiDaemonSocketClient {
  AiDaemonSocketClient({
    this.cmdPath = '/run/hmi/ai/cmd.sock',
    this.evtPath = '/run/hmi/ai/evt.sock',
  });

  final String cmdPath;
  final String evtPath;

  Socket? _cmd;
  Socket? _evt;
  StreamSubscription<List<int>>? _cmdSub;
  StreamSubscription<List<int>>? _evtSub;
  final _cmdBuf = StringBuffer();
  final _evtBuf = StringBuffer();
  final _cmdLines = StreamController<String>.broadcast();
  final _evtLines = StreamController<String>.broadcast();

  Stream<String> get cmdLines => _cmdLines.stream;
  Stream<String> get evtLines => _evtLines.stream;

  bool get isConnected => _cmd != null && _evt != null;

  Future<void> connect({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    await disconnect();
    _cmd = await Socket.connect(
      InternetAddress(cmdPath, type: InternetAddressType.unix),
      0,
      timeout: timeout,
    );
    _evt = await Socket.connect(
      InternetAddress(evtPath, type: InternetAddressType.unix),
      0,
      timeout: timeout,
    );
    _cmdSub = _cmd!.listen(
      (data) => _feed(_cmdBuf, utf8.decode(data), _cmdLines),
      onError: (_) {},
      onDone: () {},
      cancelOnError: false,
    );
    _evtSub = _evt!.listen(
      (data) => _feed(_evtBuf, utf8.decode(data), _evtLines),
      onError: (_) {},
      onDone: () {},
      cancelOnError: false,
    );
  }

  void _feed(StringBuffer buf, String chunk, StreamController<String> out) {
    buf.write(chunk);
    var s = buf.toString();
    var idx = s.indexOf('\n');
    while (idx >= 0) {
      final line = s.substring(0, idx);
      out.add(line);
      s = s.substring(idx + 1);
      idx = s.indexOf('\n');
    }
    buf
      ..clear()
      ..write(s);
  }

  Future<Map<String, dynamic>> request(
    Map<String, Object?> req, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final cmd = _cmd;
    if (cmd == null) {
      throw StateError('AI cmd socket not connected');
    }
    final id = req['id']?.toString() ?? AiDaemonProtocol.newId();
    final payload = Map<String, Object?>.from(req)..['id'] = id;
    final completer = Completer<Map<String, dynamic>>();
    late final StreamSubscription<String> sub;
    sub = cmdLines.listen((line) {
      final obj = AiDaemonProtocol.tryDecodeLine(line);
      if (obj == null) return;
      if (obj['id']?.toString() != id) return;
      if (!completer.isCompleted) {
        completer.complete(obj);
      }
    });
    try {
      cmd.add(utf8.encode(AiDaemonProtocol.encodeLine(payload)));
      await cmd.flush();
      return await completer.future.timeout(timeout);
    } finally {
      await sub.cancel();
    }
  }

  Future<void> waitForDaemonReady({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final existing = Completer<void>();
    late final StreamSubscription<String> sub;
    sub = evtLines.listen((line) {
      final obj = AiDaemonProtocol.tryDecodeLine(line);
      if (obj != null && AiDaemonProtocol.isDaemonReady(obj)) {
        if (!existing.isCompleted) existing.complete();
      }
    });
    try {
      await existing.future.timeout(timeout);
    } finally {
      await sub.cancel();
    }
  }

  Future<void> disconnect() async {
    await _cmdSub?.cancel();
    await _evtSub?.cancel();
    _cmdSub = null;
    _evtSub = null;
    await _cmd?.close();
    await _evt?.close();
    _cmd = null;
    _evt = null;
    _cmdBuf.clear();
    _evtBuf.clear();
  }
}
