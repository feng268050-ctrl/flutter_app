import 'package:cyber_hal/src/sys_info/storage_info.dart';
import 'package:flutter/material.dart';

/// One colored segment of an appliance storage capacity bar.
final class StorageBarSegment {
  const StorageBarSegment({
    required this.mountPoint,
    required this.usedBytes,
    required this.color,
  });

  final String mountPoint;

  /// Bytes represented by this colored segment (not always df "Used").
  final int usedBytes;
  final Color color;
}

/// Aggregated storage view for Settings / OS Settings capacity UI.
final class StorageCapacitySummary {
  const StorageCapacitySummary({
    required this.segments,
    required this.usedBytes,
    required this.availableBytes,
    required this.totalBytes,
  });

  final List<StorageBarSegment> segments;
  final int usedBytes;
  final int availableBytes;
  final int totalBytes;

  bool get hasData => totalBytes > 0;
}

/// Segment colors (System / User data / fallback). Available is separate.
abstract final class StorageBarColors {
  static const system = Color(0xFF5AC8FA);
  static const userData = Color(0xFFFF9F0A);
  static const other = Color(0xFF64D2FF);

  /// iOS Settings track gray (readable on dark CyberUI fill).
  static const available = Color(0xFF636366);
}

/// Maps a mount point to a [StorageBarColors] token.
Color storageMountColor(String mountPoint) {
  switch (mountPoint) {
    case '/':
      return StorageBarColors.system;
    case '/userdata':
      return StorageBarColors.userData;
    default:
      return StorageBarColors.other;
  }
}

bool _isSystemMount(String mountPoint) => mountPoint == '/';

/// Builds bar segments from HAL [StorageInfo] mounts.
///
/// Appliance accounting (not raw df Used):
/// - **System (`/`)**: HAL synthetic entry = sum of GPT system partitions
///   (rootfs A/B, oem, boot, …). Entire total counts as System.
/// - **Other mounts** (typically `/userdata`): file used = total − available.
/// - **Available** (gray): free space on non-system mounts only.
StorageCapacitySummary summarizeStorage(List<StorageInfo> storage) {
  final segments = <StorageBarSegment>[];
  var occupied = 0;
  var available = 0;
  var total = 0;
  for (final info in storage) {
    final t = info.totalBytes;
    final free = info.freeBytes;
    if (t == null || free == null || t <= 0) {
      continue;
    }
    final clampedFree = free.clamp(0, t);
    total += t;

    if (_isSystemMount(info.mountPoint)) {
      // Whole system footprint is OS-owned (used + free + reserved).
      segments.add(
        StorageBarSegment(
          mountPoint: info.mountPoint,
          usedBytes: t,
          color: storageMountColor(info.mountPoint),
        ),
      );
      occupied += t;
      continue;
    }

    final usedHere = t - clampedFree;
    if (usedHere > 0) {
      segments.add(
        StorageBarSegment(
          mountPoint: info.mountPoint,
          usedBytes: usedHere,
          color: storageMountColor(info.mountPoint),
        ),
      );
      occupied += usedHere;
    }
    available += clampedFree;
  }
  return StorageCapacitySummary(
    segments: segments,
    usedBytes: occupied,
    availableBytes: available,
    totalBytes: total,
  );
}

/// Human-readable capacity (decimal units, iOS-like).
String formatStorageBytes(int bytes) {
  if (bytes < 0) {
    bytes = 0;
  }
  const kb = 1000;
  const mb = 1000 * kb;
  const gb = 1000 * mb;
  if (bytes >= gb) {
    final v = bytes / gb;
    final text = v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return '$text GB';
  }
  if (bytes >= mb) {
    return '${(bytes / mb).round()} MB';
  }
  if (bytes >= kb) {
    return '${(bytes / kb).round()} KB';
  }
  return '$bytes B';
}

/// English nav/summary line (`{used} of {total} used`). Prefer App l10n in UI.
String storageSummaryLine(StorageCapacitySummary summary) {
  if (!summary.hasData) {
    return kStorageUnavailableDash;
  }
  return '${formatStorageBytes(summary.usedBytes)} of '
      '${formatStorageBytes(summary.totalBytes)} used';
}

const kStorageUnavailableDash = '—';
