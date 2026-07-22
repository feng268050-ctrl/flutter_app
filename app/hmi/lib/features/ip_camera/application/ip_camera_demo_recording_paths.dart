/// Demo recording paths for Settings → IP Camera (not Quick/Engineer business).
///
/// Mirrors lws-ui `VideoFileUtil.getMovieName(yyyy-MM-dd)` layout under a fixed
/// product root:
/// `/userdata/storage/Videos/movie/<yyyy-MM-dd>/<yy-MM-dd_HH-mm-ss>.mp4`
final class IpCameraDemoRecordingPaths {
  const IpCameraDemoRecordingPaths({
    this.root = '/userdata/storage/Videos',
  });

  final String root;

  /// Next demo MP4 path for [now] (does not create directories).
  String nextMp4Path([DateTime? now]) {
    final t = now ?? DateTime.now();
    final day =
        '${t.year.toString().padLeft(4, '0')}-${_two(t.month)}-${_two(t.day)}';
    final yy = (t.year % 100).toString().padLeft(2, '0');
    final name =
        '$yy-${_two(t.month)}-${_two(t.day)}_${_two(t.hour)}-${_two(t.minute)}-${_two(t.second)}';
    return '$root/movie/$day/$name.mp4';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
