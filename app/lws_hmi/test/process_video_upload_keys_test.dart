import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_video/application/process_video_upload_gating.dart';
import 'package:lws_hmi/features/process_video/application/process_video_upload_r2_keys.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';

void main() {
  group('ProcessVideoUploadR2Keys', () {
    test('videoObjectKey shape', () {
      expect(
        ProcessVideoUploadR2Keys.videoObjectKey(
          sn: ' SN1 ',
          yyyyMmDd: '2026-07-31',
          videoId: ' abc ',
          extLowerNoDot: 'jpg',
        ),
        'uploads/devices/SN1/videos/2026-07-31/abc.jpg',
      );
      expect(
        ProcessVideoUploadR2Keys.videoObjectKey(
          sn: 'SN1',
          yyyyMmDd: '2026-07-31',
          videoId: 'abc',
          extLowerNoDot: '.mp4',
        ),
        'uploads/devices/SN1/videos/2026-07-31/abc.mp4',
      );
    });

    test('yyyyMmDdFromCreateTimeMs uses local calendar day', () {
      final ms = DateTime(2026, 7, 31, 15, 30).millisecondsSinceEpoch;
      expect(
        ProcessVideoUploadR2Keys.yyyyMmDdFromCreateTimeMs(ms),
        '2026-07-31',
      );
    });

    test('extFromPath and joinPublicBaseUrl', () {
      expect(ProcessVideoUploadR2Keys.extFromPath('/a/b.MP4'), 'mp4');
      expect(ProcessVideoUploadR2Keys.extFromPath('/a/b'), 'mp4');
      expect(
        ProcessVideoUploadR2Keys.joinPublicBaseUrl(
          'https://cdn.example/',
          '/uploads/x.jpg',
        ),
        'https://cdn.example/uploads/x.jpg',
      );
      expect(
        ProcessVideoUploadR2Keys.joinPublicBaseUrl(null, 'k'),
        '',
      );
    });
  });

  group('ProcessVideoUploadGating', () {
    test('disabled when already uploaded', () {
      expect(
        ProcessVideoUploadGating.canStartUpload(
          uploadStatus: ProcessVideoUploadStatus.videoUploaded,
          isUploadingThisRow: false,
        ),
        isFalse,
      );
    });

    test('disabled while in flight', () {
      expect(
        ProcessVideoUploadGating.canStartUpload(
          uploadStatus: ProcessVideoUploadStatus.coverUploaded,
          isUploadingThisRow: true,
        ),
        isFalse,
      );
    });

    test('enabled for status 0/1/2 when idle', () {
      for (final status in [
        ProcessVideoUploadStatus.notInitiated,
        ProcessVideoUploadStatus.coverUploaded,
        ProcessVideoUploadStatus.videoUploading,
      ]) {
        expect(
          ProcessVideoUploadGating.canStartUpload(
            uploadStatus: status,
            isUploadingThisRow: false,
          ),
          isTrue,
        );
      }
    });
  });
}
