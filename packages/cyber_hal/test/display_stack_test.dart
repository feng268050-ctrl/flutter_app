import 'package:cyber_hal/sys_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DisplayStackProbe', () {
    test('image stamp weston', () async {
      final stack = await DisplayStackProbe(
        imageStampPath: '/etc/fake',
        environment: const {},
        fileExists: (p) async => p == '/etc/fake',
        readFile: (_) async => 'weston\n',
      ).detect();
      expect(stack, DisplayStack.weston);
      expect(stack.mouseSettings.scrollSpeed, isFalse);
    });

    test('image stamp flutter-pi preferred over WAYLAND_DISPLAY', () async {
      final stack = await DisplayStackProbe(
        imageStampPath: '/etc/fake',
        environment: const {'WAYLAND_DISPLAY': 'wayland-0'},
        fileExists: (p) async => p == '/etc/fake',
        readFile: (_) async => 'flutter-pi',
      ).detect();
      expect(stack, DisplayStack.flutterPi);
      expect(stack.mouseSettings.pointerAxes, isTrue);
    });

    test('WAYLAND_DISPLAY fallback when no stamps', () async {
      final stack = await DisplayStackProbe(
        imageStampPath: '/etc/missing',
        environment: const {'WAYLAND_DISPLAY': 'wayland-0'},
        fileExists: (_) async => false,
      ).detect();
      expect(stack, DisplayStack.weston);
    });

    test('no stamp no wayland → flutterPi or unknown', () async {
      final stack = await DisplayStackProbe(
        imageStampPath: '/etc/missing',
        environment: const {},
        fileExists: (_) async => false,
      ).detect();
      expect(
        stack == DisplayStack.flutterPi || stack == DisplayStack.unknown,
        isTrue,
      );
    });

    test('default stamp path is /etc/display-stack', () {
      expect(
        DisplayStackProbe.defaultImageStampPath,
        '/etc/display-stack',
      );
    });

    test('legacy /etc/hmi stamp used when new path missing', () async {
      final stack = await DisplayStackProbe(
        environment: const {},
        fileExists: (p) async =>
            p == DisplayStackProbe.legacyImageStampPath,
        readFile: (p) async {
          expect(p, DisplayStackProbe.legacyImageStampPath);
          return 'weston\n';
        },
      ).detect();
      expect(stack, DisplayStack.weston);
    });
  });

  group('MouseSettingAvailability', () {
    test('weston hides pi-only knobs', () {
      const a = MouseSettingAvailability.weston;
      expect(a.naturalScroll, isTrue);
      expect(a.pointerSpeed, isTrue);
      expect(a.pointerSize, isTrue);
      expect(a.primaryButton, isTrue);
      expect(a.scrollSpeed, isFalse);
      expect(a.pointerAxes, isFalse);
    });
  });

  test('displayLabel', () {
    expect(DisplayStack.flutterPi.displayLabel, 'Flutter-pi');
    expect(DisplayStack.weston.displayLabel, 'Weston');
    expect(DisplayStack.unknown.displayLabel, 'Unknown');
  });
}
