import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/input/linux_mouse_settings.dart';
import 'package:lws_hmi/platform/input/mouse_settings.dart';

void main() {
  test('parseMouseConf defaults on empty', () {
    final s = parseMouseConf('');
    expect(s.naturalScroll, isFalse);
    expect(s.scrollSpeedPercent, 50);
    expect(s.pointerSpeedPercent, 50);
    expect(s.pointerSizePercent, 20);
    expect(s.primaryButton, MousePrimaryButton.left);
  });

  test('parseMouseConf reads keys', () {
    final s = parseMouseConf('''
# comment
natural_scroll=1
scroll_speed=80
pointer_speed=10
pointer_size=90
primary_button=right
''');
    expect(s.naturalScroll, isTrue);
    expect(s.scrollSpeedPercent, 80);
    expect(s.pointerSpeedPercent, 10);
    expect(s.pointerSizePercent, 90);
    expect(s.primaryButton, MousePrimaryButton.right);
  });

  test('encodeMouseConf round-trip', () {
    const original = MouseSettings(
      naturalScroll: true,
      scrollSpeedPercent: 25,
      pointerSpeedPercent: 75,
      pointerSizePercent: 90,
      primaryButton: MousePrimaryButton.right,
    );
    final again = parseMouseConf(encodeMouseConf(original));
    expect(again.naturalScroll, original.naturalScroll);
    expect(again.scrollSpeedPercent, original.scrollSpeedPercent);
    expect(again.pointerSpeedPercent, original.pointerSpeedPercent);
    expect(again.pointerSizePercent, original.pointerSizePercent);
    expect(again.primaryButton, original.primaryButton);
  });

  test('pointerPercentToAccel maps mid to ~0', () {
    expect(pointerPercentToAccel(50), closeTo(0.0, 1e-9));
    expect(pointerPercentToAccel(0), closeTo(-1.0, 1e-9));
    expect(pointerPercentToAccel(100), closeTo(1.0, 1e-9));
    expect(pointerAccelToPercent(0.0), 50);
  });
}
