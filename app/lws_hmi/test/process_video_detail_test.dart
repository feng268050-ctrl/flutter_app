import 'dart:io';

import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/videos_tab.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_repository.dart';
import 'package:lws_hmi/features/process_video/presentation/process_video_detail_page.dart';
import 'package:lws_hmi/features/settings/application/common_settings_scope.dart';
import 'package:cyber_hal/locale.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('detail opens with fixture record and missing file soft-fails',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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

    expect(find.byKey(const ValueKey('call-back-home-button')), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Back'), findsNothing);
    expect(find.text('Parameter Recording'), findsOneWidget);
    // WordBoundaryLabel paints whitespace-separated tokens as separate Texts.
    expect(find.text('Continuous'), findsOneWidget);
    expect(find.text('Welding'), findsOneWidget);
    expect(find.text('Aluminum'), findsOneWidget);
    expect(find.text('Alloy'), findsOneWidget);
    expect(find.text('Unable to play this recording'), findsOneWidget);
  });

  testWidgets(
    'detail shows mm-based parameters as in when CommonSettings unit is Imperial',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late final _MemRepo repo;
      late final LocaleSettings store;
      await tester.runAsync(() async {
        repo = _MemRepo()
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
                thickness: 5, // 5mm -> 0.20in
                parameters: ProcessParameters({
                  'process.swing_width': 5,
                }),
              ).toJsonString(),
              fileSize: 1,
              durationMs: 4000,
              createTimeMs: 1,
            ),
          );
        final tmpDir = await Directory.systemTemp.createTemp('lws-hmi-test-');
        addTearDown(() {
          try {
            tmpDir.deleteSync(recursive: true);
          } catch (_) {}
        });
        store = LocaleSettings(
          preferencePath: '${tmpDir.path}/locale.conf',
        );
        await store.setUnit(UnitSystem.imperial);
      });

      await tester.pumpWidget(
        CommonSettingsScope(
          store: store,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: ProcessVideoDetailPage(
              args: ProcessVideoDetailArgs(recordId: 3, repository: repo),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(find.text('Thickness:'), findsOneWidget);
      expect(find.text('Scan Width:'), findsOneWidget);
      // 5mm / 25 = 0.2 -> parameterValue renders 2 decimals => 0.20
      // Value + unit share one Text.rich, so match the combined span text.
      expect(find.textContaining('0.20'), findsWidgets);
      expect(find.textContaining(' in'), findsWidgets);
    },
  );
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
