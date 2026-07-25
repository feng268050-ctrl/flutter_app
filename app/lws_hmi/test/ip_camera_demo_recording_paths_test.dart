import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_demo_recording_paths.dart';

void main() {
  test('demo path mirrors lws-ui movie/day/timestamp layout', () {
    final paths = const IpCameraDemoRecordingPaths();
    final when = DateTime(2026, 7, 21, 19, 5, 9);
    expect(
      paths.nextMp4Path(when),
      '/userdata/storage/Videos/movie/2026-07-21/26-07-21_19-05-09.mp4',
    );
  });

  test('custom root is honored', () {
    final paths = const IpCameraDemoRecordingPaths(root: '/tmp/videos');
    final when = DateTime(2026, 1, 2, 3, 4, 5);
    expect(
      paths.nextMp4Path(when),
      '/tmp/videos/movie/2026-01-02/26-01-02_03-04-05.mp4',
    );
  });
}
