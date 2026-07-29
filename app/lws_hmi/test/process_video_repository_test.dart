import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_video/application/process_video_save_handler.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/features/process_video/infrastructure/sqlite_process_video_repository.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Database database;
  late SqliteProcessVideoRepository repo;

  setUp(() {
    database = sqlite3.openInMemory();
    repo = SqliteProcessVideoRepository(database: database);
  });

  tearDown(() async {
    await repo.close();
  });

  ProcessVideoRecord sample({
    String path = '/tmp/a.mp4',
    int createTimeMs = 1000,
    ProcessType type = ProcessType.continuousWelding,
  }) {
    final snap = ProcessVideoSnapshot(
      processType: type,
      materialType: MaterialType.stainlessSteel,
      parameters: ProcessParameters({
        'process.laser_power': 50,
      }),
    );
    return ProcessVideoRecord(
      videoId: 'vid-$createTimeMs',
      videoPath: path,
      processType: type,
      materialType: MaterialType.stainlessSteel,
      processParametersJson: snap.toJsonString(),
      fileSize: 1024,
      durationMs: 5000,
      resolution: '1920x1080',
      createTimeMs: createTimeMs,
    );
  }

  test('schema create, insert, newest-first page, count', () async {
    await repo.insert(sample(createTimeMs: 100));
    await repo.insert(sample(path: '/tmp/b.mp4', createTimeMs: 200));
    await repo.insert(sample(path: '/tmp/c.mp4', createTimeMs: 300));

    expect(await repo.count(), 3);
    final page = await repo.list(limit: 2, offset: 0);
    expect(page.map((r) => r.createTimeMs), [300, 200]);
    final page2 = await repo.list(limit: 2, offset: 2);
    expect(page2.map((r) => r.createTimeMs), [100]);
  });

  test('deleteById removes row and soft-fails missing file', () async {
    final inserted = await repo.insert(sample(path: '/no/such/file.mp4'));
    expect(inserted.id, isNotNull);
    expect(await repo.deleteById(inserted.id!), isTrue);
    expect(await repo.count(), 0);
    expect(await repo.deleteById(inserted.id!), isFalse);
  });

  test('deleteById removes existing file', () async {
    final dir = await Directory.systemTemp.createTemp('pv-del-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/clip.mp4');
    await file.writeAsBytes(List<int>.filled(64, 1));
    final inserted = await repo.insert(sample(path: file.path));
    expect(await repo.deleteById(inserted.id!), isTrue);
    expect(await file.exists(), isFalse);
  });

  test('snapshot JSON round-trip', () {
    final snap = ProcessVideoSnapshot(
      processType: ProcessType.spotWelding,
      materialType: MaterialType.carbonSteel,
      thickness: 1.5,
      gear: 3,
      parameters: ProcessParameters({'process.laser_power': 40}),
      presetUuid: 'uuid-1',
      libraryVersion: 'v1',
    );
    final parsed = ProcessVideoSnapshot.fromJson(
      Map<String, Object?>.from(
        // ignore: avoid_dynamic_calls — decode via toJsonString
        (snap.toJson()),
      ),
    );
    expect(parsed.processType, ProcessType.spotWelding);
    expect(parsed.materialType, MaterialType.carbonSteel);
    expect(parsed.thickness, 1.5);
    expect(parsed.gear, 3);
    expect(parsed.presetUuid, 'uuid-1');
    expect(parsed.parameters.values['process.laser_power'], 40);
  });

  test('save handler discards missing and too-short files', () async {
    final handler = ProcessVideoSaveHandler(repository: repo);
    final snap = ProcessVideoSnapshot(
      processType: ProcessType.continuousWelding,
      parameters: ProcessParameters({'process.laser_power': 10}),
    );
    final started = DateTime.utc(2026, 7, 28, 12, 0, 0);
    expect(
      await handler.save(
        videoPath: '/missing.mp4',
        snapshot: snap,
        bytesWritten: 100,
        startedAt: started,
        completedAt: started.add(const Duration(seconds: 5)),
      ),
      ProcessVideoSaveOutcome.discardedMissingFile,
    );

    final dir = await Directory.systemTemp.createTemp('pv-save-');
    addTearDown(() => dir.delete(recursive: true));
    final shortFile = File('${dir.path}/short.mp4');
    await shortFile.writeAsBytes(List<int>.filled(32, 1));
    expect(
      await handler.save(
        videoPath: shortFile.path,
        snapshot: snap,
        bytesWritten: 32,
        startedAt: started,
        completedAt: started.add(const Duration(milliseconds: 500)),
      ),
      ProcessVideoSaveOutcome.discardedTooShort,
    );
    expect(await shortFile.exists(), isFalse);

    final okFile = File('${dir.path}/ok.mp4');
    await okFile.writeAsBytes(List<int>.filled(128, 2));
    expect(
      await handler.save(
        videoPath: okFile.path,
        snapshot: snap,
        bytesWritten: 128,
        startedAt: started,
        completedAt: started.add(const Duration(seconds: 3)),
      ),
      ProcessVideoSaveOutcome.saved,
    );
    expect(await repo.count(), 1);
    final row = (await repo.list()).single;
    expect(row.videoPath, okFile.path);
    expect(row.durationMs, 3000);
    expect(row.processType, ProcessType.continuousWelding);
  });
}
