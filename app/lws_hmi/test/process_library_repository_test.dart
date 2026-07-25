import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/application/process_library_importer.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_library/infrastructure/sqlite_process_library_repository.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Database database;
  late SqliteProcessLibraryRepository repository;

  setUp(() async {
    database = sqlite3.openInMemory();
    repository = SqliteProcessLibraryRepository(database: database);
    await repository.open();
  });

  tearDown(() async {
    await repository.close();
    database.dispose();
  });

  test('built-in replacement preserves user processes', () async {
    final user = _preset(
      uuid: 'user-1',
      kind: ProcessPresetKind.user,
      source: 'user',
      builtin: false,
    );
    await repository.saveUser(user);
    await repository.replaceBuiltins(
      source: 'bundled',
      meta: _meta(version: '1.0.0', rows: 1),
      presets: [
        _preset(
          uuid: 'built-in-1',
          kind: ProcessPresetKind.quick,
          source: 'bundled',
          builtin: true,
        ),
      ],
    );
    await repository.replaceBuiltins(
      source: 'bundled',
      meta: _meta(version: '1.1.0', rows: 1),
      presets: [
        _preset(
          uuid: 'built-in-2',
          kind: ProcessPresetKind.quick,
          source: 'bundled',
          builtin: true,
        ),
      ],
    );

    expect(await repository.findByUuid('user-1'), isNotNull);
    expect(await repository.findByUuid('built-in-1'), isNull);
    expect(await repository.findByUuid('built-in-2'), isNotNull);
    expect((await repository.metaFor('bundled'))!.libraryVersion, '1.1.0');
  });

  test('built-in rows cannot be changed through user CRUD', () async {
    await expectLater(
      repository.saveUser(
        _preset(
          uuid: 'built-in',
          kind: ProcessPresetKind.engineerPreset,
          source: 'bundled',
          builtin: true,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('import verifies hash and is idempotent', () async {
    final payload = jsonEncode({
      'schema_version': 1,
      'library_version': '1.4.0',
      'presets': [
        {
          'uuid': 'preset-1',
          'name': 'Weld 1',
          'kind': 'quick',
          'process_type': 0,
          'material_type': 1,
          'thickness': 1.5,
          'gear': 1,
          'parameters': {'process.laser_power': 50},
        },
      ],
    });
    final hash = sha256.convert(utf8.encode(payload)).toString();
    final bundle = _MemoryAssetBundle({
      'manifest.json': jsonEncode({
        'schema_version': 1,
        'libraries': [
          {
            'source': 'bundled',
            'library_version': '1.4.0',
            'asset': 'library.json',
            'content_sha256': hash,
            'supported_models': ['ynh960'],
            'row_count': 1,
          },
        ],
      }),
      'library.json': payload,
    });
    final importer = ProcessLibraryImporter(
      repository: repository,
      deviceModel: 'wrong-board-id',
      deviceModelLoader: () async => 'YNH960',
      bundle: bundle,
      manifestAsset: 'manifest.json',
    );

    expect(
      (await importer.importBundled()).status,
      ProcessLibraryImportStatus.imported,
    );
    expect(
      (await importer.importBundled()).status,
      ProcessLibraryImportStatus.current,
    );
    expect(await repository.findByUuid('preset-1'), isNotNull);
    final engineers = (await repository.list())
        .where((preset) => preset.kind == ProcessPresetKind.engineerPreset)
        .toList();
    expect(engineers, hasLength(1));
    expect(engineers.single.name, 'Stainless Steel-1.5mm');
    expect((await repository.metaFor('bundled'))!.rowCount, 2);
  });

  test('same-version import backfills missing engineer presets', () async {
    await repository.replaceBuiltins(
      source: 'bundled',
      meta: _meta(version: '1.4.0', rows: 1),
      presets: [
        _preset(
          uuid: 'preset-1',
          kind: ProcessPresetKind.quick,
          source: 'bundled',
          builtin: true,
        ),
      ],
    );
    // Pretend an older build installed the same asset hash without derivation.
    database.execute(
      "UPDATE process_library_meta SET content_sha256 = ? WHERE source = 'bundled'",
      [
        sha256
            .convert(
              utf8.encode(
                jsonEncode({
                  'schema_version': 1,
                  'library_version': '1.4.0',
                  'presets': [
                    {
                      'uuid': 'preset-1',
                      'name': 'Weld 1',
                      'kind': 'quick',
                      'process_type': 0,
                      'material_type': 1,
                      'thickness': 1.5,
                      'gear': 1,
                      'parameters': {'process.laser_power': 50},
                    },
                  ],
                }),
              ),
            )
            .toString(),
      ],
    );

    final payload = jsonEncode({
      'schema_version': 1,
      'library_version': '1.4.0',
      'presets': [
        {
          'uuid': 'preset-1',
          'name': 'Weld 1',
          'kind': 'quick',
          'process_type': 0,
          'material_type': 1,
          'thickness': 1.5,
          'gear': 1,
          'parameters': {'process.laser_power': 50},
        },
      ],
    });
    final hash = sha256.convert(utf8.encode(payload)).toString();
    final importer = ProcessLibraryImporter(
      repository: repository,
      deviceModel: 'ynh960',
      bundle: _MemoryAssetBundle({
        'manifest.json': jsonEncode({
          'schema_version': 1,
          'libraries': [
            {
              'source': 'bundled',
              'library_version': '1.4.0',
              'asset': 'library.json',
              'content_sha256': hash,
              'supported_models': ['*'],
              'row_count': 1,
            },
          ],
        }),
        'library.json': payload,
      }),
      manifestAsset: 'manifest.json',
    );

    expect(
      (await importer.importBundled()).status,
      ProcessLibraryImportStatus.imported,
    );
    expect(
      (await repository.list())
          .where((preset) => preset.kind == ProcessPresetKind.engineerPreset),
      hasLength(1),
    );
  });

  test('validation rejects unsafe ranges before a transaction', () async {
    final invalid = _preset(
      uuid: 'invalid',
      kind: ProcessPresetKind.quick,
      source: 'bundled',
      builtin: true,
      power: 101,
    );
    await expectLater(
      repository.replaceBuiltins(
        source: 'bundled',
        meta: _meta(version: '1.0.0', rows: 1),
        presets: [invalid],
      ),
      throwsA(isA<ProcessLibraryValidationException>()),
    );
    expect(await repository.list(), isEmpty);
  });

  test('failed built-in replacement rolls back rows and metadata', () async {
    await repository.replaceBuiltins(
      source: 'bundled',
      meta: _meta(version: '1.0.0', rows: 1),
      presets: [
        _preset(
          uuid: 'old',
          kind: ProcessPresetKind.quick,
          source: 'bundled',
          builtin: true,
        ),
      ],
    );
    database.execute('''
CREATE TRIGGER reject_bad_process
BEFORE INSERT ON process_presets
WHEN NEW.uuid = 'bad'
BEGIN
  SELECT RAISE(ABORT, 'rejected by test');
END;
''');

    await expectLater(
      repository.replaceBuiltins(
        source: 'bundled',
        meta: _meta(version: '2.0.0', rows: 2),
        presets: [
          _preset(
            uuid: 'new',
            kind: ProcessPresetKind.quick,
            source: 'bundled',
            builtin: true,
          ),
          _preset(
            uuid: 'bad',
            kind: ProcessPresetKind.quick,
            source: 'bundled',
            builtin: true,
          ),
        ],
      ),
      throwsA(anything),
    );

    expect(await repository.findByUuid('old'), isNotNull);
    expect(await repository.findByUuid('new'), isNull);
    expect((await repository.metaFor('bundled'))!.libraryVersion, '1.0.0');
  });

  test('backup and restore recover a consistent snapshot', () async {
    final directory = await Directory.systemTemp.createTemp('process-library-');
    final backup = '${directory.path}/backup.db';
    addTearDown(() => directory.delete(recursive: true));
    await repository.saveUser(
      _preset(
        uuid: 'saved',
        kind: ProcessPresetKind.user,
        source: 'user',
        builtin: false,
      ),
    );
    await repository.backupTo(backup);
    await repository.backupTo(backup);
    await repository.deleteUser('saved');
    expect(await repository.findByUuid('saved'), isNull);

    await repository.restoreFrom(backup);

    expect(await repository.findByUuid('saved'), isNotNull);
  });

  test('bundled import cannot overwrite a user uuid', () async {
    await repository.saveUser(
      _preset(
        uuid: 'protected',
        kind: ProcessPresetKind.user,
        source: 'user',
        builtin: false,
      ),
    );

    await expectLater(
      repository.replaceBuiltins(
        source: 'bundled',
        meta: _meta(version: '1.0.0', rows: 1),
        presets: [
          _preset(
            uuid: 'protected',
            kind: ProcessPresetKind.quick,
            source: 'bundled',
            builtin: true,
          ),
        ],
      ),
      throwsStateError,
    );

    final preserved = await repository.findByUuid('protected');
    expect(preserved!.kind, ProcessPresetKind.user);
    expect(await repository.metaFor('bundled'), isNull);
  });

  test('restore rejects an incompatible schema without changing live data',
      () async {
    final directory = await Directory.systemTemp.createTemp('process-restore-');
    final backup = '${directory.path}/backup.db';
    addTearDown(() => directory.delete(recursive: true));
    await repository.saveUser(
      _preset(
        uuid: 'live',
        kind: ProcessPresetKind.user,
        source: 'user',
        builtin: false,
      ),
    );
    await repository.backupTo(backup);
    final incompatible = sqlite3.open(backup);
    incompatible.execute('PRAGMA user_version = 2');
    incompatible.dispose();

    await expectLater(
      repository.restoreFrom(backup),
      throwsStateError,
    );

    expect(await repository.findByUuid('live'), isNotNull);
  });
}

ProcessPreset _preset({
  required String uuid,
  required ProcessPresetKind kind,
  required String source,
  required bool builtin,
  double power = 50,
}) {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  return ProcessPreset(
    uuid: uuid,
    name: uuid,
    kind: kind,
    source: source,
    isBuiltin: builtin,
    processType: ProcessType.continuousWelding,
    materialType: MaterialType.stainlessSteel,
    thickness: 1,
    gear: 1,
    parameters: ProcessParameters({'process.laser_power': power}),
    libraryVersion: builtin ? '1.0.0' : null,
    createdAtMs: now,
    updatedAtMs: now,
  );
}

ProcessLibraryMeta _meta({required String version, required int rows}) {
  return ProcessLibraryMeta(
    source: 'bundled',
    libraryVersion: version,
    schemaVersion: 1,
    contentSha256: 'hash-$version',
    installedAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
    rowCount: rows,
  );
}

final class _MemoryAssetBundle extends CachingAssetBundle {
  _MemoryAssetBundle(this.assets);
  final Map<String, String> assets;

  @override
  Future<ByteData> load(String key) async {
    final value = assets[key];
    if (value == null) {
      throw StateError('Missing asset $key');
    }
    final bytes = Uint8List.fromList(utf8.encode(value));
    return ByteData.sublistView(bytes);
  }
}
