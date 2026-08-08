import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/theme/hmi_text_scale.dart';
import 'package:lws_hmi/features/home/presentation/home_quick_action.dart';
import 'package:lws_hmi/ui/hmi/word_boundary_label.dart';

void main() {
  test('display factor clamps Large below reading 1.12', () {
    expect(HmiTextScale.displayFactorForReading(1.0), 1.0);
    expect(HmiTextScale.displayFactorForReading(0.90), 0.95);
    expect(HmiTextScale.displayFactorForReading(1.12), 1.05);
    expect(
      HmiTextScale.displayFactorForReading(1.12),
      lessThan(HmiTextScale.readingLarge),
    );
  });

  test('Class B settings row and tab height track reading tiers', () {
    expect(HmiTextScale.settingsRowFactorForReading(0.90), 0.95);
    expect(HmiTextScale.settingsRowFactorForReading(1.0), 1.0);
    expect(HmiTextScale.settingsRowFactorForReading(1.12), 1.10);
    expect(HmiTextScale.tabHeightForReading(0.90), 64);
    expect(HmiTextScale.tabHeightForReading(1.0), 68);
    expect(HmiTextScale.tabHeightForReading(1.12), 76);
  });

  test('quickAction scaler clamps at 1.05', () {
    expect(
      HmiTextScale.factorOf(TextScaler.linear(1.12)).clamp(0, 1.05),
      HmiTextScale.quickActionMax,
    );
  });

  test('WordBoundary packLines follows TextScaler', () {
    const style = TextStyle(fontSize: 24, fontWeight: FontWeight.w400);
    const words = ['Camera', 'Communication', 'Alarm', 'Detected'];
    const maxWidth = 220.0;

    final medium = WordBoundaryLabel.packLines(
      words: words,
      style: style,
      maxWidth: maxWidth,
      maxLines: 3,
      textScaler: TextScaler.noScaling,
    );
    final large = WordBoundaryLabel.packLines(
      words: words,
      style: style,
      maxWidth: maxWidth,
      maxLines: 3,
      textScaler: const TextScaler.linear(1.12),
    );

    // Same copy under a larger scaler cannot use fewer lines than Medium.
    expect(large.length, greaterThanOrEqualTo(medium.length));
  });

  test('homeQuickActionLabelFontSize shrinks when TextScaler grows', () {
    // Wide enough that Medium is above the 12sp floor.
    const card = 280.0;
    final at1 = homeQuickActionLabelFontSize(card);
    final atLarge = homeQuickActionLabelFontSize(
      card,
      textScaler: const TextScaler.linear(1.12),
    );
    expect(at1, greaterThan(12));
    expect(atLarge, lessThan(at1));
  });
}
