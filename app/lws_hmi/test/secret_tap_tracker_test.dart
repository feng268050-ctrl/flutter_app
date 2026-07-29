import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/cloud/secret_tap_tracker.dart';

void main() {
  group('SecretTapTracker', () {
    test('fires after required taps within window', () {
      final t = SecretTapTracker(
        requiredTaps: 5,
        tapWindow: const Duration(seconds: 5),
      );
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      expect(t.registerTap(t0), isFalse);
      expect(t.registerTap(t0.add(const Duration(milliseconds: 100))), isFalse);
      expect(t.registerTap(t0.add(const Duration(milliseconds: 200))), isFalse);
      expect(t.registerTap(t0.add(const Duration(milliseconds: 300))), isFalse);
      expect(t.registerTap(t0.add(const Duration(milliseconds: 400))), isTrue);
    });

    test('resets when window expires', () {
      final t = SecretTapTracker(
        requiredTaps: 5,
        tapWindow: const Duration(seconds: 5),
      );
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      expect(t.registerTap(t0), isFalse);
      expect(t.registerTap(t0.add(const Duration(seconds: 1))), isFalse);
      expect(t.registerTap(t0.add(const Duration(seconds: 7))), isFalse);
      expect(t.registerTap(t0.add(const Duration(seconds: 7, milliseconds: 100))),
          isFalse);
      expect(t.registerTap(t0.add(const Duration(seconds: 7, milliseconds: 200))),
          isFalse);
      expect(t.registerTap(t0.add(const Duration(seconds: 7, milliseconds: 300))),
          isFalse);
      expect(t.registerTap(t0.add(const Duration(seconds: 7, milliseconds: 400))),
          isTrue);
    });
  });
}
