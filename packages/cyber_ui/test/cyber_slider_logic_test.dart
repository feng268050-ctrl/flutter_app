import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CyberSliderLogic', () {
    test('fractionFromDelta uses resting and activation offset', () {
      const resting = 0.5;
      const travel = 167.0;
      const activation = 100.0;
      expect(
        CyberSliderLogic.fractionFromDelta(
          restingFraction: resting,
          activationX: activation,
          currentX: activation,
          travelPx: travel,
        ),
        closeTo(0.5, 0.01),
      );
      expect(
        CyberSliderLogic.fractionFromDelta(
          restingFraction: resting,
          activationX: activation,
          currentX: activation + travel * 0.1,
          travelPx: travel,
        ),
        closeTo(0.6, 0.01),
      );
    });

    test('thumb hit rejects track far from thumb', () {
      final hit = CyberSliderLogic.thumbHitRect(
        thumbCenterX: 100,
        touchHeightPx: 49,
        thumbRadiusPx: 16.5,
      );
      expect(CyberSliderLogic.hitRectContains(100, 24.5, hit), isTrue);
      expect(CyberSliderLogic.hitRectContains(20, 24.5, hit), isFalse);
    });

    test('center snap only when range spans center', () {
      expect(
        CyberSliderLogic.centerSnapConfig(min: -30, max: 30)!.centerFraction,
        closeTo(0.5, 0.01),
      );
      expect(CyberSliderLogic.centerSnapConfig(min: 0, max: 100), isNull);
    });

    test('center snap enters within threshold', () {
      final config = CyberSliderLogic.centerSnapConfig(min: -30, max: 30)!;
      final session = CyberSliderCenterSnapSession()
        ..dragRestingFraction = 0.48;
      final result = cyberSliderResolveDragValue(
        snapConfig: config,
        snapSession: session,
        min: -30,
        max: 30,
        travelPx: 167,
        activationX: 100,
        currentX: 102,
      );
      expect(result.isCenterSnapped, isTrue);
      expect(result.value, 0);
      expect(result.fraction, closeTo(0.5, 0.01));
    });
  });
}
