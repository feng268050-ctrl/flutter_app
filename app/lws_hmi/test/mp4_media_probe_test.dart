import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_video/application/mp4_media_probe.dart';

void main() {
  test('Mp4MediaProbe reads duration and size from minimal moov', () async {
    final bytes = _buildMinimalMp4(
      timescale: 1000,
      durationTicks: 47500,
      width: 1920,
      height: 1080,
    );
    final dir = await Directory.systemTemp.createTemp('mp4-probe-');
    final file = File('${dir.path}/t.mp4');
    await file.writeAsBytes(bytes);
    addTearDown(() async {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });

    final info = await Mp4MediaProbe.probeFile(file);
    expect(info, isNotNull);
    expect(info!.durationMs, 47500);
    expect(info.resolution, '1920x1080');
  });

  test('Mp4MediaProbe returns null for non-mp4', () async {
    final dir = await Directory.systemTemp.createTemp('mp4-probe-bad-');
    final file = File('${dir.path}/x.bin');
    await file.writeAsBytes([1, 2, 3, 4]);
    addTearDown(() async {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });
    expect(await Mp4MediaProbe.probeFile(file), isNull);
  });
}

Uint8List _buildMinimalMp4({
  required int timescale,
  required int durationTicks,
  required int width,
  required int height,
}) {
  final mvhd = BytesBuilder();
  mvhd.add([0, 0, 0, 0]);
  mvhd.add(_be32(0));
  mvhd.add(_be32(0));
  mvhd.add(_be32(timescale));
  mvhd.add(_be32(durationTicks));
  mvhd.add(_be32(0x00010000));
  mvhd.add([0x01, 0x00]);
  mvhd.add(List<int>.filled(10, 0));
  mvhd.add(List<int>.filled(36, 0));
  mvhd.add(List<int>.filled(24, 0));
  mvhd.add(_be32(2));
  final mvhdBox = _box('mvhd', mvhd.takeBytes());

  final tkhd = BytesBuilder();
  tkhd.add([0, 0, 0, 7]);
  tkhd.add(_be32(0));
  tkhd.add(_be32(0));
  tkhd.add(_be32(1));
  tkhd.add(_be32(0));
  tkhd.add(_be32(durationTicks));
  tkhd.add(List<int>.filled(8, 0));
  tkhd.add([0, 0, 0, 0, 0, 0, 0, 0]);
  tkhd.add(List<int>.filled(36, 0));
  tkhd.add(_be32(width << 16));
  tkhd.add(_be32(height << 16));
  final tkhdBox = _box('tkhd', tkhd.takeBytes());

  final mdhd = BytesBuilder();
  mdhd.add([0, 0, 0, 0]);
  mdhd.add(_be32(0));
  mdhd.add(_be32(0));
  mdhd.add(_be32(timescale));
  mdhd.add(_be32(durationTicks));
  mdhd.add([0x55, 0xc4, 0x00, 0x00]);
  final mdhdBox = _box('mdhd', mdhd.takeBytes());
  final hdlr = _box('hdlr', [
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    ...'vide'.codeUnits,
    ...List<int>.filled(12, 0),
    0,
  ]);
  final mdia = _box('mdia', [...mdhdBox, ...hdlr]);
  final trak = _box('trak', [...tkhdBox, ...mdia]);
  final moov = _box('moov', [...mvhdBox, ...trak]);
  final ftyp = _box('ftyp', [
    ...'isom'.codeUnits,
    ..._be32(0x200),
    ...'isom'.codeUnits,
    ...'iso2'.codeUnits,
  ]);
  return Uint8List.fromList([...ftyp, ...moov]);
}

List<int> _box(String type, List<int> payload) {
  final size = 8 + payload.length;
  return [..._be32(size), ...type.codeUnits, ...payload];
}

List<int> _be32(int v) => [
      (v >> 24) & 0xff,
      (v >> 16) & 0xff,
      (v >> 8) & 0xff,
      v & 0xff,
    ];
