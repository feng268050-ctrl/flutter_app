import 'dart:io';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/src/linux/board_helper.dart';
import 'package:cyber_hal/src/profile/board_bindings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kRestartFlutterSeatCommand points at restart-flutter-seat helper', () {
    expect(kRestartFlutterSeatCommand, <String>[kRestartFlutterSeatPath]);
    expect(kRestartFlutterSeatPath, contains('restart-flutter-seat'));
  });

  test('BoardBindings display factories default to seat restart', () {
    final json = File('boards/portable-smoke.json').readAsStringSync();
    final profile = BoardProfile.fromJsonString(json);
    final b = BoardBindings(profile);
    expect(b.wallpaper().restartCommand, kRestartFlutterSeatCommand);
    expect(b.orientation().restartCommand, kRestartFlutterSeatCommand);
  });
}
