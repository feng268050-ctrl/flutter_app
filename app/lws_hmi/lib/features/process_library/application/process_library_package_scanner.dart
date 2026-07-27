import 'dart:io';

import 'package:lws_hmi/features/process_library/application/process_library_importer.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// A discovered offline / OTA process-library package directory.
final class ProcessLibraryPackageCandidate {
  const ProcessLibraryPackageCandidate({
    required this.directoryPath,
    required this.defaultSource,
    required this.libraryVersion,
    required this.modelMatched,
    required this.supportedModels,
    required this.rowCount,
  });

  final String directoryPath;
  final String defaultSource;
  final String libraryVersion;
  final bool modelMatched;
  final List<String> supportedModels;
  final int rowCount;

  Directory get directory => Directory(directoryPath);
}

/// Scans fixed drop zones and common USB media mounts for import packages.
final class ProcessLibraryPackageScanner {
  ProcessLibraryPackageScanner({
    this.deviceModel = '',
    this.extraRoots = const [],
    this.includeDefaultRoots = true,
  });

  final String deviceModel;
  final List<String> extraRoots;
  final bool includeDefaultRoots;

  /// MTP / operator drop zone under HMI state.
  static String get incomingRoot =>
      '${OsPaths.varHmi}/incoming/process-library';

  /// OTA staging drop zone.
  static const otaRoot = '/userdata/ota/process-library';

  Future<List<ProcessLibraryPackageCandidate>> scan() async {
    final found = <String, ProcessLibraryPackageCandidate>{};

    Future<void> consider(String path, String defaultSource) async {
      final dir = Directory(path);
      if (!await dir.exists()) {
        return;
      }
      await _collectFromRoot(
        dir,
        defaultSource: defaultSource,
        into: found,
      );
    }

    if (includeDefaultRoots) {
      await consider(incomingRoot, 'usb');
      await consider(otaRoot, 'ota');
    }
    for (final root in extraRoots) {
      await consider(root, 'usb');
    }

    if (includeDefaultRoots) {
      for (final mediaRoot in const ['/run/media', '/media']) {
        final root = Directory(mediaRoot);
        if (!await root.exists()) {
          continue;
        }
        try {
          await for (final entity in root.list(followLinks: false)) {
            if (entity is! Directory) {
              continue;
            }
            // /run/media/<user>/<volume> or /media/<volume>
            await for (final child in entity.list(followLinks: false)) {
              if (child is Directory) {
                await _collectFromRoot(
                  child,
                  defaultSource: 'usb',
                  into: found,
                  maxDepth: 2,
                );
              }
            }
            await _collectFromRoot(
              entity,
              defaultSource: 'usb',
              into: found,
              maxDepth: 1,
            );
          }
        } catch (_) {
          // Best-effort media scan; ignore permission errors.
        }
      }
    }

    final list = found.values.toList(growable: false);
    list.sort((a, b) {
      if (a.modelMatched != b.modelMatched) {
        return a.modelMatched ? -1 : 1;
      }
      return b.libraryVersion.compareTo(a.libraryVersion);
    });
    return list;
  }

  Future<void> _collectFromRoot(
    Directory root, {
    required String defaultSource,
    required Map<String, ProcessLibraryPackageCandidate> into,
    int maxDepth = 1,
  }) async {
    await _tryAddPackage(root, defaultSource: defaultSource, into: into);
    if (maxDepth <= 0) {
      return;
    }
    try {
      await for (final entity in root.list(followLinks: false)) {
        if (entity is Directory) {
          await _collectFromRoot(
            entity,
            defaultSource: defaultSource,
            into: into,
            maxDepth: maxDepth - 1,
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _tryAddPackage(
    Directory dir, {
    required String defaultSource,
    required Map<String, ProcessLibraryPackageCandidate> into,
  }) async {
    final manifest = File('${dir.path}/manifest.json');
    if (!await manifest.exists()) {
      return;
    }
    try {
      final peek = ProcessLibraryImporter.peekManifest(
        await manifest.readAsString(),
        deviceModel: deviceModel,
      );
      if (peek == null) {
        return;
      }
      final key = dir.absolute.path;
      into[key] = ProcessLibraryPackageCandidate(
        directoryPath: key,
        defaultSource: peek.source.isNotEmpty ? peek.source : defaultSource,
        libraryVersion: peek.libraryVersion,
        modelMatched: peek.modelMatched,
        supportedModels: peek.supportedModels,
        rowCount: peek.rowCount,
      );
    } catch (_) {}
  }
}
