import 'package:cyber_hal/locale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PreferredLanguage', () {
    test('parse BCP-47 and legacy', () {
      expect(PreferredLanguage.parse('zh-CN'), PreferredLanguage.zhCn);
      expect(PreferredLanguage.parse('ZH'), PreferredLanguage.zhCn);
      expect(PreferredLanguage.parse('zh-TW'), PreferredLanguage.zhTw);
      expect(PreferredLanguage.parse('EN'), PreferredLanguage.enUs);
      expect(PreferredLanguage.parse('nope'), PreferredLanguage.enUs);
    });

    test('wire round-trip', () {
      for (final lang in PreferredLanguage.supported) {
        expect(PreferredLanguage.parse(lang.wire), lang);
      }
    });
  });

  group('UnitSystem', () {
    test('parse', () {
      expect(UnitSystem.parse('Imperial'), UnitSystem.imperial);
      expect(UnitSystem.parse('Metric'), UnitSystem.metric);
      expect(UnitSystem.parse('x'), UnitSystem.metric);
    });
  });

  group('RegionCatalog', () {
    test('normalize unknown to US', () {
      expect(RegionCatalog.normalize(null), 'US');
      expect(RegionCatalog.normalize('xx'), 'US');
      expect(RegionCatalog.normalize('de'), 'DE');
    });

    test('filter finds Germany', () {
      final hits = RegionCatalog.filter(RegionCatalog.entries, '德国');
      expect(hits.any((e) => e.code == 'DE'), isTrue);
      final byCode = RegionCatalog.filter(RegionCatalog.entries, 'DE');
      expect(byCode.any((e) => e.code == 'DE'), isTrue);
    });

    test('sorted display starts with A', () {
      final sorted = RegionCatalog.sortedForDisplay();
      expect(sorted.first.nameEn.toLowerCase().startsWith('a'), isTrue);
    });
  });
}
