import 'dart:async';
import 'dart:io';

import 'package:cyber_ota/cyber_ota.dart';
import 'package:test/test.dart';

final class _FakeVerify extends OtaVerify {
  _FakeVerify() : super(processRunner: ProcessRunner());

  int calls = 0;
  Object? error;
  void Function()? onCall;

  @override
  Future<void> verifyPackage({
    required String archivePath,
    required String sigPath,
  }) async {
    calls++;
    onCall?.call();
    final err = error;
    if (err != null) {
      throw err;
    }
  }
}

final class _FakeExtract extends OtaExtract {
  _FakeExtract() : super(processRunner: ProcessRunner());

  int calls = 0;
  void Function()? onCall;

  @override
  Future<void> extractArchive({
    required String archivePath,
    required String stagingDir,
    ExtractProgress? onProgress,
  }) async {
    calls++;
    onCall?.call();
    onProgress?.call(0, 1);
    onProgress?.call(1, 1);
  }
}

final class _FakeApply extends OtaApply {
  _FakeApply() : super(processRunner: ProcessRunner());

  int fullCalls = 0;
  int oemCalls = 0;
  Object? error;
  List<OtaProgress> writingSteps = const <OtaProgress>[];

  @override
  Future<void> applyFullSystem({
    required String stagingDir,
    required OtaIngressKind ingress,
    required ApplyProgressSink emit,
    bool cameFromArchive = true,
  }) async {
    fullCalls++;
    final err = error;
    if (err != null) {
      throw err;
    }
    for (final step in writingSteps) {
      await emit(step.copyWith(ingress: ingress));
    }
    if (writingSteps.isEmpty) {
      await emit(
        OtaProgress(
          phase: OtaPhase.writing,
          percent: 100,
          ingress: ingress,
          message: 'Write complete',
        ),
      );
      await emit(
        OtaProgress(
          phase: OtaPhase.arming,
          percent: 100,
          ingress: ingress,
          message: 'Arming try-boot',
        ),
      );
      await emit(
        OtaProgress(
          phase: OtaPhase.ok,
          percent: 100,
          ingress: ingress,
          message: 'OTA complete',
        ),
      );
    }
  }

  @override
  Future<void> applyOemOnly({
    required String stagingDir,
    required OtaIngressKind ingress,
    required ApplyProgressSink emit,
  }) async {
    oemCalls++;
    await emit(
      OtaProgress(
        phase: OtaPhase.ok,
        percent: 100,
        ingress: ingress,
        message: 'oem apply ok',
      ),
    );
  }
}

void main() {
  group('OtaSession progress machine', () {
    late FakeOtaHttpClient http;
    late _FakeVerify verify;
    late _FakeExtract extract;
    late _FakeApply apply;
    late OtaSession session;
    late List<OtaProgress> events;
    late Directory staging;

    setUp(() async {
      staging = await Directory.systemTemp.createTemp('cyber-ota-session-');
      verify = _FakeVerify();
      extract = _FakeExtract();
      apply = _FakeApply();
      http = FakeOtaHttpClient(
        manifestJson: <String, dynamic>{
          'version': '9.0.0',
          'package_url': 'https://cdn.example/ota.tar.gz',
        },
        downloadHandler: (url, dest, {onProgress}) async {
          final file = File(dest);
          await file.parent.create(recursive: true);
          await file.writeAsString('package-bytes');
          onProgress?.call(100, 100);
        },
      );
      session = OtaSession(
        stagingDir: '${staging.path}/',
        httpClient: http,
        verify: verify,
        extract: extract,
        apply: apply,
      );
      events = <OtaProgress>[];
      session.progress.listen(events.add);
    });

    tearDown(() async {
      await session.close();
      try {
        await staging.delete(recursive: true);
      } catch (_) {}
    });

    test('checkForUpdate reports newer manifest', () async {
      final result = await session.checkForUpdate(
        manifestUrl: 'https://cdn.example/manifest.json',
        currentVersion: '1.0.0',
      );

      expect(result.hasUpdate, isTrue);
      expect(result.manifest?.version, '9.0.0');
      expect(events.map((e) => e.phase), contains(OtaPhase.checking));
    });

    test('checkForUpdate accepts publish-shaped url channel JSON', () async {
      http.manifestJson = <String, dynamic>{
        'version': 'v1.0.41-beta',
        'filename': 'v1.0.41-beta.tar.gz',
        'published_at': '2026-08-06T08:00:00Z',
        'url': 'https://cdn.example/lws-hmi/v1.0.41-beta.tar.gz',
      };

      final result = await session.checkForUpdate(
        manifestUrl: 'https://api.example/view/lws-hmi/staging.json',
        currentVersion: '1.0.40',
      );

      expect(result.hasUpdate, isTrue);
      expect(result.manifest?.version, 'v1.0.41-beta');
      expect(
        result.manifest?.packageUrl,
        'https://cdn.example/lws-hmi/v1.0.41-beta.tar.gz',
      );
      expect(
        result.manifest?.sigUrlResolved,
        'https://cdn.example/lws-hmi/v1.0.41-beta.tar.gz.sig',
      );
    });

    test('cloud path walks transferring → verifying → extracting → writing → ok',
        () async {
      await session.runCloudUpdate(
        manifest: OtaManifest.fromJson(<String, dynamic>{
          'version': '2.0.0',
          'package_url': 'https://cdn.example/ota.tar.gz',
        }),
      );

      final phases = events.map((e) => e.phase).toList();
      expect(phases, contains(OtaPhase.transferring));
      expect(phases, contains(OtaPhase.verifying));
      expect(phases, contains(OtaPhase.extracting));
      expect(phases, contains(OtaPhase.writing));
      expect(phases, contains(OtaPhase.arming));
      expect(phases.last, OtaPhase.ok);

      expect(verify.calls, 1);
      expect(extract.calls, 1);
      expect(apply.fullCalls, 1);
      expect(http.downloads, contains('https://cdn.example/ota.tar.gz'));
      expect(http.downloads, contains('https://cdn.example/ota.tar.gz.sig'));
    });

    test('beforeExtract runs after verify and before extract', () async {
      final order = <String>[];
      verify.onCall = () => order.add('verify');
      extract.onCall = () => order.add('extract');
      final hooked = OtaSession(
        stagingDir: '${staging.path}/hooked/',
        httpClient: http,
        verify: verify,
        extract: extract,
        apply: apply,
        beforeExtract: () async {
          order.add('beforeExtract');
        },
      );
      await hooked.runCloudUpdate(
        manifest: OtaManifest.fromJson(<String, dynamic>{
          'version': '2.0.0',
          'package_url': 'https://cdn.example/ota.tar.gz',
        }),
      );
      await hooked.close();
      expect(order, ['verify', 'beforeExtract', 'extract']);
    });

    test('cloud verify failure refuses apply', () async {
      verify.error = StateError('bad sig');

      await session.runCloudUpdate(
        manifest: OtaManifest.fromJson(<String, dynamic>{
          'version': '2.0.0',
          'package_url': 'https://cdn.example/ota.tar.gz',
        }),
      );

      expect(verify.calls, 1);
      expect(extract.calls, 0);
      expect(apply.fullCalls, 0);
      expect(events.last.phase, OtaPhase.fail);
      expect(events.last.errorCode, 'verify_failed');
      expect(events.map((e) => e.phase), isNot(contains(OtaPhase.ok)));
    });

    test('host HTTP pull verifies then applies with host mode', () async {
      await session.runHostHttpSession(
        manifest: OtaManifest.fromJson(<String, dynamic>{
          'version': '0.0.0-host',
          'package_url': 'http://192.168.55.2:8765/ota-package.tar.gz',
        }),
      );

      expect(verify.calls, 1);
      expect(apply.fullCalls, 1);
      expect(events.map((e) => e.phase), contains(OtaPhase.verifying));
      expect(events.last.phase, OtaPhase.ok);
      expect(
        http.downloads,
        contains('http://192.168.55.2:8765/ota-package.tar.gz'),
      );
      expect(
        http.downloads,
        contains('http://192.168.55.2:8765/ota-package.tar.gz.sig'),
      );

      final transferring = events.where((e) => e.phase == OtaPhase.transferring);
      expect(transferring, isNotEmpty);
      expect(transferring.last.ingress, OtaIngressKind.host);
    });

    test('progress percent is monotonic within transferring', () async {
      var last = 0;
      http.downloadHandler = (url, dest, {onProgress}) async {
        final file = File(dest);
        await file.parent.create(recursive: true);
        if (url.endsWith('.sig')) {
          await file.writeAsString('sig');
          onProgress?.call(64, 64);
          return;
        }
        for (final step in <int>[20, 40, 60, 80, 100]) {
          last = step;
          onProgress?.call(step, 100);
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        await file.writeAsString('package-bytes');
      };

      await session.runHostHttpSession(
        manifest: OtaManifest.fromJson(<String, dynamic>{
          'version': '0.0.0-host',
          'package_url': 'http://192.168.55.2:9/ota-package.tar.gz',
        }),
      );

      final percents = events
          .where((e) => e.phase == OtaPhase.transferring)
          .map((e) => e.percent)
          .toList();
      for (var i = 1; i < percents.length; i++) {
        expect(percents[i], greaterThanOrEqualTo(percents[i - 1]));
      }
      expect(last, 100);
    });

    test('emits writing progress on stream and logs to ota.log', () async {
      apply.writingSteps = <OtaProgress>[
        const OtaProgress(
          phase: OtaPhase.writing,
          percent: 0,
          bytesReceived: 0,
          bytesTotal: 100,
          message: 'writing rootfs',
        ),
        const OtaProgress(
          phase: OtaPhase.writing,
          percent: 100,
          bytesReceived: 100,
          bytesTotal: 100,
          message: 'writing rootfs',
        ),
        const OtaProgress(
          phase: OtaPhase.writing,
          percent: 0,
          bytesReceived: 0,
          bytesTotal: 50,
          message: 'writing kernel',
        ),
        const OtaProgress(
          phase: OtaPhase.writing,
          percent: 100,
          bytesReceived: 50,
          bytesTotal: 50,
          message: 'writing kernel',
        ),
        const OtaProgress(
          phase: OtaPhase.arming,
          percent: 100,
          message: 'rebooting',
        ),
        const OtaProgress(
          phase: OtaPhase.ok,
          percent: 100,
          message: 'apply ok',
        ),
      ];

      await session.runHostHttpSession(
        manifest: OtaManifest.fromJson(<String, dynamic>{
          'version': '0.0.0-host',
          'package_url': 'http://192.168.55.2:9/ota-package.tar.gz',
        }),
      );

      final writing = events.where((e) => e.phase == OtaPhase.writing).toList();
      expect(
        writing.map((e) => e.message),
        containsAll(<String>['writing rootfs', 'writing kernel']),
      );
      expect(writing.any((e) => e.percent == 0), isTrue);
      expect(writing.any((e) => e.percent == 100), isTrue);
      expect(events.last.phase, OtaPhase.ok);
      final logText = await File('${staging.path}/ota.log').readAsString();
      expect(logText, contains('phase=writing'));
      expect(logText, contains('writing kernel'));
    });
  });

  group('AbSlot letter helpers', () {
    final slot = AbSlot();

    test('otherLetter and part labels', () {
      expect(slot.otherLetter('A'), 'B');
      expect(slot.otherLetter('B'), 'A');
      expect(slot.rootfsPartForLetter('A'), 'rootfs_a');
      expect(slot.rootfsPartForLetter('B'), 'rootfs_b');
      expect(slot.bootPartForLetter('A'), 'boot');
      expect(slot.bootPartForLetter('B'), 'boot_b');
    });

    test('normalizeLetter rejects junk', () {
      expect(() => slot.normalizeLetter('C'), throwsStateError);
    });
  });

  group('OtaIngress', () {
    test('CloudIngress and HostHttpIngress both require verify', () {
      expect(const CloudIngress().requireVerify, isTrue);
      expect(const HostHttpIngress().requireVerify, isTrue);
      expect(const LocalStagingIngress().requireVerify, isTrue);
      expect(
        const LocalStagingIngress(requireVerify: false).requireVerify,
        isFalse,
      );
    });
  });
}
