import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/features/ip_camera/presentation/ip_camera_preview.dart';

class _FakePlayer extends ChangeNotifier implements IpCameraPreviewPlayer {
  _FakePlayer({this.initializeError});

  final Object? initializeError;
  bool initialized = false;
  bool played = false;
  bool disposed = false;

  @override
  Future<void> initialize() async {
    if (initializeError case final error?) {
      throw error;
    }
    initialized = true;
    notifyListeners();
  }

  @override
  Future<void> play() async {
    played = true;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    super.dispose();
  }

  @override
  bool get isInitialized => initialized;

  @override
  double get aspectRatio => 16 / 9;

  @override
  String? get errorDescription => null;

  @override
  Widget buildVideo() {
    return const ColoredBox(
      key: Key('fake-video-frame'),
      color: Colors.green,
    );
  }
}

Widget _preview({
  required IpCameraPreviewPlayerFactory playerFactory,
  IpCameraUiPhase phase = IpCameraUiPhase.connected,
  bool relayReady = true,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 640,
        height: 360,
        child: IpCameraPreview(
          rtspUrl: Uri.parse('rtsp://192.168.1.100/PR1'),
          linkPhase: phase,
          relayReady: relayReady,
          playerFactory: playerFactory,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('ready relay renders live player instead of URL placeholder', (
    tester,
  ) async {
    final player = _FakePlayer();

    await tester.pumpWidget(_preview(playerFactory: (_) => player));
    await tester.pump();

    expect(find.byKey(const Key('ip-camera-live-preview')), findsOneWidget);
    expect(find.byKey(const Key('fake-video-frame')), findsOneWidget);
    expect(find.textContaining('GStreamer surface pending'), findsNothing);
    expect(player.played, isTrue);
  });

  testWidgets('player is disposed when preview leaves ready state', (
    tester,
  ) async {
    final player = _FakePlayer();

    await tester.pumpWidget(_preview(playerFactory: (_) => player));
    await tester.pump();
    await tester.pumpWidget(
      _preview(
        playerFactory: (_) => player,
        phase: IpCameraUiPhase.connecting,
      ),
    );
    await tester.pump();

    expect(player.disposed, isTrue);
    expect(find.text('Establishing video…'), findsOneWidget);
  });

  testWidgets('missing player plugin fails softly and can retry', (
    tester,
  ) async {
    var creations = 0;
    final recovered = _FakePlayer();

    await tester.pumpWidget(
      _preview(
        playerFactory: (_) {
          creations++;
          if (creations == 1) {
            return _FakePlayer(
              initializeError: StateError('plugin unavailable'),
            );
          }
          return recovered;
        },
      ),
    );
    await tester.pump();

    expect(find.textContaining('Preview failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('fake-video-frame')), findsOneWidget);
    expect(recovered.played, isTrue);
  });
}
