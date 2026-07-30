import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/videos_tab.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_repository.dart';
import 'package:lws_hmi/features/process_video/presentation/process_video_detail_page.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('detail opens with fixture record and missing file soft-fails',
      (tester) async {
    final repo = _MemRepo()
      ..seed(
        ProcessVideoRecord(
          id: 3,
          videoId: 'v3',
          videoPath: '/no/such/process-video.mp4',
          processType: ProcessType.continuousWelding,
          materialType: MaterialType.aluminumAlloy,
          processParametersJson: ProcessVideoSnapshot(
            processType: ProcessType.continuousWelding,
            materialType: MaterialType.aluminumAlloy,
            parameters: ProcessParameters({'process.laser_power': 42}),
          ).toJsonString(),
          fileSize: 1,
          durationMs: 4000,
          createTimeMs: 1,
        ),
      );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: ProcessVideoDetailPage(
          args: ProcessVideoDetailArgs(recordId: 3, repository: repo),
        ),
      ),
    );
    await tester.pump();
    // dart:io File.exists runs on the real async timeline.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();

    expect(find.text('Video Details'), findsOneWidget);
    expect(find.text('Parameter recording'), findsOneWidget);
    expect(find.text('Continuous Welding'), findsOneWidget);
    expect(find.text('Aluminum Alloy'), findsOneWidget);
    expect(find.text('Unable to play this recording'), findsOneWidget);
  });
}

final class _MemRepo implements ProcessVideoRepository {
  final List<ProcessVideoRecord> _rows = [];

  void seed(ProcessVideoRecord record) => _rows.add(record);

  @override
  Future<void> open() async {}

  @override
  Future<void> close() async {}

  @override
  Future<int> count() async => _rows.length;

  @override
  Future<ProcessVideoRecord> insert(ProcessVideoRecord record) async => record;

  @override
  Future<List<ProcessVideoRecord>> list({int limit = 10, int offset = 0}) async =>
      _rows;

  @override
  Future<ProcessVideoListPage> query(ProcessVideoListQuery q) async {
    return ProcessVideoListPage(list: _rows, total: _rows.length);
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
