import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/application/process_library_importer.dart';
import 'package:lws_hmi/features/process_library/application/process_library_package_scanner.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_library/infrastructure/sqlite_process_library_repository.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Database database;
  late SqliteProcessLibraryRepository repository;
  late Directory packageDir;

  setUp(() async {
    database = sqlite3.openInMemory();
    repository = SqliteProcessLibraryRepository(database: database);
    await repository.open();
    packageDir = await Directory.systemTemp.createTemp('process-lib-pkg-');
  });

  tearDown(() async {
    await repository.close();
    database.dispose();
    if (await packageDir.exists()) {
      await packageDir.delete(recursive: true);
    }
  });

  Future<void> writePackage({
    required String version,
    required String source,
    String model = 'ynh960',
    String? hashOverride,
    List<Map<String, Object?>>? presets,
  }) async {
    final presetRows = presets ??
        [
          {
            'uuid': 'preset-usb-1',
            'name': 'Weld USB',
            'kind': 'quick',
            'process_type': 0,
            'material_type': 1,
            'thickness': 1.5,
            'gear': 1,
            'parameters': {'process.laser_power': 55},
          },
        ];
    final payload = jsonEncode({
      'schema_version': 1,
      'library_version': version,
      'presets': presetRows,
    });
    final hash = hashOverride ?? sha256.convert(utf8.encode(payload)).toString();
    await File('${packageDir.path}/library.json').writeAsString(payload);
    await File('${packageDir.path}/manifest.json').writeAsString(
      jsonEncode({
        'schema_version': 1,
        'libraries': [
          {
            'source': source,
            'library_version': version,
            'asset': 'library.json',
            'content_sha256': hash,
            'supported_models': [model, '*'],
            'row_count': presetRows.length,
          },
        ],
      }),
    );
  }

  test('filesystem package imports and preserves user presets', () async {
    await repository.saveUser(
      ProcessPreset(
        uuid: 'user-keep',
        name: 'My Weld',
        kind: ProcessPresetKind.user,
        source: 'user',
        isBuiltin: false,
        processType: ProcessType.continuousWelding,
        materialType: MaterialType.stainlessSteel,
        thickness: 1.5,
        gear: 1,
        parameters: ProcessParameters({'process.laser_power': 40}),
        createdAtMs: 1,
        updatedAtMs: 1,
      ),
    );
    await writePackage(version: '2.0.0', source: 'usb');
    final importer = ProcessLibraryImporter(
      repository: repository,
      deviceModel: 'ynh960',
    );

    final audit = await importer.importPackageFromDirectory(
      packageDir,
      defaultSource: 'usb',
    );

    expect(audit.status, ProcessLibraryImportStatus.imported);
    expect(audit.toVersion, '2.0.0');
    expect(audit.preservedUserCount, 1);
    expect(audit.modelMatched, isTrue);
    expect(await repository.findByUuid('user-keep'), isNotNull);
    expect(await repository.findByUuid('preset-usb-1'), isNotNull);
    expect((await repository.metaFor('usb'))!.libraryVersion, '2.0.0');
  });

  test('hash mismatch rejects without writing', () async {
    await writePackage(
      version: '2.0.0',
      source: 'usb',
      hashOverride: '0' * 64,
    );
    final importer = ProcessLibraryImporter(
      repository: repository,
      deviceModel: 'ynh960',
    );

    final audit = await importer.importPackageFromDirectory(packageDir);
    expect(audit.status, ProcessLibraryImportStatus.rejected);
    expect(audit.errors, isNotEmpty);
    expect(await repository.metaFor('usb'), isNull);
  });

  test('older package version is rejected', () async {
    await writePackage(version: '2.0.0', source: 'usb');
    final importer = ProcessLibraryImporter(
      repository: repository,
      deviceModel: 'ynh960',
    );
    expect(
      (await importer.importPackageFromDirectory(packageDir)).status,
      ProcessLibraryImportStatus.imported,
    );

    await writePackage(version: '1.0.0', source: 'usb');
    final audit = await importer.importPackageFromDirectory(packageDir);
    expect(audit.status, ProcessLibraryImportStatus.rejected);
    expect(audit.skippedReason, 'older_version');
    expect((await repository.metaFor('usb'))!.libraryVersion, '2.0.0');
  });

  test('force re-imports same version', () async {
    await writePackage(version: '2.0.0', source: 'usb');
    final importer = ProcessLibraryImporter(
      repository: repository,
      deviceModel: 'ynh960',
    );
    expect(
      (await importer.importPackageFromDirectory(packageDir)).status,
      ProcessLibraryImportStatus.imported,
    );
    expect(
      (await importer.importPackageFromDirectory(packageDir)).status,
      ProcessLibraryImportStatus.current,
    );

    final forced = await importer.importPackageFromDirectory(
      packageDir,
      force: true,
    );
    expect(forced.status, ProcessLibraryImportStatus.imported);
    expect(forced.toVersion, '2.0.0');
    expect((await repository.metaFor('usb'))!.libraryVersion, '2.0.0');
  });

  test('force still rejects when no model matches', () async {
    await writePackage(version: '2.0.0', source: 'usb', model: 'L1 Pro');
    // Overwrite manifest without wildcard / matching model.
    await File('${packageDir.path}/manifest.json').writeAsString(
      jsonEncode({
        'schema_version': 1,
        'libraries': [
          {
            'source': 'usb',
            'library_version': '2.0.0',
            'asset': 'library.json',
            'content_sha256': sha256
                .convert(
                  utf8.encode(
                    await File('${packageDir.path}/library.json').readAsString(),
                  ),
                )
                .toString(),
            'supported_models': ['L1 Pro'],
            'row_count': 1,
          },
        ],
      }),
    );
    final importer = ProcessLibraryImporter(
      repository: repository,
      deviceModel: 'other-model',
    );

    final audit = await importer.importPackageFromDirectory(
      packageDir,
      force: true,
    );
    expect(audit.status, ProcessLibraryImportStatus.noCompatibleLibrary);
    expect(audit.skippedReason, 'no_compatible_library');
    expect(await repository.metaFor('usb'), isNull);
  });

  test('clearAll wipes presets and meta', () async {
    await writePackage(version: '2.0.0', source: 'usb');
    final importer = ProcessLibraryImporter(
      repository: repository,
      deviceModel: 'ynh960',
    );
    expect(
      (await importer.importPackageFromDirectory(packageDir)).status,
      ProcessLibraryImportStatus.imported,
    );
    await repository.saveUser(
      ProcessPreset(
        uuid: 'user-wipe',
        name: 'Wipe Me',
        kind: ProcessPresetKind.user,
        source: 'user',
        isBuiltin: false,
        processType: ProcessType.continuousWelding,
        materialType: MaterialType.stainlessSteel,
        thickness: 1.5,
        gear: 1,
        parameters: ProcessParameters({'process.laser_power': 40}),
        createdAtMs: 1,
        updatedAtMs: 1,
      ),
    );

    await repository.clearAll();
    expect(await repository.list(), isEmpty);
    expect(await repository.metaFor('usb'), isNull);
  });

  test('deleteAllUserPresets keeps builtins', () async {
    await writePackage(version: '2.0.0', source: 'usb');
    final importer = ProcessLibraryImporter(
      repository: repository,
      deviceModel: 'ynh960',
    );
    expect(
      (await importer.importPackageFromDirectory(packageDir)).status,
      ProcessLibraryImportStatus.imported,
    );
    await repository.saveUser(
      ProcessPreset(
        uuid: 'user-keep-builtins',
        name: 'User',
        kind: ProcessPresetKind.user,
        source: 'user',
        isBuiltin: false,
        processType: ProcessType.continuousWelding,
        materialType: MaterialType.stainlessSteel,
        thickness: 1.5,
        gear: 1,
        parameters: ProcessParameters({'process.laser_power': 40}),
        createdAtMs: 1,
        updatedAtMs: 1,
      ),
    );

    await repository.deleteAllUserPresets();
    final left = await repository.list();
    expect(left.every((p) => p.isBuiltin), isTrue);
    expect(left, isNotEmpty);
    expect(await repository.metaFor('usb'), isNotNull);
  });

  test('scanner finds packages under extraRoots', () async {
    await writePackage(version: '3.1.0', source: 'usb');
    final scanner = ProcessLibraryPackageScanner(
      deviceModel: 'ynh960',
      extraRoots: [packageDir.parent.path],
    );
    // Put package as child of extra root so scanner walks depth.
    final nested = Directory('${packageDir.parent.path}/scan-child')
      ..createSync();
    addTearDown(() {
      if (nested.existsSync()) {
        nested.deleteSync(recursive: true);
      }
    });
    for (final name in ['manifest.json', 'library.json']) {
      File('${packageDir.path}/$name')
          .copySync('${nested.path}/$name');
    }

    final found = await scanner.scan();
    expect(
      found.any((c) => c.directoryPath == nested.absolute.path),
      isTrue,
    );
  });
}
