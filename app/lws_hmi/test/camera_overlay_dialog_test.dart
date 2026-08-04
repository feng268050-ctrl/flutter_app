import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_show_overlay_applier.dart';
import 'package:lws_hmi/features/ip_camera/presentation/camera_overlay_dialog.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

final class _CountingHttp implements CameraOsdHttpClient {
  int putCount = 0;

  @override
  Future<CameraOsdHttpResponse> get(
    Uri uri, {
    required String authorization,
  }) async {
    return CameraOsdHttpResponse(
      statusCode: 200,
      body: '{"VideoOverlay":{"NameOverlay":{}}}',
    );
  }

  @override
  Future<CameraOsdHttpResponse> put(
    Uri uri, {
    required String authorization,
    Object? body,
  }) async {
    putCount++;
    return const CameraOsdHttpResponse(
      statusCode: 200,
      body: '{"errCode":200}',
    );
  }

  @override
  void close() {}
}

final class _FailingHttp implements CameraOsdHttpClient {
  @override
  Future<CameraOsdHttpResponse> get(
    Uri uri, {
    required String authorization,
  }) async {
    return const CameraOsdHttpResponse(statusCode: 500, body: '');
  }

  @override
  Future<CameraOsdHttpResponse> put(
    Uri uri, {
    required String authorization,
    Object? body,
  }) async {
    return const CameraOsdHttpResponse(statusCode: 500, body: '');
  }

  @override
  void close() {}
}

void main() {
  testWidgets('editing alone does not apply; Apply succeeds and closes',
      (tester) async {
    final http = _CountingHttp();
    final applier = CameraShowOverlayApplier(httpClient: http);
    CameraShowOverlayParams? result;

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      applier.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showCameraOverlayDialog(
                  context: context,
                  applier: applier,
                  cameraHost: '192.168.1.100',
                  machineModel: 'Laser-01',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('camera-overlay-apply')), findsOneWidget);
    expect(find.text('Change Overlay'), findsOneWidget);
    expect(find.textContaining('Position X'), findsNothing);
    expect(http.putCount, 0);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.textContaining('Position X'), findsOneWidget);
    expect(find.textContaining('Position Y'), findsOneWidget);
    expect(http.putCount, 0);

    await tester.tap(find.byKey(const Key('camera-overlay-apply')));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.enable, 1);
    expect(http.putCount, greaterThan(0));
    expect(find.byKey(const Key('camera-overlay-apply')), findsNothing);
  });

  testWidgets('Apply failure keeps dialog open', (tester) async {
    final applier = CameraShowOverlayApplier(httpClient: _FailingHttp());

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      applier.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCameraOverlayDialog(
                context: context,
                applier: applier,
                cameraHost: '192.168.1.100',
                machineModel: 'Laser-01',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('camera-overlay-apply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('camera-overlay-apply')), findsOneWidget);
    expect(find.textContaining('overlay'), findsWidgets);
  });

  testWidgets('Cancel does not apply', (tester) async {
    final http = _CountingHttp();
    final applier = CameraShowOverlayApplier(httpClient: http);

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      applier.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCameraOverlayDialog(
                context: context,
                applier: applier,
                cameraHost: '192.168.1.100',
                machineModel: 'Laser-01',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('camera-overlay-cancel')));
    await tester.pumpAndSettle();
    expect(http.putCount, 0);
    expect(find.byKey(const Key('camera-overlay-apply')), findsNothing);
  });
}
