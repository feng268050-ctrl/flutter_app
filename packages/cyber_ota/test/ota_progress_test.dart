import 'dart:convert';
import 'dart:io';

import 'package:cyber_ota/cyber_ota.dart';
import 'package:test/test.dart';

void main() {
  group('OtaProgress json', () {
    test('round-trips WS payload fields', () {
      const progress = OtaProgress(
        phase: OtaPhase.transferring,
        percent: 42,
        bytesReceived: 420,
        bytesTotal: 1000,
        ingress: OtaIngressKind.host,
        message: 'Receiving host upload',
        errorCode: '',
        updatedAtMs: 1234567890,
      );

      final json = progress.toJson(updatedAtMsOverride: 1234567890);
      expect(json['phase'], 'transferring');
      expect(json['percent'], 42);
      expect(json['bytes_received'], 420);
      expect(json['bytes_total'], 1000);
      expect(json['ingress'], 'host');
      expect(json['message'], 'Receiving host upload');
      expect(json['error_code'], '');
      expect(json['updated_at_ms'], 1234567890);

      final restored = OtaProgress.fromJson(json);
      expect(restored.phase, OtaPhase.transferring);
      expect(restored.percent, 42);
      expect(restored.ingress, OtaIngressKind.host);
    });

    test('jsonEncode matches WS contract keys', () {
      const progress = OtaProgress(
        phase: OtaPhase.fail,
        errorCode: 'verify_failed',
        ingress: OtaIngressKind.cloud,
      );
      final keys = (jsonDecode(jsonEncode(progress.toJson())) as Map).keys;
      expect(
        keys,
        containsAll(<String>[
          'phase',
          'percent',
          'bytes_received',
          'bytes_total',
          'ingress',
          'message',
          'error_code',
          'updated_at_ms',
        ]),
      );
    });
  });

  group('OtaLog', () {
    test('appends progress lines to ota.log', () async {
      final dir = await Directory.systemTemp.createTemp('ota-log-');
      final log = OtaLog('${dir.path}/');
      await log.progress(
        const OtaProgress(
          phase: OtaPhase.writing,
          percent: 60,
          ingress: OtaIngressKind.host,
          message: 'rootfs written',
        ),
      );
      final text = await File('${dir.path}/ota.log').readAsString();
      expect(text, contains('phase=writing'));
      expect(text, contains('percent=60'));
      expect(text, contains('ingress=host'));
      await dir.delete(recursive: true);
    });
  });
}
