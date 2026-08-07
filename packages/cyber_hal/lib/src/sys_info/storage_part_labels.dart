import 'dart:io';

/// GPT PARTNAMEs counted as System storage (full block size).
///
/// Matches ynh960-line layout in `board/parameter-buildroot-fit.txt` /
/// `docs/storage-layout.md` — everything except grow `userdata`.
const kDefaultSystemStoragePartLabels = <String>[
  'uboot',
  'misc',
  'boot',
  'boot_b',
  'recovery',
  'backup',
  'rootfs_a',
  'rootfs_b',
  'oem',
  'private',
  'private1',
  'vendor0',
  'vendor1',
  'vendor2',
  'vendor3',
];

/// Bytes for [partLabel] via `/dev/disk/by-partlabel/…` → sysfs `size`
/// (512-byte sectors). Returns null when the partition is missing.
Future<int?> readPartLabelSizeBytes(String partLabel) async {
  final label = partLabel.trim();
  if (label.isEmpty) {
    return null;
  }
  try {
    final link = Link('/dev/disk/by-partlabel/$label');
    if (!await link.exists()) {
      return null;
    }
    final target = await link.resolveSymbolicLinks();
    final name = target.split('/').where((s) => s.isNotEmpty).last;
    if (name.isEmpty) {
      return null;
    }
    final sizeFile = File('/sys/class/block/$name/size');
    if (!await sizeFile.exists()) {
      return null;
    }
    return sectorsFileToBytes(await sizeFile.readAsString());
  } catch (_) {
    return null;
  }
}

/// Parse sysfs `…/size` (512-byte sectors) to bytes.
int? sectorsFileToBytes(String contents) {
  final sectors = int.tryParse(contents.trim());
  if (sectors == null || sectors <= 0) {
    return null;
  }
  return sectors * 512;
}
