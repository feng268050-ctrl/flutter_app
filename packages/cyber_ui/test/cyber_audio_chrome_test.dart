import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CyberVolumeSlider reports progress', (tester) async {
    var value = 40;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CyberVolumeSlider(
            percent: value,
            onChanged: (v) => value = v,
            onChangeEnd: (v) => value = v,
          ),
        ),
      ),
    );
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byIcon(Icons.volume_mute), findsOneWidget);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
  });

  testWidgets('CyberAudioPlayerCard play invokes callback', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CyberAudioPlayerCard(
            isPlaying: false,
            position: Duration.zero,
            duration: const Duration(seconds: 10),
            seekEnabled: false,
            onPlayPause: () => taps++,
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.play_circle));
    await tester.pump();
    expect(taps, 1);
  });
}
