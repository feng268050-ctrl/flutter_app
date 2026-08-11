import 'dart:io';

/// ISO BMFF (MP4) duration / resolution without `ffprobe`.
final class Mp4MediaInfo {
  const Mp4MediaInfo({
    required this.durationMs,
    this.width,
    this.height,
  });

  final int durationMs;
  final int? width;
  final int? height;

  String? get resolution {
    final w = width;
    final h = height;
    if (w == null || h == null || w <= 0 || h <= 0) {
      return null;
    }
    return '${w}x$h';
  }
}

/// Walks `moov` / `mvhd` / `trak` / `tkhd` / `mdhd` via random-access reads.
abstract final class Mp4MediaProbe {
  /// Returns null when the file is not a readable MP4 or has no positive duration.
  static Future<Mp4MediaInfo?> probeFile(File file) async {
    if (!await file.exists()) {
      return null;
    }
    final length = await file.length();
    if (length < 16) {
      return null;
    }
    final raf = await file.open();
    try {
      return await probeRandomAccess(raf, length);
    } finally {
      await raf.close();
    }
  }

  static Future<Mp4MediaInfo?> probeRandomAccess(
    RandomAccessFile raf,
    int length,
  ) async {
    var movieTimescale = 0;
    var movieDuration = 0;
    var videoTimescale = 0;
    var videoDuration = 0;
    int? width;
    int? height;

    Future<void> walk(int start, int end, int depth) async {
      if (depth > 12 || start >= end) {
        return;
      }
      var offset = start;
      while (offset + 8 <= end) {
        await raf.setPosition(offset);
        final header = await raf.read(8);
        if (header.length < 8) {
          return;
        }
        var size = _u32(header, 0);
        final type = String.fromCharCodes(header.sublist(4, 8));
        var headerLen = 8;
        if (size == 1) {
          if (offset + 16 > end) {
            return;
          }
          await raf.setPosition(offset + 8);
          final large = await raf.read(8);
          if (large.length < 8) {
            return;
          }
          size = _u64(large, 0);
          headerLen = 16;
        } else if (size == 0) {
          size = end - offset;
        }
        if (size < headerLen || offset + size > end) {
          return;
        }
        final contentStart = offset + headerLen;
        final contentEnd = offset + size;
        final payloadLen = contentEnd - contentStart;

        switch (type) {
          case 'moov':
          case 'trak':
          case 'mdia':
          case 'minf':
          case 'stbl':
            await walk(contentStart, contentEnd, depth + 1);
          case 'mvhd':
            final mv = await _readMvhd(raf, contentStart, payloadLen);
            if (mv != null) {
              movieTimescale = mv.$1;
              movieDuration = mv.$2;
            }
          case 'mdhd':
            final md = await _readMdhd(raf, contentStart, payloadLen);
            if (md != null && md.$2 > videoDuration) {
              videoTimescale = md.$1;
              videoDuration = md.$2;
            }
          case 'tkhd':
            final wh = await _readTkhdSize(raf, contentStart, payloadLen);
            if (wh != null && (width == null || width == 0)) {
              width = wh.$1;
              height = wh.$2;
            }
          case 'stsd':
            final wh = await _readStsdSize(raf, contentStart, payloadLen);
            if (wh != null && (width == null || width == 0)) {
              width = wh.$1;
              height = wh.$2;
            }
        }
        offset = contentEnd;
      }
    }

    await walk(0, length, 0);

    final durationMs = _durationMs(
      movieTimescale: movieTimescale,
      movieDuration: movieDuration,
      videoTimescale: videoTimescale,
      videoDuration: videoDuration,
    );
    if (durationMs <= 0) {
      return null;
    }
    return Mp4MediaInfo(
      durationMs: durationMs,
      width: width,
      height: height,
    );
  }

  static int _durationMs({
    required int movieTimescale,
    required int movieDuration,
    required int videoTimescale,
    required int videoDuration,
  }) {
    if (movieTimescale > 0 && movieDuration > 0) {
      return ((movieDuration * 1000) / movieTimescale).round();
    }
    if (videoTimescale > 0 && videoDuration > 0) {
      return ((videoDuration * 1000) / videoTimescale).round();
    }
    return 0;
  }

  static Future<(int, int)?> _readMvhd(
    RandomAccessFile raf,
    int start,
    int len,
  ) async {
    if (len < 20) {
      return null;
    }
    await raf.setPosition(start);
    final buf = await raf.read(len.clamp(0, 32));
    if (buf.isEmpty) {
      return null;
    }
    final version = buf[0];
    if (version == 1) {
      if (buf.length < 32) {
        return null;
      }
      return (_u32(buf, 20), _u64(buf, 24));
    }
    if (buf.length < 20) {
      return null;
    }
    return (_u32(buf, 12), _u32(buf, 16));
  }

  static Future<(int, int)?> _readMdhd(
    RandomAccessFile raf,
    int start,
    int len,
  ) async {
    if (len < 20) {
      return null;
    }
    await raf.setPosition(start);
    final buf = await raf.read(len.clamp(0, 32));
    if (buf.isEmpty) {
      return null;
    }
    final version = buf[0];
    if (version == 1) {
      if (buf.length < 32) {
        return null;
      }
      return (_u32(buf, 20), _u64(buf, 24));
    }
    if (buf.length < 20) {
      return null;
    }
    return (_u32(buf, 12), _u32(buf, 16));
  }

  /// `tkhd` width/height are 16.16 fixed-point at the end of the header.
  static Future<(int, int)?> _readTkhdSize(
    RandomAccessFile raf,
    int start,
    int len,
  ) async {
    if (len < 4) {
      return null;
    }
    await raf.setPosition(start);
    final version = (await raf.read(1)).first;
    final widthOff = version == 1 ? 88 : 76;
    if (len < widthOff + 8) {
      return null;
    }
    await raf.setPosition(start + widthOff);
    final wh = await raf.read(8);
    if (wh.length < 8) {
      return null;
    }
    final w = _u32(wh, 0) >> 16;
    final h = _u32(wh, 4) >> 16;
    if (w <= 0 || h <= 0) {
      return null;
    }
    return (w, h);
  }

  /// Visual sample entries (`avc1`, `hvc1`, …) store width/height as u16.
  static Future<(int, int)?> _readStsdSize(
    RandomAccessFile raf,
    int start,
    int len,
  ) async {
    if (len < 16) {
      return null;
    }
    await raf.setPosition(start);
    final head = await raf.read(16);
    if (head.length < 16) {
      return null;
    }
    final entryCount = _u32(head, 4);
    if (entryCount < 1) {
      return null;
    }
    final entrySize = _u32(head, 8);
    if (entrySize < 32 || 8 + entrySize > len) {
      return null;
    }
    await raf.setPosition(start + 8);
    final entry = await raf.read(entrySize.clamp(0, 64));
    if (entry.length < 32) {
      return null;
    }
    final w = _u16(entry, 24);
    final h = _u16(entry, 26);
    if (w <= 0 || h <= 0) {
      return null;
    }
    return (w, h);
  }

  static int _u16(List<int> b, int i) =>
      ((b[i] & 0xff) << 8) | (b[i + 1] & 0xff);

  static int _u32(List<int> b, int i) =>
      ((b[i] & 0xff) << 24) |
      ((b[i + 1] & 0xff) << 16) |
      ((b[i + 2] & 0xff) << 8) |
      (b[i + 3] & 0xff);

  static int _u64(List<int> b, int i) {
    final hi = _u32(b, i);
    final lo = _u32(b, i + 4);
    return (hi << 32) | lo;
  }
}
