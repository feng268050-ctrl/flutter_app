/// R2 object keys and public URL join (lws-ui `ProcessVideoUploadR2Keys` / `ObjectStorageUrls`).
abstract final class ProcessVideoUploadR2Keys {
  static String videoObjectKey({
    required String sn,
    required String yyyyMmDd,
    required String videoId,
    required String extLowerNoDot,
  }) {
    final ext = extLowerNoDot.startsWith('.')
        ? extLowerNoDot.substring(1)
        : extLowerNoDot;
    return 'uploads/devices/${sn.trim()}/videos/$yyyyMmDd/'
        '${videoId.trim()}.$ext';
  }

  static String yyyyMmDdFromCreateTimeMs(int? createTimeMs) {
    final ms = (createTimeMs != null && createTimeMs > 0)
        ? createTimeMs
        : DateTime.now().millisecondsSinceEpoch;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  static String extFromPath(String localPath) {
    final i = localPath.lastIndexOf('.');
    if (i < 0 || i >= localPath.length - 1) {
      return 'mp4';
    }
    final ext = localPath.substring(i + 1).trim().toLowerCase();
    if (ext.isEmpty || ext.length > 8) {
      return 'mp4';
    }
    return ext;
  }

  static String joinPublicBaseUrl(String? publicBaseUrl, String objectKey) {
    if (publicBaseUrl == null || publicBaseUrl.trim().isEmpty) {
      return '';
    }
    final base = publicBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final key = objectKey.replaceFirst(RegExp(r'^/+'), '');
    return '$base/$key';
  }
}
