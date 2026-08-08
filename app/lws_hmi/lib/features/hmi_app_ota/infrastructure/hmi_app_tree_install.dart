import 'dart:io';

import 'package:flutter/foundation.dart';

/// Installs a verified HMI staging tree into `/opt/hmi` with byte progress.
///
/// Uses plain file copies (not DdWriter): app trees are many small files, and
/// per-file `sync` would make Install crawl. Live `/opt/hmi/bin` and companion
/// `/opt/hmi/lib` paths are replaced via temp + `rename` so running binaries
/// (MediaMTX, mapped `.so`) do not hit ETXTBSY.
final class HmiAppTreeInstall {
  HmiAppTreeInstall();

  static const optHmi = '/opt/hmi';
  static const libDst = '$optHmi/lib/libapp.so';
  static const assetsDir = '$optHmi/data/flutter_assets';
  static const nextLib = '$optHmi/lib/.libapp.so.push-next';
  static const nextAssets = '$optHmi/data/.flutter_assets.push-next';
  static const oldAssets = '$optHmi/data/.flutter_assets.push-old';

  /// Copies [stagingDir] (`lib/libapp.so`, `data/flutter_assets`, optional
  /// `bin/` / extra `lib/`) into `/opt/hmi`, then atomically activates.
  Future<void> installFromStaging({
    required String stagingDir,
    void Function(int bytesWritten, int bytesTotal)? onProgress,
  }) async {
    final stage = stagingDir.endsWith('/')
        ? stagingDir.substring(0, stagingDir.length - 1)
        : stagingDir;
    final libSrc = File('$stage/lib/libapp.so');
    final assetsSrc = Directory('$stage/data/flutter_assets');
    if (!await libSrc.exists()) {
      throw StateError('missing $libSrc');
    }
    if (!await assetsSrc.exists()) {
      throw StateError('missing $assetsSrc');
    }

    final jobs = <_CopyJob>[];
    jobs.add(_CopyJob.file(src: libSrc, dest: File(nextLib)));

    await for (final entity in assetsSrc.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      if (_isPackagingJunkPath(entity.path)) {
        continue;
      }
      final rel = entity.path.substring(assetsSrc.path.length);
      final relPath = rel.startsWith('/') ? rel.substring(1) : rel;
      jobs.add(_CopyJob.file(src: entity, dest: File('$nextAssets/$relPath')));
    }

    final stageBin = Directory('$stage/bin');
    if (await stageBin.exists()) {
      await for (final entity in stageBin.list(recursive: true, followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        if (_isPackagingJunkPath(entity.path)) {
          continue;
        }
        final name = _baseName(entity);
        if (name == 'ffmpeg') {
          continue;
        }
        final rel = entity.path.substring(stageBin.path.length);
        final relPath = rel.startsWith('/') ? rel.substring(1) : rel;
        jobs.add(
          _CopyJob.file(
            src: entity,
            dest: File('$optHmi/bin/$relPath'),
            executable: true,
            replaceLive: true,
          ),
        );
      }
    }

    final stageLib = Directory('$stage/lib');
    if (await stageLib.exists()) {
      await for (final entity in stageLib.list(followLinks: false)) {
        if (_isPackagingJunkPath(entity.path)) {
          continue;
        }
        final base = _baseName(entity);
        if (base == 'libapp.so' || base.startsWith('librknnrt.so')) {
          continue;
        }
        final dest = File('$optHmi/lib/$base');
        if (entity is File) {
          jobs.add(
            _CopyJob.file(src: entity, dest: dest, replaceLive: true),
          );
        } else if (entity is Link) {
          jobs.add(
            _CopyJob.link(linkSrc: entity, dest: dest, replaceLive: true),
          );
        }
      }
    }

    var total = 0;
    for (final job in jobs) {
      total += await job.byteLength();
    }
    // Symlink-only companion sets can yield total==0 when libapp is missing
    // from jobs — libapp is always present, so total should stay > 0.
    if (total <= 0) {
      throw StateError('empty install payload under $stage');
    }

    onProgress?.call(0, total);

    try {
      await File('/var/lib/hmi/debug-app.pid').delete();
    } catch (_) {}
    try {
      await File('/var/lib/hmi/debug-app.vm-service').delete();
    } catch (_) {}
    await Directory('$optHmi/lib').create(recursive: true);
    await Directory('$optHmi/bin').create(recursive: true);
    await Directory('$optHmi/data').create(recursive: true);
    await _rmRf(nextLib);
    await _rmRf(nextAssets);
    await _rmRf(oldAssets);
    await Directory(nextAssets).create(recursive: true);

    var written = 0;
    var nextPercent = 0;
    void tick() {
      final percent = (written * 100 ~/ total).clamp(0, 100);
      if (percent >= nextPercent || written >= total) {
        onProgress?.call(written, total);
        nextPercent = (percent + 1).clamp(0, 100);
      }
    }

    for (final job in jobs) {
      final fileTotal = await job.byteLength();
      await _installJob(job);
      written += fileTotal;
      tick();
    }

    try {
      await File('$optHmi/bin/ffmpeg').delete();
    } catch (_) {}

    await Process.run('sync', const <String>[]);

    // Atomic activate (same mv dance as shell). Must run before sweeping
    // leftover `*.push-next` temps — nextLib itself ends with that suffix.
    await File(nextLib).rename(libDst);
    final liveAssets = Directory(assetsDir);
    if (await liveAssets.exists()) {
      await liveAssets.rename(oldAssets);
    }
    try {
      await Directory(nextAssets).rename(assetsDir);
    } catch (e) {
      if (await Directory(oldAssets).exists()) {
        await Directory(oldAssets).rename(assetsDir);
      }
      throw StateError('failed to activate flutter_assets: $e');
    }
    await _rmRf(oldAssets);

    // Drop legacy App-bundled RKNN + any stranded companion temps.
    for (final dirPath in <String>['$optHmi/lib', '$optHmi/bin']) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        continue;
      }
      await for (final entity in dir.list(followLinks: false)) {
        final base = _baseName(entity);
        final drop = base.startsWith('librknnrt.so') || base.endsWith('.push-next');
        if (!drop) {
          continue;
        }
        try {
          await _rmRf(entity.path);
        } catch (_) {}
      }
    }

    final engineVer = await _readEngineVersion();
    await File('$optHmi/runtime-mode.json').writeAsString(
      '{"mode":"release","engine_version":"$engineVer"}\n',
      flush: true,
    );
    await Process.run('sync', const <String>[]);
    onProgress?.call(total, total);
  }

  static Future<void> _installJob(_CopyJob job) async {
    final parent = job.dest.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    if (job.linkSrc != null) {
      final target = await job.linkSrc!.target();
      final outPath = job.replaceLive ? '${job.dest.path}.push-next' : job.dest.path;
      await _rmRf(outPath);
      await Link(outPath).create(target);
      if (job.replaceLive) {
        await _rmRf(job.dest.path);
        await Link(outPath).rename(job.dest.path);
      }
      return;
    }

    final src = job.src!;
    if (job.replaceLive) {
      final next = File('${job.dest.path}.push-next');
      try {
        await next.delete();
      } catch (_) {}
      await src.copy(next.path);
      await next.rename(job.dest.path);
    } else {
      await src.copy(job.dest.path);
    }

    if (job.executable) {
      await Process.run('chmod', ['0755', job.dest.path]);
    }
  }

  /// macOS AppleDouble / Finder metadata must never land in `/opt/hmi`.
  static bool _isPackagingJunkPath(String path) {
    final base = path.split('/').last;
    return base == '.DS_Store' || base.startsWith('._');
  }

  static String _baseName(FileSystemEntity entity) {
    if (entity.uri.pathSegments.isEmpty) {
      return entity.path.split('/').last;
    }
    return entity.uri.pathSegments.last;
  }

  static Future<String> _readEngineVersion() async {
    for (final path in <String>[
      '/usr/share/flutter/flutter-engine.version',
      '/etc/hmi/flutter-engine.version',
    ]) {
      try {
        final v = (await File(path).readAsString()).trim();
        if (v.isNotEmpty) {
          return v;
        }
      } catch (_) {}
    }
    return '3.41.9';
  }

  static Future<void> _rmRf(String path) async {
    try {
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        return;
      }
      if (type == FileSystemEntityType.directory) {
        await Directory(path).delete(recursive: true);
      } else if (type == FileSystemEntityType.link) {
        await Link(path).delete();
      } else {
        await File(path).delete();
      }
    } catch (e) {
      debugPrint('HmiAppTreeInstall: rmRf $path failed: $e');
    }
  }
}

final class _CopyJob {
  const _CopyJob._({
    this.src,
    this.linkSrc,
    required this.dest,
    this.executable = false,
    this.replaceLive = false,
  });

  factory _CopyJob.file({
    required File src,
    required File dest,
    bool executable = false,
    bool replaceLive = false,
  }) {
    return _CopyJob._(
      src: src,
      dest: dest,
      executable: executable,
      replaceLive: replaceLive,
    );
  }

  factory _CopyJob.link({
    required Link linkSrc,
    required File dest,
    bool replaceLive = false,
  }) {
    return _CopyJob._(
      linkSrc: linkSrc,
      dest: dest,
      replaceLive: replaceLive,
    );
  }

  final File? src;
  final Link? linkSrc;
  final File dest;
  final bool executable;

  /// When true, write via `dest.push-next` then rename over [dest] (busy-safe).
  final bool replaceLive;

  Future<int> byteLength() async {
    if (linkSrc != null) {
      return 0;
    }
    return src!.length();
  }
}
