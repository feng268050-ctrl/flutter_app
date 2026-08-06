import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 8, 5);

  test('EN product date weekday', () {
    expect(formatProductDateWeekday(day, const Locale('en')), 'Wed Aug 5');
    expect(formatProductDateWeekday(day, const Locale('en', 'US')), 'Wed Aug 5');
  });

  test('ZH CN product date weekday has space', () {
    expect(
      formatProductDateWeekday(day, const Locale('zh', 'CN')),
      '8月5日 周三',
    );
  });

  test('ZH TW product date weekday uses 週', () {
    expect(
      formatProductDateWeekday(day, const Locale('zh', 'TW')),
      '8月5日 週三',
    );
  });
}
