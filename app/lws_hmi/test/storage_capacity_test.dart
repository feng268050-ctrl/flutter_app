import 'package:cyber_hal/sys_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/settings/application/storage_capacity.dart';

void main() {
  group('formatStorageBytes', () {
    test('formats decimal units', () {
      expect(formatStorageBytes(500), '500 B');
      expect(formatStorageBytes(1500), '2 KB');
      expect(formatStorageBytes(15 * 1000 * 1000), '15 MB');
      expect(formatStorageBytes(2500 * 1000 * 1000), '2.5 GB');
      expect(formatStorageBytes(12 * 1000 * 1000 * 1000), '12 GB');
    });
  });

  group('summarizeStorage', () {
    test('System uses full root size; Available is userdata free only', () {
      final summary = summarizeStorage(const [
        StorageInfo(mountPoint: '/', totalBytes: 1000, freeBytes: 400),
        StorageInfo(
          mountPoint: '/userdata',
          totalBytes: 2000,
          freeBytes: 500,
        ),
      ]);
      expect(summary.hasData, isTrue);
      expect(summary.totalBytes, 3000);
      // System 1000 + userdata used 1500.
      expect(summary.usedBytes, 2500);
      // Root free is not operator-available.
      expect(summary.availableBytes, 500);
      expect(summary.segments, hasLength(2));
      expect(summary.segments[0].mountPoint, '/');
      expect(summary.segments[0].usedBytes, 1000);
      expect(summary.segments[0].color, StorageBarColors.system);
      expect(summary.segments[1].mountPoint, '/userdata');
      expect(summary.segments[1].usedBytes, 1500);
      expect(summary.segments[1].color, StorageBarColors.userData);
    });

    test('skips mounts without totals and soft-fails empty', () {
      final empty = summarizeStorage(const [
        StorageInfo(mountPoint: '/'),
        StorageInfo(mountPoint: '/userdata', totalBytes: 0, freeBytes: 0),
      ]);
      expect(empty.hasData, isFalse);
      expect(empty.segments, isEmpty);
    });
  });
}
