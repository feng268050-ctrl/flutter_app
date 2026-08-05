import 'dart:io';
import 'dart:typed_data';

import 'ota_constants.dart';
import 'process_runner.dart';

/// Parsed LWS A/B slot marker at misc @ 1 MiB.
final class SlotState {
  const SlotState({
    required this.active,
    required this.tryBoot,
    required this.previous,
    required this.triesRemaining,
  });

  /// `A` or `B`.
  final String active;

  /// `0`, `A`, or `B`.
  final String tryBoot;

  /// `A` or `B`.
  final String previous;

  final int triesRemaining;

  static const factoryDefault = SlotState(
    active: 'A',
    tryBoot: '0',
    previous: 'A',
    triesRemaining: 0,
  );
}

/// Board partition / misc slot helpers (ported from `ab-slot-lib.sh`).
final class AbSlot {
  AbSlot({
    ProcessRunner? processRunner,
    this.miscOffset = kAbMiscOffset,
    this.defaultTries = kAbDefaultTries,
  }) : _proc = processRunner ?? ProcessRunner();

  final ProcessRunner _proc;
  final int miscOffset;
  final int defaultTries;

  static final _magic = Uint8List.fromList(
    <int>[0x4c, 0x57, 0x53, 0x41, 0x42, 0x00, 0x01, 0x00],
  );

  String normalizeLetter(String letter) {
    switch (letter) {
      case 'A':
      case 'a':
        return 'A';
      case 'B':
      case 'b':
        return 'B';
      default:
        throw StateError('invalid letter: $letter');
    }
  }

  String otherLetter(String letter) {
    switch (normalizeLetter(letter)) {
      case 'A':
        return 'B';
      case 'B':
        return 'A';
      default:
        throw StateError('invalid letter: $letter');
    }
  }

  String bootPartForLetter(String letter) {
    return normalizeLetter(letter) == 'A' ? 'boot' : 'boot_b';
  }

  String rootfsPartForLetter(String letter) {
    return normalizeLetter(letter) == 'A' ? 'rootfs_a' : 'rootfs_b';
  }

  Future<String?> partByLabel(String label) async {
    final byLabel = File('/dev/disk/by-partlabel/$label');
    if (await byLabel.exists()) {
      return byLabel.path;
    }
    final blockDir = Directory('/sys/class/block');
    if (!await blockDir.exists()) {
      return null;
    }
    await for (final entity in blockDir.list()) {
      final name = entity.uri.pathSegments.last;
      if (!name.startsWith('mmcblk') || !name.contains('p')) {
        continue;
      }
      final partition = File('${entity.path}/partition');
      if (!await partition.exists()) {
        continue;
      }
      final uevent = File('${entity.path}/uevent');
      if (!await uevent.exists()) {
        continue;
      }
      final text = await uevent.readAsString();
      for (final line in text.split('\n')) {
        if (line.startsWith('PARTNAME=') && line.substring(9) == label) {
          return '/dev/$name';
        }
      }
    }
    return null;
  }

  Future<String> requirePart(String label) async {
    final node = await partByLabel(label);
    if (node == null || node.isEmpty) {
      throw StateError('partition PARTLABEL=$label not found');
    }
    // Prefer the real block node — RandomAccessFile open on by-partlabel
    // symlinks has failed with PathNotFoundException (ENOENT) on device.
    return _resolvePath(node);
  }

  Future<int> blockSizeBytes(String device) async {
    final resolved = await _resolvePath(device);
    final name = resolved.split('/').last;
    final sectorsFile = File('/sys/class/block/$name/size');
    if (await sectorsFile.exists()) {
      final sectors = int.tryParse((await sectorsFile.readAsString()).trim());
      if (sectors != null) {
        return sectors * 512;
      }
    }
    final result = await _proc.run('blockdev', <String>['--getsize64', device]);
    if (result.exitCode == 0) {
      final n = int.tryParse('${result.stdout}'.trim());
      if (n != null) {
        return n;
      }
    }
    throw StateError('cannot determine size of $device');
  }

  Future<String?> currentRootDev() async {
    final mountinfo = File('/proc/self/mountinfo');
    if (!await mountinfo.exists()) {
      return null;
    }
    String? majMin;
    for (final line in (await mountinfo.readAsString()).split('\n')) {
      final parts = line.split(' ');
      if (parts.length > 4 && parts[4] == '/') {
        majMin = parts[2];
        break;
      }
    }
    if (majMin == null || majMin.isEmpty) {
      return null;
    }
    final sysLink = Link('/sys/dev/block/$majMin');
    String sysPath;
    try {
      sysPath = await sysLink.resolveSymbolicLinks();
    } catch (_) {
      return null;
    }
    final name = sysPath.split('/').last;
    final dev = '/dev/$name';
    if (!await File(dev).exists()) {
      return null;
    }
    return dev;
  }

  Future<String?> partLabelForDev(String device) async {
    final resolved = await _resolvePath(device);
    final name = resolved.split('/').last;
    final uevent = File('/sys/class/block/$name/uevent');
    if (!await uevent.exists()) {
      return null;
    }
    for (final line in (await uevent.readAsString()).split('\n')) {
      if (line.startsWith('PARTNAME=')) {
        return line.substring(9);
      }
    }
    return null;
  }

  Future<String> currentRootLetter() async {
    final rootDev = await currentRootDev();
    if (rootDev == null) {
      throw StateError('cannot identify the block device mounted as /');
    }
    final label = await partLabelForDev(rootDev);
    switch (label) {
      case 'rootfs_a':
        return 'A';
      case 'rootfs_b':
        return 'B';
      default:
        throw StateError(
          'current root is not PARTLABEL=rootfs_a/rootfs_b (got $label)',
        );
    }
  }

  Future<bool> sameBlockDevice(String a, String b) async {
    final ra = await _resolvePath(a);
    final rb = await _resolvePath(b);
    return ra == rb;
  }

  Future<bool> slotMarkerValid() async {
    final misc = await partByLabel('misc');
    if (misc == null) {
      return false;
    }
    final bytes = await _readDeviceBytes(misc, miscOffset, 8);
    if (bytes.length < 8) {
      return false;
    }
    for (var i = 0; i < 8; i++) {
      if (bytes[i] != _magic[i]) {
        return false;
      }
    }
    return true;
  }

  Future<SlotState> slotRead() async {
    final misc = await partByLabel('misc');
    if (misc == null) {
      return SlotState.factoryDefault;
    }
    final bytes = await _readDeviceBytes(misc, miscOffset, 16);
    if (bytes.length < 12) {
      return SlotState.factoryDefault;
    }
    if (bytes[0] != 0x4c ||
        bytes[1] != 0x57 ||
        bytes[2] != 0x53 ||
        bytes[3] != 0x41 ||
        bytes[4] != 0x42) {
      return SlotState.factoryDefault;
    }
    return SlotState(
      active: _letterOrA(bytes[8]),
      tryBoot: _tryBootField(bytes[9]),
      previous: _letterOrA(bytes[10]),
      triesRemaining: bytes[11],
    );
  }

  Future<void> slotWrite({
    required String active,
    required String tryBoot,
    required String previous,
    int tries = 0,
  }) async {
    final a = normalizeLetter(active);
    final p = normalizeLetter(previous);
    var t = tryBoot;
    switch (t) {
      case '0':
      case 'A':
      case 'B':
        break;
      case 'a':
        t = 'A';
      case 'b':
        t = 'B';
      default:
        throw StateError('invalid try_boot: $tryBoot');
    }
    final misc = await requirePart('misc');
    final block = Uint8List(64);
    block.setRange(0, 8, _magic);
    block[8] = a.codeUnitAt(0);
    block[9] = t == '0' ? 0 : t.codeUnitAt(0);
    block[10] = p.codeUnitAt(0);
    block[11] = tries & 0xff;
    await _writeDeviceBytes(misc, miscOffset, block);
    await _proc.run('sync', const <String>[]);
  }

  /// Backup running FIT: `boot` → `boot_b` (rollback copy before try-boot write).
  Future<void> backupBootToBootB() async {
    final bootDev = await requirePart('boot');
    final bootBDev = await requirePart('boot_b');
    await _proc.runChecked(
      'dd',
      <String>[
        'if=$bootDev',
        'of=$bootBDev',
        'bs=4M',
        'status=none',
        'conv=fsync',
      ],
      errorPrefix: 'dd boot→boot_b',
    );
    await _proc.run('sync', const <String>[]);
  }

  /// Backup FIT boot → boot_b, then write [fitImage] → boot (no progress).
  Future<void> armTryBootFit(String fitImage) async {
    final img = File(fitImage);
    if (!await img.exists()) {
      throw StateError('missing try FIT: $fitImage');
    }
    await backupBootToBootB();
    final bootDev = await requirePart('boot');
    await _proc.runChecked(
      'dd',
      <String>[
        'if=$fitImage',
        'of=$bootDev',
        'bs=4M',
        'status=none',
        'conv=fsync',
      ],
      errorPrefix: 'dd try-FIT→boot',
    );
    await _proc.run('sync', const <String>[]);
  }

  Future<void> reboot() async {
    await _proc.run('sync', const <String>[]);
    final real = File('/usr/bin/systemctl.real');
    final exe =
        await real.exists() ? '/usr/bin/systemctl.real' : 'systemctl';
    await _proc.run(exe, const <String>['reboot', '--no-block']);
  }

  Future<String> _resolvePath(String path) async {
    try {
      return await Link(path).resolveSymbolicLinks();
    } catch (_) {
      return path;
    }
  }

  String _letterOrA(int b) {
    if (b == 65) {
      return 'A';
    }
    if (b == 66) {
      return 'B';
    }
    return 'A';
  }

  String _tryBootField(int b) {
    if (b == 0 || b == 48) {
      return '0';
    }
    if (b == 65) {
      return 'A';
    }
    if (b == 66) {
      return 'B';
    }
    return '0';
  }

  Future<Uint8List> _readDeviceBytes(
    String device,
    int offset,
    int count,
  ) async {
    final tmp = await File(
      '${Directory.systemTemp.path}/lws-ab-rd-${DateTime.now().microsecondsSinceEpoch}',
    ).create();
    try {
      await _proc.runChecked(
        'dd',
        <String>[
          'if=$device',
          'of=${tmp.path}',
          'bs=1',
          'skip=$offset',
          'count=$count',
          'status=none',
        ],
        errorPrefix: 'dd read misc',
      );
      return Uint8List.fromList(await tmp.readAsBytes());
    } finally {
      try {
        await tmp.delete();
      } catch (_) {}
    }
  }

  Future<void> _writeDeviceBytes(
    String device,
    int offset,
    Uint8List data,
  ) async {
    final tmp = await File(
      '${Directory.systemTemp.path}/lws-ab-wr-${DateTime.now().microsecondsSinceEpoch}',
    ).create();
    try {
      await tmp.writeAsBytes(data, flush: true);
      await _proc.runChecked(
        'dd',
        <String>[
          'if=${tmp.path}',
          'of=$device',
          'bs=1',
          'seek=$offset',
          'conv=notrunc',
          'status=none',
        ],
        errorPrefix: 'dd write misc',
      );
    } finally {
      try {
        await tmp.delete();
      } catch (_) {}
    }
  }
}
