import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/videos_tab.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_repository.dart';
import 'package:lws_hmi/features/process_video/presentation/process_video_format.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('format helpers', () {
    final snap = ProcessVideoSnapshot(
      processType: ProcessType.continuousWelding,
      materialType: MaterialType.stainlessSteel,
      parameters: ProcessParameters({'process.laser_power': 40}),
    );
    final record = ProcessVideoRecord(
      id: 1,
      videoId: 'v1',
      videoPath: '/tmp/a.mp4',
      processType: ProcessType.continuousWelding,
      materialType: MaterialType.stainlessSteel,
      processParametersJson: snap.toJsonString(),
      fileSize: 10,
      durationMs: 125000,
      createTimeMs: DateTime.utc(2026, 7, 28, 10, 5).millisecondsSinceEpoch,
    );
    expect(ProcessVideoFormat.duration(125000), '02:05');
    expect(ProcessVideoFormat.workMode(ProcessType.spotWelding), 'Spot Welding');
    expect(ProcessVideoFormat.material(record), 'Stainless Steel');
  });

  testWidgets('empty Videos tab', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: VideosTab(repository: _MemRepo()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No recordings'), findsOneWidget);
  });

  testWidgets('populated row and cancel delete', (tester) async {
    final repo = _MemRepo()
      ..seed(
        ProcessVideoRecord(
          id: 7,
          videoId: 'v7',
          videoPath: '/tmp/clip.mp4',
          processType: ProcessType.spotWelding,
          materialType: MaterialType.carbonSteel,
          processParametersJson: ProcessVideoSnapshot(
            processType: ProcessType.spotWelding,
            materialType: MaterialType.carbonSteel,
            parameters: ProcessParameters({'process.laser_power': 30}),
          ).toJsonString(),
          fileSize: 100,
          durationMs: 65000,
          createTimeMs: DateTime.utc(2026, 7, 28, 8, 0).millisecondsSinceEpoch,
        ),
      );

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: VideosTab(repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Spot Welding'), findsOneWidget);
    expect(find.text('Carbon Steel'), findsOneWidget);
    expect(find.text('01:05'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(find.text('Upload recording?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.countSync(), 1);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete recording?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.countSync(), 1);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    // Confirm uses CyberButton primary labeled Delete.
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(repo.countSync(), 0);
    expect(find.text('No recordings'), findsOneWidget);
  });
}

final class _MemRepo implements ProcessVideoRepository {
  final List<ProcessVideoRecord> _rows = [];

  void seed(ProcessVideoRecord record) => _rows.add(record);

  int countSync() => _rows.length;

  @override
  Future<void> open() async {}

  @override
  Future<void> close() async {}

  @override
  Future<int> count() async => _rows.length;

  @override
  Future<ProcessVideoRecord> insert(ProcessVideoRecord record) async {
    final id = (_rows.length + 1);
    final saved = ProcessVideoRecord(
      id: id,
      videoId: record.videoId,
      videoPath: record.videoPath,
      processType: record.processType,
      materialType: record.materialType,
      processParametersJson: record.processParametersJson,
      fileSize: record.fileSize,
      durationMs: record.durationMs,
      resolution: record.resolution,
      createTimeMs: record.createTimeMs,
    );
    _rows.add(saved);
    return saved;
  }

  @override
  Future<List<ProcessVideoRecord>> list({int limit = 10, int offset = 0}) async {
    final sorted = [..._rows]
      ..sort((a, b) => b.createTimeMs.compareTo(a.createTimeMs));
    return sorted.skip(offset).take(limit).toList();
  }

  @override
  Future<ProcessVideoListPage> query(ProcessVideoListQuery q) async {
    final sorted = await list(limit: 500, offset: 0);
    return ProcessVideoListPage(list: sorted, total: sorted.length);
  }

  @override
  Future<ProcessVideoRecord?> findByVideoId(String videoId) async {
    for (final row in _rows) {
      if (row.videoId == videoId) return row;
    }
    return null;
  }

  @override
  Future<bool> updateUploadState({
    required String videoId,
    required int uploadStatus,
    required int uploadProgress,
    String? coverUrl,
    String? videoUrl,
  }) async =>
      true;

  @override
  Future<ProcessVideoRecord?> getById(int id) async {
    for (final row in _rows) {
      if (row.id == id) {
        return row;
      }
    }
    return null;
  }

  @override
  Future<bool> deleteById(int id) async {
    final before = _rows.length;
    _rows.removeWhere((r) => r.id == id);
    return _rows.length < before;
  }

  @override
  Future<bool> deleteByVideoId(String videoId) async {
    final before = _rows.length;
    _rows.removeWhere((r) => r.videoId == videoId);
    return _rows.length < before;
  }
}
