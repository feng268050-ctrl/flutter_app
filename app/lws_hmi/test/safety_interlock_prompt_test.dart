import 'dart:async';

import 'package:cyber_alarm_ui/cyber_alarm_ui.dart';
import 'package:cyber_hal/output.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_mode/presentation/emergency_stop_prompt.dart';
import 'package:lws_hmi/features/process_mode/presentation/key_switch_off_prompt.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/warn_alarm_sound.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

Future<void> _pumpPromptFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  final overflow = tester.takeException();
  expect(
    overflow == null ||
        overflow.toString().contains('overflowed') ||
        overflow.toString().contains('A RenderFlex overflowed') ||
        overflow.toString().contains('ink_sparkle'),
    isTrue,
  );
}

Widget _promptHost({required Widget Function(BuildContext context) builder}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en', 'US'),
    home: Builder(builder: builder),
  );
}

void main() {
  tearDown(() {
    KeySwitchOffPrompt.debugReset();
    EmergencyStopPrompt.debugReset();
  });

  group('KeySwitchOffPrompt.chromeForMiscAlarmEnabled', () {
    test('Misc on → WARN', () {
      expect(
        KeySwitchOffPrompt.chromeForMiscAlarmEnabled(true),
        WarnChromeStyle.warn,
      );
    });

    test('Misc off → INFO', () {
      expect(
        KeySwitchOffPrompt.chromeForMiscAlarmEnabled(false),
        WarnChromeStyle.info,
      );
    });
  });

  group('KeySwitchOffPrompt.maybeShow', () {
    testWidgets('Misc on shows WARN frost with sound', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final audio = _FakeAudio();
      final sound = WarnAlarmSound(audio);
      addTearDown(sound.dispose);

      late BuildContext hostContext;
      await tester.pumpWidget(
        _promptHost(
          builder: (context) {
            hostContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      );

      unawaited(
        KeySwitchOffPrompt.maybeShow(
          hostContext,
          miscAlarmEnabled: true,
          sound: sound,
        ),
      );
      await _pumpPromptFrames(tester);

      expect(
        find.byKey(const ValueKey('key-switch-off-prompt-warn')),
        findsOneWidget,
      );
      expect(KeySwitchOffPrompt.showingChrome, WarnChromeStyle.warn);
      expect(audio.loopCalls, isNotEmpty);
      expect(KeySwitchOffPrompt.promptedForCurrentKeyOff, isTrue);

      unawaited(
        KeySwitchOffPrompt.maybeShow(
          hostContext,
          miscAlarmEnabled: true,
          sound: sound,
        ),
      );
      await _pumpPromptFrames(tester);
      expect(
        find.byKey(const ValueKey('key-switch-off-prompt-warn')),
        findsOneWidget,
        reason: 'edge latched until reset',
      );
    });

    testWidgets('Misc off shows INFO frost without sound', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final audio = _FakeAudio();
      final sound = WarnAlarmSound(audio);
      addTearDown(sound.dispose);

      late BuildContext hostContext;
      await tester.pumpWidget(
        _promptHost(
          builder: (context) {
            hostContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      );

      unawaited(
        KeySwitchOffPrompt.maybeShow(
          hostContext,
          miscAlarmEnabled: false,
          sound: sound,
        ),
      );
      await _pumpPromptFrames(tester);

      expect(
        find.byKey(const ValueKey('key-switch-off-prompt-info')),
        findsOneWidget,
      );
      expect(KeySwitchOffPrompt.showingChrome, WarnChromeStyle.info);
      expect(audio.loopCalls, isEmpty);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(KeySwitchOffPrompt.isShowing, isFalse);
      expect(KeySwitchOffPrompt.promptedForCurrentKeyOff, isTrue);
    });

    testWidgets('reset clears latch and dismisses', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late BuildContext hostContext;
      await tester.pumpWidget(
        _promptHost(
          builder: (context) {
            hostContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      );

      unawaited(
        KeySwitchOffPrompt.maybeShow(
          hostContext,
          miscAlarmEnabled: false,
        ),
      );
      await _pumpPromptFrames(tester);
      expect(KeySwitchOffPrompt.isShowing, isTrue);

      KeySwitchOffPrompt.reset();
      await tester.pumpAndSettle();
      expect(KeySwitchOffPrompt.isShowing, isFalse);
      expect(KeySwitchOffPrompt.promptedForCurrentKeyOff, isFalse);
    });
  });

  group('KeySwitchOffPrompt.presentLaserEnableKeyOffBlock', () {
    testWidgets('always INFO even when Misc alarm is on', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final audio = _FakeAudio();
      final sound = WarnAlarmSound(audio);
      addTearDown(sound.dispose);

      late BuildContext hostContext;
      await tester.pumpWidget(
        _promptHost(
          builder: (context) {
            hostContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      );

      unawaited(
        KeySwitchOffPrompt.presentLaserEnableKeyOffBlock(
          hostContext,
          sound: sound,
        ),
      );
      await _pumpPromptFrames(tester);

      expect(
        find.byKey(const ValueKey('key-switch-off-prompt-info')),
        findsOneWidget,
      );
      expect(KeySwitchOffPrompt.showingChrome, WarnChromeStyle.info);
      expect(audio.loopCalls, isEmpty);
    });

    testWidgets('replaces WARN frost with INFO', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final audio = _FakeAudio();
      final sound = WarnAlarmSound(audio);
      addTearDown(sound.dispose);

      late BuildContext hostContext;
      await tester.pumpWidget(
        _promptHost(
          builder: (context) {
            hostContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      );

      unawaited(
        KeySwitchOffPrompt.maybeShow(
          hostContext,
          miscAlarmEnabled: true,
          sound: sound,
        ),
      );
      await _pumpPromptFrames(tester);
      expect(
        find.byKey(const ValueKey('key-switch-off-prompt-warn')),
        findsOneWidget,
      );

      unawaited(
        KeySwitchOffPrompt.presentLaserEnableKeyOffBlock(
          hostContext,
          sound: sound,
        ),
      );
      await _pumpPromptFrames(tester);
      expect(
        find.byKey(const ValueKey('key-switch-off-prompt-warn')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('key-switch-off-prompt-info')),
        findsOneWidget,
      );
    });
  });

  group('EmergencyStopPrompt', () {
    testWidgets('edge shows INFO prompt', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late BuildContext hostContext;
      await tester.pumpWidget(
        _promptHost(
          builder: (context) {
            hostContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      );

      unawaited(EmergencyStopPrompt.maybeShow(hostContext));
      await _pumpPromptFrames(tester);

      expect(
        find.byKey(const ValueKey('emergency-stop-prompt')),
        findsOneWidget,
      );
      expect(find.text('Emergency Stop Is Active'), findsOneWidget);
      expect(EmergencyStopPrompt.isShowing, isTrue);
    });

    testWidgets('confirm dismisses prompt', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late BuildContext hostContext;
      await tester.pumpWidget(
        _promptHost(
          builder: (context) {
            hostContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      );

      unawaited(EmergencyStopPrompt.maybeShow(hostContext));
      await _pumpPromptFrames(tester);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('emergency-stop-prompt')), findsNothing);
      expect(EmergencyStopPrompt.isShowing, isFalse);
    });

    testWidgets('reset dismisses prompt', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late BuildContext hostContext;
      await tester.pumpWidget(
        _promptHost(
          builder: (context) {
            hostContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      );

      unawaited(EmergencyStopPrompt.maybeShow(hostContext));
      await _pumpPromptFrames(tester);
      EmergencyStopPrompt.reset();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('emergency-stop-prompt')), findsNothing);
      expect(EmergencyStopPrompt.isShowing, isFalse);
      expect(EmergencyStopPrompt.promptedForCurrentEStop, isFalse);
    });

    testWidgets('Enable Laser block uses same INFO prompt', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late BuildContext hostContext;
      await tester.pumpWidget(
        _promptHost(
          builder: (context) {
            hostContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      );

      unawaited(EmergencyStopPrompt.presentLaserEnableBlock(hostContext));
      await _pumpPromptFrames(tester);

      expect(
        find.byKey(const ValueKey('emergency-stop-prompt')),
        findsOneWidget,
      );
    });
  });
}

final class _FakeAudio implements MediaAudioController {
  final loopCalls = <String>[];

  @override
  bool get isPlaying => false;

  @override
  Stream<bool> get playing => const Stream.empty();

  @override
  Future<void> playAsset(String assetKey) async {}

  @override
  Future<void> playLoopingAsset(String assetKey) async {
    loopCalls.add(assetKey);
  }

  @override
  Future<void> playOneShotAsset(String assetKey) async {}

  @override
  Future<void> warmClickSession() async {}

  @override
  bool get hasActiveLoop => loopCalls.isNotEmpty;

  @override
  Future<void> stop() async {}

  @override
  Future<void> setVolumePercent(int percent) async {}

  @override
  Future<int> getVolumePercent() async => 80;

  @override
  Future<void> dispose() async {}
}
