import 'dart:io';

import 'package:cyber_ota/cyber_ota.dart';
import 'package:test/test.dart';

void main() {
  test('OtaExtract reports monotonic archive-byte progress', () async {
    final dir = await Directory.systemTemp.createTemp('ota-extract-');
    final staging = Directory('${dir.path}/out')..createSync();
    final member = File('${dir.path}/rootfs.img');
    await member.writeAsBytes(List<int>.generate(64 * 1024, (i) => i & 0xff));

    final archive = File('${dir.path}/ota-package.tar.gz');
    final tar = await Process.run(
      'tar',
      <String>['-C', dir.path, '-czf', archive.path, 'rootfs.img'],
    );
    expect(tar.exitCode, 0, reason: '${tar.stderr}');

    final progress = <(int, int)>[];
    final extract = OtaExtract();
    await extract.extractArchive(
      archivePath: archive.path,
      stagingDir: staging.path,
      onProgress: (r, t) => progress.add((r, t)),
    );

    expect(File('${staging.path}/rootfs.img').existsSync(), isTrue);
    expect(progress.first.$1, 0);
    expect(progress.last.$1, progress.last.$2);
    expect(progress.last.$2, await archive.length());
    for (var i = 1; i < progress.length; i++) {
      expect(progress[i].$1, greaterThanOrEqualTo(progress[i - 1].$1));
    }

    await dir.delete(recursive: true);
  }, skip: !_tarAvailable() ? 'tar not available' : null);
}

bool _tarAvailable() {
  try {
    final r = Process.runSync('tar', <String>['--help']);
    return '${r.stdout}${r.stderr}'.toLowerCase().contains('tar') ||
        r.exitCode == 0;
  } catch (_) {
    return false;
  }
}
