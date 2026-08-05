import 'package:cyber_ota/cyber_ota.dart';
import 'package:test/test.dart';

void main() {
  group('compareVersion', () {
    test('orders dotted numeric segments', () {
      expect(compareVersion('1.0.0', '1.0.1'), lessThan(0));
      expect(compareVersion('2.0.0', '1.9.9'), greaterThan(0));
      expect(compareVersion('1.2.3', '1.2.3'), 0);
    });

    test('handles v prefix and missing patch', () {
      expect(compareVersion('v1.2', '1.2.0'), 0);
      expect(compareVersion('1.10.0', '1.9.0'), greaterThan(0));
    });

    test('pre-release is older than release at same numeric level', () {
      expect(compareVersion('1.0.0', '1.0.0-beta'), greaterThan(0));
      expect(compareVersion('1.0.0-rc1', '1.0.0'), lessThan(0));
    });
  });

  group('isNewer', () {
    test('returns true only for strictly newer remote', () {
      expect(isNewer('1.1.0', '1.0.0'), isTrue);
      expect(isNewer('1.0.0', '1.0.0'), isFalse);
      expect(isNewer('0.9.0', '1.0.0'), isFalse);
    });
  });
}
