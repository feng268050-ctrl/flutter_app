/*
 * extract-video-frame — local MP4 → single JPEG via rootfs GStreamer.
 *
 * Usage: extract-video-frame <input.mp4> <output.jpg> [start_ms]
 *
 * Pipeline (product tip, GStreamer 1.28.5 + rockchipmpp):
 *   filesrc ! decodebin ! videoconvert ! video/x-raw,format=NV12 !
 *   videorate drop-only=true ! video/x-raw,framerate=1/1000 !
 *   mppjpegenc rc-mode=fixqp q-factor=80 ! appsink
 *
 * Use fixqp — default CBR with bps=0 trips mpp_enc assert (alloc_bits) on RK3566
 * and can destabilize concurrent MPP users (e.g. video_player in the HMI process).
 *
 * start_ms omitted or 0: decode from file start (display-order first frame;
 *   no input-side keyframe-only seek).
 * start_ms > 0: FLUSH|ACCURATE seek after PAUSED (falls back to KEY_UNIT).
 *   Seek tolerance: nearest decodable frame, typically ≤ one GOP.
 *
 * Required elements (must stay in gst harden / export allowlist):
 *   filesrc, decodebin, videoconvert, videorate, mppjpegenc, appsink
 *   (mppjpegenc lives in libgstrockchipmpp.so — no software jpegenc).
 *
 * Exit: 0 on non-empty JPEG; non-zero on failure. Soft-fail is the caller's job.
 */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <gst/app/gstappsink.h>
#include <gst/gst.h>

static void die(const char *msg) {
  fprintf(stderr, "extract-video-frame: %s\n", msg);
  exit(1);
}

static int write_jpeg(GstBuffer *buf, const char *path) {
  GstMapInfo map;
  FILE *f;
  size_t n;

  if (!gst_buffer_map(buf, &map, GST_MAP_READ)) {
    return -1;
  }
  if (map.size < 4 || map.data[0] != 0xff || map.data[1] != 0xd8) {
    gst_buffer_unmap(buf, &map);
    fprintf(stderr, "extract-video-frame: appsink buffer is not JPEG\n");
    return -1;
  }
  f = fopen(path, "wb");
  if (!f) {
    fprintf(stderr, "extract-video-frame: open %s: %s\n", path, strerror(errno));
    gst_buffer_unmap(buf, &map);
    return -1;
  }
  n = fwrite(map.data, 1, map.size, f);
  if (fclose(f) != 0 || n != map.size) {
    gst_buffer_unmap(buf, &map);
    unlink(path);
    return -1;
  }
  gst_buffer_unmap(buf, &map);
  return 0;
}

static gboolean seek_to_ms(GstElement *pipeline, gint64 start_ms) {
  GstSeekFlags flags =
      (GstSeekFlags)(GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_ACCURATE);
  gint64 pos = start_ms * GST_MSECOND;

  if (gst_element_seek_simple(pipeline, GST_FORMAT_TIME, flags, pos)) {
    return TRUE;
  }
  flags = (GstSeekFlags)(GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_KEY_UNIT);
  if (gst_element_seek_simple(pipeline, GST_FORMAT_TIME, flags, pos)) {
    fprintf(stderr,
            "extract-video-frame: ACCURATE seek failed; used KEY_UNIT at %lld ms\n",
            (long long)start_ms);
    return TRUE;
  }
  return FALSE;
}

int main(int argc, char **argv) {
  const char *input;
  const char *output;
  gint64 start_ms = 0;
  GError *err = NULL;
  GstElement *pipeline = NULL;
  GstElement *src = NULL;
  GstElement *sink_el = NULL;
  GstAppSink *sink = NULL;
  GstSample *sample = NULL;
  GstBuffer *buf = NULL;
  GstStateChangeReturn ret;
  int rc = 1;

  if (argc < 3 || argc > 4) {
    fprintf(stderr,
            "Usage: %s <input.mp4> <output.jpg> [start_ms]\n",
            argv[0]);
    return 2;
  }
  input = argv[1];
  output = argv[2];
  if (argc == 4) {
    char *end = NULL;
    errno = 0;
    start_ms = strtoll(argv[3], &end, 10);
    if (errno != 0 || end == argv[3] || *end != '\0' || start_ms < 0) {
      die("invalid start_ms");
    }
  }

  if (access(input, R_OK) != 0) {
    fprintf(stderr, "extract-video-frame: cannot read %s: %s\n", input,
            strerror(errno));
    return 1;
  }

  gst_init(&argc, &argv);

  pipeline = gst_parse_launch(
      "filesrc name=src ! decodebin ! videoconvert ! "
      "video/x-raw,format=NV12 ! videorate drop-only=true ! "
      "video/x-raw,framerate=1/1000 ! "
      "mppjpegenc rc-mode=fixqp q-factor=80 ! "
      "appsink name=sink sync=false max-buffers=1 drop=true",
      &err);
  if (!pipeline) {
    fprintf(stderr, "extract-video-frame: parse failed: %s\n",
            err ? err->message : "unknown");
    g_clear_error(&err);
    return 1;
  }

  src = gst_bin_get_by_name(GST_BIN(pipeline), "src");
  sink_el = gst_bin_get_by_name(GST_BIN(pipeline), "sink");
  if (!src || !sink_el) {
    die("missing filesrc/appsink in pipeline");
  }
  g_object_set(src, "location", input, NULL);
  sink = GST_APP_SINK(sink_el);

  ret = gst_element_set_state(pipeline, GST_STATE_PAUSED);
  if (ret == GST_STATE_CHANGE_FAILURE) {
    fprintf(stderr, "extract-video-frame: PAUSED failed\n");
    goto out;
  }
  ret = gst_element_get_state(pipeline, NULL, NULL, 30 * GST_SECOND);
  if (ret == GST_STATE_CHANGE_FAILURE) {
    fprintf(stderr, "extract-video-frame: preroll failed\n");
    goto out;
  }

  if (start_ms > 0) {
    if (!seek_to_ms(pipeline, start_ms)) {
      fprintf(stderr, "extract-video-frame: seek to %lld ms failed\n",
              (long long)start_ms);
      goto out;
    }
    ret = gst_element_get_state(pipeline, NULL, NULL, 30 * GST_SECOND);
    if (ret == GST_STATE_CHANGE_FAILURE) {
      fprintf(stderr, "extract-video-frame: post-seek state failed\n");
      goto out;
    }
  }

  ret = gst_element_set_state(pipeline, GST_STATE_PLAYING);
  if (ret == GST_STATE_CHANGE_FAILURE) {
    fprintf(stderr, "extract-video-frame: PLAYING failed\n");
    goto out;
  }

  sample = gst_app_sink_try_pull_sample(sink, 45 * GST_SECOND);
  if (!sample) {
    fprintf(stderr, "extract-video-frame: timeout waiting for JPEG frame\n");
    goto out;
  }
  buf = gst_sample_get_buffer(sample);
  if (!buf || write_jpeg(buf, output) != 0) {
    fprintf(stderr, "extract-video-frame: write %s failed\n", output);
    goto out;
  }
  rc = 0;

out:
  if (sample) {
    gst_sample_unref(sample);
  }
  if (pipeline) {
    gst_element_set_state(pipeline, GST_STATE_NULL);
  }
  if (src) {
    gst_object_unref(src);
  }
  if (sink_el) {
    gst_object_unref(sink_el);
  }
  if (pipeline) {
    gst_object_unref(pipeline);
  }
  return rc;
}
