import 'package:cyber_hal/display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DisplayStackProbe', () {
    test('runtime stamp weston wins over image flutter-pi', () {
      final stack = DisplayStackProbe(
        runtimeStampPath: '/run/fake',
        imageStampPath: '/etc/fake',
        environment: const {},
        fileExists: (p) => true,
        readFile: (p) => p.startsWith('/run') ? 'weston\n' : 'flutter-pi\n',
      ).detect();
      expect(stack, DisplayStack.weston);
      expect(stack.mouseSettings.scrollSpeed, isFalse);
    });

    test('image stamp used when runtime missing', () {
      final stack = DisplayStackProbe(
        runtimeStampPath: '/run/missing',
        imageStampPath: '/etc/fake',
        environment: const {'WAYLAND_DISPLAY': 'wayland-0'},
        fileExists: (p) => p == '/etc/fake',
        readFile: (_) => 'flutter-pi',
      ).detect();
      expect(stack, DisplayStack.flutterPi);
      expect(stack.mouseSettings.pointerAxes, isTrue);
    });

    test('WAYLAND_DISPLAY fallback when no stamps', () {
      final stack = DisplayStackProbe(
        runtimeStampPath: '/run/missing',
        imageStampPath: '/etc/missing',
        environment: const {'WAYLAND_DISPLAY': 'wayland-0'},
        fileExists: (_) => false,
      ).detect();
      expect(stack, DisplayStack.weston);
    });

    test('no stamp no wayland → flutterPi or unknown', () {
      final stack = DisplayStackProbe(
        runtimeStampPath: '/run/missing',
        imageStampPath: '/etc/missing',
        environment: const {},
        fileExists: (_) => false,
      ).detect();
      expect(
        stack == DisplayStack.flutterPi || stack == DisplayStack.unknown,
        isTrue,
      );
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
