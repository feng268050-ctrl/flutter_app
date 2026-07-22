import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cyber_hal/ip_camera.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tcpRtspPortProbe', () {
    test('succeeds when port accepts TCP', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((socket) async {
        await socket.close();
      });

      final probe = tcpRtspPortProbe(port: server.port);
      expect(await probe('127.0.0.1'), isTrue);
    });

    test('fails when port is closed', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      await server.close();

      final probe = tcpRtspPortProbe(
        port: port,
        timeout: const Duration(milliseconds: 200),
      );
      expect(await probe('127.0.0.1'), isFalse);
    });

    test('fails on empty host', () async {
      final probe = tcpRtspPortProbe();
      expect(await probe('  '), isFalse);
    });
  });

  group('rtspOptionsProbe', () {
    test('succeeds on RTSP OPTIONS * response without PR0/PR1 SETUP', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      final requestCompleter = Completer<String>();
      server.listen((socket) async {
        final buffer = StringBuffer();
        await for (final chunk in socket) {
          buffer.write(utf8.decode(chunk));
          if (buffer.toString().contains('\r\n\r\n')) {
            break;
          }
        }
        requestCompleter.complete(buffer.toString());
        socket.add(
          utf8.encode(
            'RTSP/1.0 200 OK\r\n'
            'CSeq: 1\r\n'
            'Public: OPTIONS, DESCRIBE\r\n'
            '\r\n',
          ),
        );
        await socket.flush();
        await socket.close();
      });

      final probe = rtspOptionsProbe(port: server.port);
      expect(await probe('127.0.0.1'), isTrue);

      final request = await requestCompleter.future;
      expect(request, startsWith('OPTIONS * RTSP/1.0'));
      expect(request.toUpperCase(), isNot(contains('SETUP')));
      expect(request.toUpperCase(), isNot(contains('PLAY')));
      expect(request, isNot(contains('/PR0')));
      expect(request, isNot(contains('/PR1')));
    });

    test('treats RTSP 4xx as alive (no media SETUP)', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((socket) async {
        await for (final chunk in socket) {
          if (utf8.decode(chunk).contains('\r\n\r\n')) {
            break;
          }
        }
        socket.add(utf8.encode('RTSP/1.0 461 Unsupported transport\r\n\r\n'));
        await socket.flush();
        await socket.close();
      });

      final probe = rtspOptionsProbe(port: server.port);
      expect(await probe('127.0.0.1'), isTrue);
    });

    test('fails when peer never speaks RTSP', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((socket) async {
        await for (final _ in socket) {
          break;
        }
        socket.add(utf8.encode('HTTP/1.1 200 OK\r\n\r\n'));
        await socket.flush();
        await socket.close();
      });

      final probe = rtspOptionsProbe(
        port: server.port,
        timeout: const Duration(milliseconds: 300),
      );
      expect(await probe('127.0.0.1'), isFalse);
    });
  });

  group('relayInformedProbe', () {
    test('fails fast when path/relay not ready', () async {
      var hostCalled = false;
      final probe = relayInformedProbe(
        isPathOrRelayReady: () => false,
        hostProbe: (_) async {
          hostCalled = true;
          return true;
        },
      );
      expect(await probe('192.168.1.100'), isFalse);
      expect(hostCalled, isFalse);
    });

    test('delegates to host probe when ready', () async {
      final probe = relayInformedProbe(
        isPathOrRelayReady: () => true,
        hostProbe: (_) async => true,
      );
      expect(await probe('192.168.1.100'), isTrue);
    });
  });

  group('LinuxIpCameraController + injectable probes', () {
    test('debounce unchanged with TCP-style fake probe', () async {
      final results = <bool>[true, false, true, false, false, false];
      var i = 0;
      final cam = LinuxIpCameraController(
        cameraHost: '192.168.1.100',
        recoveryStablePings: 1,
        failureStablePings: 3,
        probe: (_) async => results[i++],
      );

      await cam.probeOnce();
      expect(cam.currentHealth.phase, IpCameraHealthPhase.healthy);
      await cam.probeOnce();
      expect(cam.currentHealth.phase, IpCameraHealthPhase.healthy);
      await cam.probeOnce();
      expect(cam.currentHealth.phase, IpCameraHealthPhase.healthy);
      await cam.probeOnce();
      await cam.probeOnce();
      expect(cam.currentHealth.phase, IpCameraHealthPhase.healthy);
      await cam.probeOnce();
      expect(cam.currentHealth.phase, IpCameraHealthPhase.unhealthy);

      await cam.dispose();
    });

    test('relay-informed composition drives health without PR path SETUP',
        () async {
      var ready = true;
      var hostOk = true;
      final cam = LinuxIpCameraController(
        cameraHost: '192.168.1.100',
        recoveryStablePings: 1,
        failureStablePings: 1,
        probe: relayInformedProbe(
          isPathOrRelayReady: () => ready,
          hostProbe: (_) async => hostOk,
        ),
      );

      await cam.probeOnce();
      expect(cam.currentHealth.phase, IpCameraHealthPhase.healthy);

      ready = false;
      await cam.probeOnce();
      expect(cam.currentHealth.phase, IpCameraHealthPhase.unhealthy);

      ready = true;
      hostOk = true;
      await cam.probeOnce();
      expect(cam.currentHealth.phase, IpCameraHealthPhase.healthy);

      await cam.dispose();
    });
  });
}
