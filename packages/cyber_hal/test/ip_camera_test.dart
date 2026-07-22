import 'package:cyber_hal/ip_camera.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IpCameraStreams', () {
    test('builds upstream URIs from injected host', () {
      final streams = IpCameraStreams.fromHost('192.168.1.100');
      expect(streams.pr0.toString(), 'rtsp://192.168.1.100/PR0');
      expect(streams.pr1.toString(), 'rtsp://192.168.1.100/PR1');
    });
  });

  group('LinuxIpCameraController', () {
    test('requires non-empty host', () {
      expect(
        () => LinuxIpCameraController(cameraHost: '  '),
        throwsArgumentError,
      );
    });

    test('two instances do not share health state', () async {
      var aOk = false;
      var bOk = false;
      final a = LinuxIpCameraController(
        cameraHost: '10.0.0.1',
        recoveryStablePings: 1,
        probe: (_) async => aOk,
      );
      final b = LinuxIpCameraController(
        cameraHost: '10.0.0.2',
        recoveryStablePings: 1,
        probe: (_) async => bOk,
      );

      aOk = true;
      await a.probeOnce();
      expect(a.currentHealth.phase, IpCameraHealthPhase.healthy);
      expect(b.currentHealth.phase, IpCameraHealthPhase.unknown);

      bOk = true;
      await b.probeOnce();
      expect(b.currentHealth.phase, IpCameraHealthPhase.healthy);

      await a.dispose();
      expect(b.currentHealth.phase, IpCameraHealthPhase.healthy);
      await b.dispose();
    });

    test('recovery needs consecutive OK probes', () async {
      final results = <bool>[false, true, true, true];
      var i = 0;
      final cam = LinuxIpCameraController(
        cameraHost: '192.168.1.100',
        recoveryStablePings: 3,
        failureStablePings: 1,
        probe: (_) async => results[i++],
      );

      await cam.probeOnce(); // fail → unhealthy
      expect(cam.currentHealth.phase, IpCameraHealthPhase.unhealthy);

      await cam.probeOnce(); // ok 1
      expect(cam.currentHealth.phase, IpCameraHealthPhase.unhealthy);
      await cam.probeOnce(); // ok 2
      expect(cam.currentHealth.phase, IpCameraHealthPhase.unhealthy);
      await cam.probeOnce(); // ok 3 → healthy
      expect(cam.currentHealth.phase, IpCameraHealthPhase.healthy);

      await cam.dispose();
    });

    test('single lost packet does not downgrade a healthy camera', () async {
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

    test('suspend suppresses probes; resume with configurePingOk seeds healthy',
        () async {
      var ok = false;
      final cam = LinuxIpCameraController(
        cameraHost: '192.168.1.100',
        recoveryStablePings: 1,
        probe: (_) async => ok,
      );

      cam.suspendProbes();
      ok = true;
      await cam.probeOnce();
      expect(cam.currentHealth.phase, IpCameraHealthPhase.unknown);

      cam.resumeProbes(configurePingOk: true);
      // configurePingOk true applies onProbeResult(true) → 1 stable → healthy
      expect(cam.currentHealth.phase, IpCameraHealthPhase.healthy);

      await cam.dispose();
    });

    test('failed configure ping does not downgrade prior healthy', () async {
      var ok = true;
      final cam = LinuxIpCameraController(
        cameraHost: '192.168.1.100',
        recoveryStablePings: 1,
        probe: (_) async => ok,
      );
      await cam.probeOnce();
      expect(cam.currentHealth.phase, IpCameraHealthPhase.healthy);

      cam.suspendProbes();
      ok = false;
      cam.resumeProbes(configurePingOk: false);
      expect(cam.currentHealth.phase, IpCameraHealthPhase.healthy);

      await cam.dispose();
    });
  });
}
