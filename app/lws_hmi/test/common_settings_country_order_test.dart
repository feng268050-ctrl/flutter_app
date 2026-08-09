import 'package:cyber_hal/locale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default region is US and catalog is full ISO', () {
    expect(RegionCatalog.defaultRegion, 'US');
    expect(RegionCatalog.supportedCodes.length, greaterThanOrEqualTo(240));
    expect(RegionCatalog.isSupported('CN'), isTrue);
    expect(RegionCatalog.isSupported('TW'), isTrue);
    expect(RegionCatalog.isSupported('HK'), isTrue);
    expect(RegionCatalog.isSupported('DE'), isTrue);
    expect(RegionCatalog.isSupported('BR'), isTrue);
    expect(RegionCatalog.normalize('xx'), 'US');
    for (final e in RegionCatalog.entries) {
      expect(e.preferredNtp, isNot(RegionCatalog.legacyChinaNtp));
    }
  });

  test('filter finds Germany by code and Chinese name', () {
    final byCode = RegionCatalog.filter(
      RegionCatalog.entries,
      'DE',
    );
    expect(byCode.any((e) => e.code == 'DE'), isTrue);
    final byZh = RegionCatalog.filter(
      RegionCatalog.entries,
      '德国',
    );
    expect(byZh.any((e) => e.code == 'DE'), isTrue);
  });

  test('sorted for display is A–Z by English name', () {
    final sorted = RegionCatalog.sortedForDisplay();
    expect(sorted.length, RegionCatalog.entries.length);
    for (var i = 1; i < sorted.length; i++) {
      expect(
        sorted[i - 1].nameEn.toLowerCase().compareTo(
              sorted[i].nameEn.toLowerCase(),
            ),
        lessThanOrEqualTo(0),
      );
    }
  });
}
