import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/l10n/app_localizations_en.dart';
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
    final l10n = AppLocalizationsEn();
    expect(ProcessVideoFormat.workMode(ProcessType.spotWelding, l10n), 'Spot welding');
    expect(ProcessVideoFormat.material(record, l10n), 'Stainless Steel');
  });

  testWidgets('empty Videos tab', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
    // Column headers stay visible with zero recordings.
    expect(find.text('Recording Time'), findsOneWidget);
    expect(find.text('Process'), findsOneWidget);
    expect(find.text('Material'), findsOneWidget);
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('Operations'), findsOneWidget);
  });

  testWidgets('populated row and cancel delete', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
    expect(find.text('Spot welding'), findsOneWidget);
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

  testWidgets('Upload disabled when already uploaded', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _MemRepo()
      ..seed(
        ProcessVideoRecord(
          id: 1,
          videoId: 'done',
          videoPath: '/tmp/done.mp4',
          processType: ProcessType.spotWelding,
          processParametersJson: '{}',
          fileSize: 1,
          durationMs: 1000,
          createTimeMs: 1,
          uploadStatus: ProcessVideoUploadStatus.videoUploaded,
        ),
      );

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
    final upload = tester.widget<CyberButton>(
      find.widgetWithText(CyberButton, 'Upload'),
    );
    expect(upload.onPressed, isNull);
  });

  testWidgets('Upload shows progress then done', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _MemRepo()
      ..seed(
        ProcessVideoRecord(
          id: 2,
          videoId: 'up1',
          videoPath: '/tmp/up.mp4',
          processType: ProcessType.continuousWelding,
          processParametersJson: '{}',
          fileSize: 1,
          durationMs: 2000,
          createTimeMs: 2,
          uploadStatus: ProcessVideoUploadStatus.coverUploaded,
        ),
      );
    final finish = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: VideosTab(
            repository: repo,
            uploadVideo: (videoId, {listener}) async {
              listener?.onMetadataPhaseStarted();
              await finish.future;
              listener?.onVideoProgress(40);
              listener?.onVideoProgress(100);
              listener?.onFinishedSuccess();
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(find.text('Upload recording?'), findsOneWidget);
    await tester.tap(find.text('Upload').last);
    await tester.pump();
    expect(find.text('Uploading cover…'), findsOneWidget);
    finish.complete();
    await tester.pumpAndSettle();
    expect(find.text('Upload complete'), findsOneWidget);
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
  Future<List<ProcessVideoRecord>> listPendingCoverUploads({
    int limit = 50,
  }) async =>
      _rows
          .where((r) => r.uploadStatus == 0)
          .take(limit)
          .toList(growable: false);

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
