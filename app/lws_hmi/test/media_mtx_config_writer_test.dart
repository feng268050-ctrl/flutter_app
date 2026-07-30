import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/ip_camera/application/media_mtx_config_writer.dart';

void main() {
  test('renderYaml matches product PR0/PR1 contract', () {
    final yaml = MediaMtxConfigWriter.renderYaml(cameraHost: '192.168.1.100');
    expect(yaml, contains('source: rtsp://192.168.1.100/PR0'));
    expect(yaml, contains('source: rtsp://192.168.1.100/PR1'));
    expect(yaml, contains('rtspTransport: udp'));
    expect(yaml, contains('sourceOnDemand: no'));
    expect(yaml, contains('logDestinations: [stdout]'));
  });

  test('write skips identical rewrite', () async {
    final dir = await Directory.systemTemp.createTemp('mtx-cfg-');
    final path = '${dir.path}/mediamtx.yaml';
    final writer = MediaMtxConfigWriter(configPath: path);
    await writer.write(cameraHost: '10.0.0.2');
    final first = await File(path).lastModified();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await writer.write(cameraHost: '10.0.0.2');
    final second = await File(path).lastModified();
    expect(second, first);
    await writer.write(cameraHost: '10.0.0.3');
    final body = await File(path).readAsString();
    expect(body, contains('10.0.0.3'));
    await dir.delete(recursive: true);
  });
}
