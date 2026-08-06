import 'dart:async';
import 'dart:io';

import 'ab_slot.dart';
import 'dd_writer.dart';
import 'ota_constants.dart';
import 'ota_phase.dart';
import 'ota_progress.dart';
import 'process_runner.dart';

typedef ApplyProgressSink = Future<void> Function(OtaProgress progress);

/// Full-system / OEM staged apply owned by Dart (calls `dd` / slot helpers).
class OtaApply {
  OtaApply({
    AbSlot? slot,
    DdWriter? ddWriter,
    ProcessRunner? processRunner,
  })  : _slot = slot ?? AbSlot(processRunner: processRunner),
        _dd = ddWriter ?? DdWriter(processRunner: processRunner),
        _proc = processRunner ?? ProcessRunner();

  final AbSlot _slot;
  final DdWriter _dd;
  final ProcessRunner _proc;

  String _join(String stagingDir, String name) {
    if (stagingDir.endsWith('/')) {
      return '$stagingDir$name';
    }
    return '$stagingDir/$name';
  }

  Future<void> _setStatus(String stagingDir, String status) async {
    final path = _join(stagingDir, kApplyStatusFileName);
    await File(path).writeAsString('$status\n', flush: true);
    await _proc.run('sync', const <String>[]);
  }

  /// OEM-only: write `oem.img` then reboot (no A/B letter switch).
  Future<void> applyOemOnly({
    required String stagingDir,
    required OtaIngressKind ingress,
    required ApplyProgressSink emit,
  }) async {
    await _ensureUserdata();
    await _setStatus(stagingDir, 'running');
    try {
      final oemImg = _join(stagingDir, kOemImgFileName);
      if (!await File(oemImg).exists()) {
        throw StateError('missing $oemImg');
      }
      await emit(
        OtaProgress(
          phase: OtaPhase.writing,
          percent: 0,
          ingress: ingress,
          message: 'writing oem',
        ),
      );
      final oemDev = await _slot.requirePart('oem');
      await _refuseUbootTargets(targets: <String>[oemDev]);
      final oemBytes = await File(oemImg).length();
      final oemCap = await _slot.blockSizeBytes(oemDev);
      if (oemBytes > oemCap) {
        throw StateError('oem.img too large');
      }
      await _dd.writeImage(
        imagePath: oemImg,
        devicePath: oemDev,
        onProgress: (written, total) {
          final pct = total <= 0 ? 0 : (written * 90 / total).floor().clamp(0, 90);
          unawaitedEmit(
            emit,
            OtaProgress(
              phase: OtaPhase.writing,
              percent: pct,
              bytesReceived: written,
              bytesTotal: total,
              ingress: ingress,
              message: 'writing oem',
            ),
          );
        },
      );
      await emit(
        OtaProgress(
          phase: OtaPhase.arming,
          percent: 100,
          ingress: ingress,
          message: 'rebooting',
        ),
      );
      await _setStatus(stagingDir, 'ok');
      await emit(
        OtaProgress(
          phase: OtaPhase.ok,
          percent: 100,
          ingress: ingress,
          message: 'oem apply ok',
        ),
      );
      // Pause so UI can show the auto-reboot notice before reboot.
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      await _slot.reboot();
    } catch (e) {
      await _setStatus(stagingDir, 'fail');
      rethrow;
    }
  }

  /// Full A/B apply: inactive rootfs + optional oem + try-boot FIT + reboot.
  Future<void> applyFullSystem({
    required String stagingDir,
    required OtaIngressKind ingress,
    required ApplyProgressSink emit,
    bool cameFromArchive = true,
  }) async {
    await _ensureUserdata();
    await _setStatus(stagingDir, 'running');
    try {
      final bootImg = _join(stagingDir, kBootImgFileName);
      final bootBImg = _join(stagingDir, kBootBImgFileName);
      final rootfsImg = _join(stagingDir, kRootfsImgFileName);
      final oemImg = _join(stagingDir, kOemImgFileName);

      for (final path in <String>[bootImg, bootBImg, rootfsImg]) {
        if (!await File(path).exists()) {
          throw StateError('missing $path');
        }
        if (path.contains('uboot')) {
          throw StateError('refusing path $path');
        }
      }

      if (!cameFromArchive) {
        await _verifyLooseDigests(stagingDir, bootImg, bootBImg, rootfsImg, oemImg);
      }

      final currentRootDev = await _slot.currentRootDev();
      if (currentRootDev == null) {
        throw StateError(
          'cannot identify the block device mounted as /; refusing upgrade',
        );
      }
      final active = await _slot.currentRootLetter();
      var markerValid = await _slot.slotMarkerValid();
      var meta = await _slot.slotRead();
      if (!markerValid) {
        await _slot.slotWrite(
          active: active,
          tryBoot: '0',
          previous: active,
          tries: 0,
        );
        meta = SlotState(
          active: active,
          tryBoot: '0',
          previous: active,
          triesRemaining: 0,
        );
      }
      if (meta.tryBoot != '0') {
        throw StateError(
          'try-boot ${meta.tryBoot} is still pending; wait for boot confirmation before upgrading',
        );
      }
      if (meta.active != active) {
        throw StateError(
          'slot metadata active=${meta.active} disagrees with mounted root=$active',
        );
      }

      final inactive = _slot.otherLetter(active);
      final rootLab = _slot.rootfsPartForLetter(inactive);
      final stageBoot = inactive == 'A' ? bootImg : bootBImg;
      final rootDev = await _slot.requirePart(rootLab);
      final bootDev = await _slot.requirePart('boot');
      final bootBDev = await _slot.requirePart('boot_b');

      if (await _slot.sameBlockDevice(rootDev, currentRootDev)) {
        throw StateError(
          'refusing to overwrite mounted root device $currentRootDev ($rootLab)',
        );
      }
      await _refuseUbootTargets(targets: <String>[bootDev, bootBDev, rootDev]);

      final bootBytes = await File(stageBoot).length();
      final rootBytes = await File(rootfsImg).length();
      final bootCap = await _slot.blockSizeBytes(bootDev);
      final rootCap = await _slot.blockSizeBytes(rootDev);
      if (bootBytes > bootCap) {
        throw StateError('boot.img ($bootBytes) > boot ($bootCap)');
      }
      if (rootBytes > rootCap) {
        throw StateError('rootfs.img ($rootBytes) > $rootLab ($rootCap)');
      }

      // Same sequence as retired host stream make upgrade (upgrade-remote.sh):
      //   rootfs → backup-boot → FIT (kernel) → oem → arm
      // Progress = stream-file-progress.py one-file mode (each image 0–100%).
      // message is a stable UI label key (see SystemUpgradePage).
      final hasOem = await File(oemImg).exists();

      Future<void> writeOneImage({
        required String imagePath,
        required String devicePath,
        required String label,
      }) async {
        final imageBytes = await File(imagePath).length();
        await emit(
          OtaProgress(
            phase: OtaPhase.writing,
            percent: 0,
            bytesReceived: 0,
            bytesTotal: imageBytes,
            ingress: ingress,
            message: label,
          ),
        );
        await _dd.writeImage(
          imagePath: imagePath,
          devicePath: devicePath,
          onProgress: (written, total) {
            final pct = total <= 0
                ? 0
                : (written * 100 ~/ total).clamp(0, 100);
            unawaitedEmit(
              emit,
              OtaProgress(
                phase: OtaPhase.writing,
                percent: pct,
                bytesReceived: written,
                bytesTotal: total,
                ingress: ingress,
                message: label,
              ),
            );
          },
        );
        await emit(
          OtaProgress(
            phase: OtaPhase.writing,
            percent: 100,
            bytesReceived: imageBytes,
            bytesTotal: imageBytes,
            ingress: ingress,
            message: label,
          ),
        );
      }

      await writeOneImage(
        imagePath: rootfsImg,
        devicePath: rootDev,
        label: 'writing rootfs',
      );

      // backup-boot is part of kernel apply; UI stays on "writing kernel" at 0%.
      await emit(
        OtaProgress(
          phase: OtaPhase.writing,
          percent: 0,
          bytesReceived: 0,
          bytesTotal: 0,
          ingress: ingress,
          message: 'writing kernel',
        ),
      );
      await _slot.backupBootToBootB();

      await writeOneImage(
        imagePath: stageBoot,
        devicePath: bootDev,
        label: 'writing kernel',
      );

      if (hasOem) {
        final oemDev = await _slot.requirePart('oem');
        await _refuseUbootTargets(targets: <String>[oemDev]);
        final oemBytes = await File(oemImg).length();
        final oemCap = await _slot.blockSizeBytes(oemDev);
        if (oemBytes > oemCap) {
          throw StateError('oem.img too large');
        }
        await writeOneImage(
          imagePath: oemImg,
          devicePath: oemDev,
          label: 'writing oem',
        );
      }

      await _slot.slotWrite(
        active: active,
        tryBoot: inactive,
        previous: active,
        tries: _slot.defaultTries,
      );

      await emit(
        OtaProgress(
          phase: OtaPhase.arming,
          percent: 100,
          ingress: ingress,
          message: 'rebooting',
        ),
      );
      await _setStatus(stagingDir, 'ok');
      await emit(
        OtaProgress(
          phase: OtaPhase.ok,
          percent: 100,
          ingress: ingress,
          message: 'apply ok',
        ),
      );
      await _proc.run('sync', const <String>[]);
      // Pause so UI can show the auto-reboot notice before reboot.
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      await _slot.reboot();
    } catch (e) {
      await _setStatus(stagingDir, 'fail');
      rethrow;
    }
  }

  Future<void> _ensureUserdata() async {
    if (!await Directory('/userdata').exists()) {
      throw StateError('/userdata not mounted');
    }
  }

  Future<void> _refuseUbootTargets({required List<String> targets}) async {
    final uboot = await _slot.partByLabel('uboot');
    if (uboot == null) {
      return;
    }
    for (final t in targets) {
      if (await _slot.sameBlockDevice(t, uboot)) {
        throw StateError('refusing to write uboot device');
      }
    }
  }

  Future<void> _verifyLooseDigests(
    String stagingDir,
    String bootImg,
    String bootBImg,
    String rootfsImg,
    String oemImg,
  ) async {
    for (final img in <String>[bootImg, bootBImg, rootfsImg]) {
      await _verifyFileDigest(stagingDir, img);
    }
    if (await File(oemImg).exists()) {
      final sidecar = File('$oemImg.sha256');
      if (await sidecar.exists()) {
        await _verifyFileDigest(stagingDir, oemImg);
      }
    }
  }

  Future<void> _verifyFileDigest(String stagingDir, String img) async {
    final want = await _readDigest(stagingDir, img);
    if (want == null) {
      throw StateError('missing digest for $img');
    }
    final result = await _proc.run('sha256sum', <String>[img]);
    if (result.exitCode != 0) {
      throw StateError('sha256sum failed for $img');
    }
    final got = '${result.stdout}'.trim().split(RegExp(r'\s+')).first;
    if (got.toLowerCase() != want.toLowerCase()) {
      throw StateError('digest mismatch for $img');
    }
  }

  Future<String?> _readDigest(String stagingDir, String img) async {
    final sidecar = File('$img.sha256');
    if (await sidecar.exists()) {
      final line = (await sidecar.readAsString()).trim();
      if (line.isNotEmpty) {
        return line.split(RegExp(r'\s+')).first;
      }
    }
    final manifest = File(_join(stagingDir, 'manifest.json'));
    if (!await manifest.exists()) {
      return null;
    }
    final base = img.split('/').last;
    final text = await manifest.readAsString();
    final hex = RegExp(r'[0-9a-fA-F]{64}');
    for (final line in text.split('\n')) {
      if (line.contains(base)) {
        final m = hex.firstMatch(line);
        if (m != null) {
          return m.group(0);
        }
      }
    }
    return null;
  }
}

void unawaitedEmit(ApplyProgressSink emit, OtaProgress progress) {
  // Fire-and-forget progress during dd chunks; session coalesces via stream.
  unawaited(emit(progress));
}
