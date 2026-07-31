import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/ai/application/ai_daemon_protocol.dart';

void main() {
  test('ping request carries v/type/id/ts_ms', () {
    final req = AiDaemonProtocol.pingRequest(id: 'abc', tsMs: 42);
    expect(req['v'], 1);
    expect(req['type'], 'ping');
    expect(req['id'], 'abc');
    expect(req['ts_ms'], 42);
  });

  test('encodeLine ends with newline', () {
    final line = AiDaemonProtocol.encodeLine({'v': 1, 'type': 'ping'});
    expect(line.endsWith('\n'), isTrue);
    expect(AiDaemonProtocol.tryDecodeLine(line)!['type'], 'ping');
  });

  test('isDaemonReady / isPingAck', () {
    expect(
      AiDaemonProtocol.isDaemonReady({'type': 'daemon_ready', 'v': 1}),
      isTrue,
    );
    expect(
      AiDaemonProtocol.isPingAck(
        {'type': 'ping_ack', 'id': 'x', 'ok': true},
        id: 'x',
      ),
      isTrue,
    );
    expect(
      AiDaemonProtocol.isPingAck(
        {'type': 'ping_ack', 'id': 'y', 'ok': true},
        id: 'x',
      ),
      isFalse,
    );
  });
}
