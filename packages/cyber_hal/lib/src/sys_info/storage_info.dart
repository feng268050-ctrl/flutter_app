/// One mount / synthetic storage row from HAL probes.
final class StorageInfo {
  const StorageInfo({
    required this.mountPoint,
    this.totalBytes,
    this.freeBytes,
  });

  final String mountPoint;
  final int? totalBytes;
  final int? freeBytes;
}

/// Parse `df -P` / `df -Pk` / `df -B1` stdout for [mountPoint].
///
/// Uses the last data line (handles wrapped filesystem names). Columns:
/// `Filesystem blocks Used Available …`. Multiplies block counts by
/// [blockSizeBytes] (1 for GNU `-B1`, 1024 for BusyBox/POSIX `-k`/`-P`).
StorageInfo? parseDfStorageLine({
  required String stdout,
  required String mountPoint,
  int blockSizeBytes = 1024,
}) {
  final lines = stdout.trim().split('\n');
  if (lines.length < 2) {
    return null;
  }
  // Prefer a line that ends with the mount point; else last non-header line.
  String? dataLine;
  for (var i = lines.length - 1; i >= 1; i--) {
    final line = lines[i].trim();
    if (line.isEmpty) {
      continue;
    }
    if (line == mountPoint ||
        line.endsWith(' $mountPoint') ||
        line.endsWith('\t$mountPoint')) {
      dataLine = line;
      break;
    }
    dataLine ??= line;
  }
  if (dataLine == null) {
    return null;
  }
  final cols = dataLine.split(RegExp(r'\s+'));
  if (cols.length < 4) {
    return null;
  }
  final totalBlocks = int.tryParse(cols[1]);
  final freeBlocks = int.tryParse(cols[3]);
  if (totalBlocks == null || freeBlocks == null || totalBlocks <= 0) {
    return null;
  }
  final scale = blockSizeBytes <= 0 ? 1 : blockSizeBytes;
  return StorageInfo(
    mountPoint: mountPoint,
    totalBytes: totalBlocks * scale,
    freeBytes: freeBlocks * scale,
  );
}
