/*
 * libhmi_capture — present-hook RGBA readback + GStreamer MPP encode.
 *
 * Present path (GL thread): glReadPixels into a free ring slot (drop if busy).
 * Encode path (worker): appsrc → videoconvert → mppjpegenc|mpph264enc → file.
 */
#define _GNU_SOURCE
#include "hmi_capture.h"

#include <errno.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#include <gst/app/gstappsrc.h>
#include <gst/gst.h>

enum {
  kRingSlots = 3,
  kStatusMax = 512,
  kPathMax = 512,
};

typedef enum {
  kModeIdle = 0,
  kModeStillArmed,
  kModeRecording,
  kModeStopping,
} Mode;

typedef struct {
  uint8_t *rgba;
  int width;
  int height;
  int stride;
  int64_t pts_ns;
  int ready; /* 1 = filled by present, waiting for encode */
} FrameSlot;

typedef struct {
  pthread_mutex_t mu;
  pthread_cond_t cv;
  pthread_t worker;
  int worker_started;
  int worker_stop;

  Mode mode;
  char out_dir[kPathMax];
  char status[kStatusMax];
  char last_error[kStatusMax];

  int fps;
  int scale_pct; /* 100 = full */
  int rotate_deg;
  int q_factor;
  int audio; /* request; may soft-fail */

  int pending_still; /* 1 = next ready ring slot is a still */
  int record_active;

  FrameSlot ring[kRingSlots];
  int drop_count;
  int frame_count;

  /* GL procs (resolved on first present while capturing) */
  void (*glReadPixels)(int, int, int, int, unsigned int, unsigned int, void *);
  void (*glPixelStorei)(unsigned int, int);
  int gl_ready;
} CaptureState;

static CaptureState g;

static int64_t mono_ns(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (int64_t)ts.tv_sec * 1000000000LL + (int64_t)ts.tv_nsec;
}

static void write_status_file_locked(void) {
  FILE *f = fopen("/var/lib/hmi/capture/status", "w");
  if (!f) {
    return;
  }
  fprintf(f, "%s\n", g.status);
  if (g.out_dir[0]) {
    fprintf(f, "out_dir=%s\n", g.out_dir);
  }
  if (g.last_error[0]) {
    fprintf(f, "error=%s\n", g.last_error);
  }
  fprintf(f, "frames=%d\n", g.frame_count);
  fprintf(f, "drops=%d\n", g.drop_count);
  fclose(f);
  if (g.out_dir[0]) {
    char path[kPathMax];
    snprintf(path, sizeof(path), "%s/.status", g.out_dir);
    f = fopen(path, "w");
    if (f) {
      fprintf(f, "%s\n", g.status);
      fclose(f);
    }
  }
}

static void set_status_locked(const char *s) {
  snprintf(g.status, sizeof(g.status), "%s", s ? s : "idle");
  write_status_file_locked();
}

static void set_error_locked(const char *s) {
  snprintf(g.last_error, sizeof(g.last_error), "%s", s ? s : "");
  if (g.last_error[0]) {
    snprintf(g.status, sizeof(g.status), "error:%s", g.last_error);
    write_status_file_locked();
  }
}

static int ensure_dir(const char *path) {
  char tmp[kPathMax];
  size_t len;
  char *p;

  if (!path || !path[0]) {
    return -1;
  }
  snprintf(tmp, sizeof(tmp), "%s", path);
  len = strlen(tmp);
  if (len == 0 || len >= sizeof(tmp)) {
    return -1;
  }
  if (tmp[len - 1] == '/') {
    tmp[len - 1] = '\0';
  }
  for (p = tmp + 1; *p; p++) {
    if (*p == '/') {
      *p = '\0';
      if (mkdir(tmp, 0755) != 0 && errno != EEXIST) {
        return -1;
      }
      *p = '/';
    }
  }
  if (mkdir(tmp, 0755) != 0 && errno != EEXIST) {
    return -1;
  }
  return 0;
}

static void free_ring_locked(void) {
  int i;
  for (i = 0; i < kRingSlots; i++) {
    free(g.ring[i].rgba);
    g.ring[i].rgba = NULL;
    g.ring[i].ready = 0;
    g.ring[i].width = 0;
    g.ring[i].height = 0;
  }
}

static int alloc_slot(FrameSlot *slot, int w, int h) {
  size_t need = (size_t)w * (size_t)h * 4u;
  if (slot->rgba && slot->width == w && slot->height == h) {
    return 0;
  }
  free(slot->rgba);
  slot->rgba = (uint8_t *)malloc(need);
  if (!slot->rgba) {
    slot->width = slot->height = 0;
    return -1;
  }
  slot->width = w;
  slot->height = h;
  slot->stride = w * 4;
  return 0;
}

/* GLES glReadPixels is bottom-up; flip to top-left origin for encoders. */
static void flip_vertical(uint8_t *rgba, int w, int h, int stride) {
  uint8_t *tmp;
  int y;
  size_t row = (size_t)stride;
  tmp = (uint8_t *)malloc(row);
  if (!tmp) {
    return;
  }
  for (y = 0; y < h / 2; y++) {
    uint8_t *a = rgba + (size_t)y * row;
    uint8_t *b = rgba + (size_t)(h - 1 - y) * row;
    memcpy(tmp, a, row);
    memcpy(a, b, row);
    memcpy(b, tmp, row);
  }
  free(tmp);
}

static void rotate_rgba_inplace(uint8_t **prgba,
                                int *pw,
                                int *ph,
                                int *pstride,
                                int rotate_deg) {
  int rot = ((rotate_deg % 360) + 360) % 360;
  int w = *pw;
  int h = *ph;
  int stride = *pstride;
  uint8_t *src = *prgba;
  uint8_t *dst;
  int x, y, nw, nh;

  if (rot == 0 || !src) {
    return;
  }
  if (rot == 180) {
    flip_vertical(src, w, h, stride);
    /* also mirror horizontally */
    for (y = 0; y < h; y++) {
      uint8_t *row = src + (size_t)y * (size_t)stride;
      for (x = 0; x < w / 2; x++) {
        uint8_t *a = row + x * 4;
        uint8_t *b = row + (w - 1 - x) * 4;
        uint8_t t[4];
        memcpy(t, a, 4);
        memcpy(a, b, 4);
        memcpy(b, t, 4);
      }
    }
    return;
  }
  if (rot != 90 && rot != 270) {
    return;
  }
  nw = h;
  nh = w;
  dst = (uint8_t *)malloc((size_t)nw * (size_t)nh * 4u);
  if (!dst) {
    return;
  }
  for (y = 0; y < h; y++) {
    for (x = 0; x < w; x++) {
      const uint8_t *s = src + (size_t)y * (size_t)stride + (size_t)x * 4u;
      int dx, dy;
      if (rot == 90) {
        dx = h - 1 - y;
        dy = x;
      } else {
        dx = y;
        dy = w - 1 - x;
      }
      memcpy(dst + ((size_t)dy * (size_t)nw + (size_t)dx) * 4u, s, 4);
    }
  }
  free(src);
  *prgba = dst;
  *pw = nw;
  *ph = nh;
  *pstride = nw * 4;
}

static int write_summary(const char *dir,
                         const char *kind,
                         int w,
                         int h,
                         int fps,
                         int frames,
                         int drops,
                         const char *extra) {
  char path[kPathMax];
  FILE *f;
  snprintf(path, sizeof(path), "%s/summary.txt", dir);
  f = fopen(path, "w");
  if (!f) {
    return -1;
  }
  fprintf(f, "kind=%s\n", kind);
  fprintf(f, "backend=hmi_capture_present_hook\n");
  fprintf(f, "encoder=%s\n", strcmp(kind, "still") == 0 ? "mppjpegenc" : "mpph264enc");
  fprintf(f, "width=%d\n", w);
  fprintf(f, "height=%d\n", h);
  fprintf(f, "fps=%d\n", fps);
  fprintf(f, "frames=%d\n", frames);
  fprintf(f, "drops=%d\n", drops);
  fprintf(f, "rotate=%d\n", g.rotate_deg);
  if (extra && extra[0]) {
    fprintf(f, "%s\n", extra);
  }
  fclose(f);
  return 0;
}

static int push_rgba_appsrc(GstElement *appsrc,
                            const uint8_t *rgba,
                            int w,
                            int h,
                            int64_t pts_ns,
                            int64_t dur_ns) {
  size_t nbytes = (size_t)w * (size_t)h * 4u;
  GstBuffer *buf;
  GstMapInfo map;
  GstFlowReturn ret;

  buf = gst_buffer_new_allocate(NULL, nbytes, NULL);
  if (!buf) {
    return -1;
  }
  if (!gst_buffer_map(buf, &map, GST_MAP_WRITE)) {
    gst_buffer_unref(buf);
    return -1;
  }
  memcpy(map.data, rgba, nbytes);
  gst_buffer_unmap(buf, &map);
  GST_BUFFER_PTS(buf) = (GstClockTime)pts_ns;
  GST_BUFFER_DTS(buf) = (GstClockTime)pts_ns;
  GST_BUFFER_DURATION(buf) = (GstClockTime)dur_ns;
  ret = gst_app_src_push_buffer(GST_APP_SRC(appsrc), buf);
  return ret == GST_FLOW_OK ? 0 : -1;
}

static int encode_still_file(const uint8_t *rgba,
                             int w,
                             int h,
                             const char *jpg_path,
                             int q_factor) {
  GstElement *pipeline = NULL;
  GstElement *appsrc = NULL;
  GError *err = NULL;
  char desc[1024];
  int rc = -1;
  GstStateChangeReturn state;

  snprintf(desc, sizeof(desc),
           "appsrc name=src is-live=true format=time do-timestamp=false ! "
           "video/x-raw,format=RGBA,width=%d,height=%d,framerate=1/1 ! "
           "videoconvert ! video/x-raw,format=NV12 ! "
           "mppjpegenc rc-mode=fixqp q-factor=%d ! "
           "filesink location=\"%s\" sync=false",
           w, h, q_factor > 0 ? q_factor : 80, jpg_path);

  pipeline = gst_parse_launch(desc, &err);
  if (!pipeline) {
    fprintf(stderr, "hmi_capture: still parse: %s\n",
            err ? err->message : "?");
    if (err) {
      g_error_free(err);
    }
    return -1;
  }
  appsrc = gst_bin_get_by_name(GST_BIN(pipeline), "src");
  if (!appsrc) {
    gst_object_unref(pipeline);
    return -1;
  }

  state = gst_element_set_state(pipeline, GST_STATE_PLAYING);
  if (state == GST_STATE_CHANGE_FAILURE) {
    gst_object_unref(appsrc);
    gst_object_unref(pipeline);
    return -1;
  }

  if (push_rgba_appsrc(appsrc, rgba, w, h, 0, GST_SECOND) != 0) {
    goto out;
  }
  gst_app_src_end_of_stream(GST_APP_SRC(appsrc));

  {
    GstBus *bus = gst_element_get_bus(pipeline);
    GstMessage *msg = gst_bus_timed_pop_filtered(
        bus, 15 * GST_SECOND,
        (GstMessageType)(GST_MESSAGE_ERROR | GST_MESSAGE_EOS));
    if (msg) {
      if (GST_MESSAGE_TYPE(msg) == GST_MESSAGE_EOS) {
        rc = 0;
      } else {
        GError *e = NULL;
        gchar *dbg = NULL;
        gst_message_parse_error(msg, &e, &dbg);
        fprintf(stderr, "hmi_capture: still error: %s\n",
                e ? e->message : "?");
        if (e) {
          g_error_free(e);
        }
        g_free(dbg);
      }
      gst_message_unref(msg);
    }
    gst_object_unref(bus);
  }

out:
  gst_element_set_state(pipeline, GST_STATE_NULL);
  gst_object_unref(appsrc);
  gst_object_unref(pipeline);
  return rc;
}

typedef struct {
  GstElement *pipeline;
  GstElement *appsrc;
  int width;
  int height;
  int fps;
  int64_t base_pts_ns; /* first frame monotonic pts; -1 = unset */
  int64_t last_pts_ns;
  char audio_note[128];
} RecordPipe;

static void record_pipe_close(RecordPipe *rp) {
  if (!rp) {
    return;
  }
  if (rp->pipeline) {
    if (rp->appsrc) {
      gst_app_src_end_of_stream(GST_APP_SRC(rp->appsrc));
    }
    {
      GstBus *bus = gst_element_get_bus(rp->pipeline);
      GstMessage *msg = gst_bus_timed_pop_filtered(
          bus, 8 * GST_SECOND,
          (GstMessageType)(GST_MESSAGE_ERROR | GST_MESSAGE_EOS));
      if (msg) {
        gst_message_unref(msg);
      }
      gst_object_unref(bus);
    }
    gst_element_set_state(rp->pipeline, GST_STATE_NULL);
    if (rp->appsrc) {
      gst_object_unref(rp->appsrc);
      rp->appsrc = NULL;
    }
    gst_object_unref(rp->pipeline);
    rp->pipeline = NULL;
  }
}

static int record_pipe_open(RecordPipe *rp,
                            const char *mp4_path,
                            int w,
                            int h,
                            int fps,
                            int want_audio) {
  GError *err = NULL;
  char desc[1536];
  GstStateChangeReturn state;

  memset(rp, 0, sizeof(*rp));
  rp->width = w;
  rp->height = h;
  rp->fps = fps > 0 ? fps : 30;
  rp->base_pts_ns = -1;
  rp->last_pts_ns = 0;
  snprintf(rp->audio_note, sizeof(rp->audio_note), "audio=off");

  /* Video-only first; ALSA soft-fallback keeps the same mux path. */
  (void)want_audio;
  /* framerate caps are a hint; PTS come from monotonic submit time. */
  snprintf(desc, sizeof(desc),
           "appsrc name=src is-live=true format=time do-timestamp=false "
           "block=false max-bytes=0 ! "
           "video/x-raw,format=RGBA,width=%d,height=%d,framerate=%d/1 ! "
           "videoconvert ! video/x-raw,format=NV12 ! "
           "mpph264enc rc-mode=fixqp ! h264parse ! "
           "mp4mux name=mux ! filesink location=\"%s\" sync=false",
           w, h, rp->fps, mp4_path);

  rp->pipeline = gst_parse_launch(desc, &err);
  if (!rp->pipeline) {
    fprintf(stderr, "hmi_capture: record parse: %s\n",
            err ? err->message : "?");
    if (err) {
      g_error_free(err);
    }
    return -1;
  }
  rp->appsrc = gst_bin_get_by_name(GST_BIN(rp->pipeline), "src");
  if (!rp->appsrc) {
    gst_object_unref(rp->pipeline);
    rp->pipeline = NULL;
    return -1;
  }
  g_object_set(rp->appsrc, "format", GST_FORMAT_TIME, "is-live", TRUE, NULL);

  state = gst_element_set_state(rp->pipeline, GST_STATE_PLAYING);
  if (state == GST_STATE_CHANGE_FAILURE) {
    record_pipe_close(rp);
    return -1;
  }
  if (want_audio) {
    snprintf(rp->audio_note, sizeof(rp->audio_note),
             "audio=skipped_no_aac_soft_fallback");
  }
  return 0;
}

static void scale_rgba_box(const uint8_t *src,
                           int sw,
                           int sh,
                           uint8_t *dst,
                           int dw,
                           int dh) {
  int y, x;
  for (y = 0; y < dh; y++) {
    int sy = y * sh / dh;
    for (x = 0; x < dw; x++) {
      int sx = x * sw / dw;
      const uint8_t *s =
          src + ((size_t)sy * (size_t)sw + (size_t)sx) * 4u;
      uint8_t *d = dst + ((size_t)y * (size_t)dw + (size_t)x) * 4u;
      memcpy(d, s, 4);
    }
  }
}

static void *worker_main(void *arg) {
  RecordPipe rp;
  char jpg_path[kPathMax];
  char mp4_path[kPathMax];
  int last_w = 0, last_h = 0;
  (void)arg;
  memset(&rp, 0, sizeof(rp));

  gst_init(NULL, NULL);

  for (;;) {
    FrameSlot local;
    Mode mode;
    char out_dir[kPathMax];
    int fps, scale_pct, rotate_deg, q_factor, audio;
    int stop;
    int is_still = 0;

    memset(&local, 0, sizeof(local));

    pthread_mutex_lock(&g.mu);
    while (!g.worker_stop) {
      int i;
      int got = 0;
      for (i = 0; i < kRingSlots; i++) {
        if (g.ring[i].ready) {
          local = g.ring[i];
          g.ring[i].rgba = NULL; /* take ownership */
          g.ring[i].ready = 0;
          g.ring[i].width = g.ring[i].height = 0;
          got = 1;
          break;
        }
      }
      if (got) {
        is_still = g.pending_still;
        if (is_still) {
          g.pending_still = 0;
        }
        break;
      }
      if (g.mode == kModeStopping && g.record_active) {
        break;
      }
      pthread_cond_wait(&g.cv, &g.mu);
    }
    stop = g.worker_stop;
    mode = g.mode;
    snprintf(out_dir, sizeof(out_dir), "%s", g.out_dir);
    fps = g.fps;
    scale_pct = g.scale_pct;
    rotate_deg = g.rotate_deg;
    q_factor = g.q_factor;
    audio = g.audio;
    pthread_mutex_unlock(&g.mu);

    if (stop) {
      free(local.rgba);
      break;
    }

    if (local.rgba) {
      int w = local.width;
      int h = local.height;
      int stride = local.stride;
      uint8_t *rgba = local.rgba;
      int dw, dh;
      uint8_t *scaled = NULL;

      flip_vertical(rgba, w, h, stride);
      rotate_rgba_inplace(&rgba, &w, &h, &stride, rotate_deg);

      dw = w;
      dh = h;
      if (!is_still && scale_pct > 0 && scale_pct < 100) {
        dw = (w * scale_pct / 100) & ~1;
        dh = (h * scale_pct / 100) & ~1;
        if (dw < 96) {
          dw = 96;
        }
        if (dh < 64) {
          dh = 64;
        }
        scaled = (uint8_t *)malloc((size_t)dw * (size_t)dh * 4u);
        if (scaled) {
          scale_rgba_box(rgba, w, h, scaled, dw, dh);
          free(rgba);
          rgba = scaled;
          w = dw;
          h = dh;
          stride = w * 4;
        }
      }

      if (is_still) {
        snprintf(jpg_path, sizeof(jpg_path), "%s/screen.jpg", out_dir);
        if (encode_still_file(rgba, w, h, jpg_path, q_factor) == 0) {
          write_summary(out_dir, "still", w, h, 0, 1, g.drop_count, NULL);
          pthread_mutex_lock(&g.mu);
          g.mode = kModeIdle;
          set_status_locked("done");
          pthread_mutex_unlock(&g.mu);
        } else {
          pthread_mutex_lock(&g.mu);
          g.mode = kModeIdle;
          set_error_locked("still_encode_failed");
          pthread_mutex_unlock(&g.mu);
        }
        free(rgba);
        continue;
      }

      if (mode == kModeRecording || mode == kModeStopping || rp.pipeline) {
        if (!rp.pipeline || rp.width != w || rp.height != h) {
          record_pipe_close(&rp);
          snprintf(mp4_path, sizeof(mp4_path), "%s/screen.mp4", out_dir);
          if (record_pipe_open(&rp, mp4_path, w, h, fps, audio) != 0) {
            pthread_mutex_lock(&g.mu);
            g.mode = kModeIdle;
            g.record_active = 0;
            set_error_locked("record_pipeline_failed");
            pthread_mutex_unlock(&g.mu);
            free(rgba);
            continue;
          }
          last_w = w;
          last_h = h;
          pthread_mutex_lock(&g.mu);
          g.record_active = 1;
          set_status_locked("recording");
          pthread_mutex_unlock(&g.mu);
        }
        {
          int64_t pts;
          int64_t dur;
          if (rp.base_pts_ns < 0) {
            rp.base_pts_ns = local.pts_ns;
            rp.last_pts_ns = local.pts_ns;
          }
          pts = local.pts_ns - rp.base_pts_ns;
          if (pts < 0) {
            pts = 0;
          }
          dur = local.pts_ns - rp.last_pts_ns;
          if (dur <= 0) {
            dur = GST_SECOND / (rp.fps > 0 ? rp.fps : 30);
          }
          rp.last_pts_ns = local.pts_ns;
          if (push_rgba_appsrc(rp.appsrc, rgba, w, h, pts, dur) == 0) {
            pthread_mutex_lock(&g.mu);
            g.frame_count++;
            pthread_mutex_unlock(&g.mu);
          }
        }
        free(rgba);
      } else {
        free(rgba);
      }
    }

    /* Finalize record on stop with empty queue. */
    pthread_mutex_lock(&g.mu);
    if (g.mode == kModeStopping && g.record_active) {
      int busy = 0;
      int i;
      for (i = 0; i < kRingSlots; i++) {
        if (g.ring[i].ready) {
          busy = 1;
          break;
        }
      }
      if (!busy) {
        char extra[160];
        char audio_note[128];
        snprintf(audio_note, sizeof(audio_note), "%s", rp.audio_note);
        pthread_mutex_unlock(&g.mu);
        record_pipe_close(&rp);
        snprintf(extra, sizeof(extra), "%s", audio_note);
        write_summary(out_dir, "record", last_w, last_h, fps, g.frame_count,
                      g.drop_count, extra);
        pthread_mutex_lock(&g.mu);
        g.record_active = 0;
        g.mode = kModeIdle;
        set_status_locked("done");
      }
    }
    pthread_mutex_unlock(&g.mu);
  }

  record_pipe_close(&rp);
  return NULL;
}

static int ensure_worker(void) {
  if (g.worker_started) {
    return 0;
  }
  if (pthread_create(&g.worker, NULL, worker_main, NULL) != 0) {
    return -1;
  }
  g.worker_started = 1;
  return 0;
}

static void capture_init_once(void) {
  static int inited = 0;
  if (inited) {
    return;
  }
  memset(&g, 0, sizeof(g));
  pthread_mutex_init(&g.mu, NULL);
  pthread_cond_init(&g.cv, NULL);
  set_status_locked("idle");
  g.fps = 30;
  g.scale_pct = 100;
  g.q_factor = 80;
  inited = 1;
}

int hmi_capture_screenshot(const char *out_dir, int rotate_deg, int q_factor) {
  capture_init_once();
  if (!out_dir || !out_dir[0]) {
    return -1;
  }
  if (ensure_dir(out_dir) != 0) {
    return -1;
  }
  if (ensure_worker() != 0) {
    return -1;
  }
  pthread_mutex_lock(&g.mu);
  if (g.mode != kModeIdle) {
    pthread_mutex_unlock(&g.mu);
    return -1;
  }
  snprintf(g.out_dir, sizeof(g.out_dir), "%s", out_dir);
  g.rotate_deg = rotate_deg;
  g.q_factor = q_factor > 0 ? q_factor : 80;
  g.pending_still = 0;
  g.drop_count = 0;
  g.frame_count = 0;
  g.mode = kModeStillArmed;
  set_status_locked("armed");
  set_error_locked("");
  pthread_cond_signal(&g.cv);
  pthread_mutex_unlock(&g.mu);
  return 0;
}

int hmi_capture_record_start(const char *out_dir,
                             int fps,
                             int scale_pct,
                             int rotate_deg,
                             int audio) {
  capture_init_once();
  if (!out_dir || !out_dir[0]) {
    return -1;
  }
  if (ensure_dir(out_dir) != 0) {
    return -1;
  }
  if (ensure_worker() != 0) {
    return -1;
  }
  pthread_mutex_lock(&g.mu);
  if (g.mode != kModeIdle) {
    pthread_mutex_unlock(&g.mu);
    return -1;
  }
  snprintf(g.out_dir, sizeof(g.out_dir), "%s", out_dir);
  g.fps = fps > 0 ? fps : 30;
  g.scale_pct = (scale_pct > 0 && scale_pct <= 100) ? scale_pct : 100;
  g.rotate_deg = rotate_deg;
  g.audio = audio ? 1 : 0;
  g.drop_count = 0;
  g.frame_count = 0;
  g.mode = kModeRecording;
  set_status_locked("recording");
  set_error_locked("");
  pthread_cond_signal(&g.cv);
  pthread_mutex_unlock(&g.mu);
  return 0;
}

int hmi_capture_record_stop(void) {
  capture_init_once();
  pthread_mutex_lock(&g.mu);
  if (g.mode == kModeRecording || g.record_active) {
    g.mode = kModeStopping;
    set_status_locked("stopping");
    pthread_cond_signal(&g.cv);
  }
  pthread_mutex_unlock(&g.mu);
  return 0;
}

int hmi_capture_status(char *buf, size_t buflen) {
  capture_init_once();
  if (!buf || buflen == 0) {
    return -1;
  }
  pthread_mutex_lock(&g.mu);
  snprintf(buf, buflen, "%s", g.status);
  pthread_mutex_unlock(&g.mu);
  return 0;
}

int hmi_capture_cleanup(const char *path) {
  char cmd[kPathMax + 32];
  if (!path || !path[0]) {
    return -1;
  }
  /* Only allow cleanup under /var/lib/hmi/capture or /tmp */
  if (strncmp(path, "/var/lib/hmi/capture/", 21) != 0 &&
      strncmp(path, "/tmp/", 5) != 0) {
    return -1;
  }
  snprintf(cmd, sizeof(cmd), "rm -rf '%s'", path);
  return system(cmd) == 0 ? 0 : -1;
}

void hmi_capture_on_present(hmi_capture_gl_get_proc_fn get_proc,
                            int width,
                            int height) {
  FrameSlot *slot = NULL;
  int i;
  size_t nbytes;
  Mode mode;

  capture_init_once();
  if (!get_proc || width <= 0 || height <= 0) {
    return;
  }

  pthread_mutex_lock(&g.mu);
  mode = g.mode;
  if (mode != kModeStillArmed && mode != kModeRecording) {
    pthread_mutex_unlock(&g.mu);
    return;
  }

  if (!g.gl_ready) {
    g.glReadPixels = (void (*)(int, int, int, int, unsigned int, unsigned int,
                               void *))get_proc("glReadPixels");
    g.glPixelStorei =
        (void (*)(unsigned int, int))get_proc("glPixelStorei");
    g.gl_ready = (g.glReadPixels != NULL);
  }
  if (!g.gl_ready) {
    set_error_locked("glReadPixels_missing");
    g.mode = kModeIdle;
    pthread_mutex_unlock(&g.mu);
    return;
  }

  for (i = 0; i < kRingSlots; i++) {
    if (!g.ring[i].ready) {
      slot = &g.ring[i];
      break;
    }
  }
  if (!slot) {
    g.drop_count++;
    pthread_mutex_unlock(&g.mu);
    return;
  }
  if (alloc_slot(slot, width, height) != 0) {
    g.drop_count++;
    pthread_mutex_unlock(&g.mu);
    return;
  }
  nbytes = (size_t)width * (size_t)height * 4u;

  /* Unlock during GL read so encode can run; slot not marked ready yet. */
  pthread_mutex_unlock(&g.mu);

  if (g.glPixelStorei) {
    g.glPixelStorei(0x0D05 /* GL_PACK_ALIGNMENT */, 1);
  }
  /* GL_RGBA=0x1908, GL_UNSIGNED_BYTE=0x1401 */
  g.glReadPixels(0, 0, width, height, 0x1908, 0x1401, slot->rgba);

  pthread_mutex_lock(&g.mu);
  if (g.mode != kModeStillArmed && g.mode != kModeRecording) {
    /* cancelled while reading */
    pthread_mutex_unlock(&g.mu);
    return;
  }
  slot->pts_ns = mono_ns();
  slot->ready = 1;
  if (g.mode == kModeStillArmed) {
    g.pending_still = 1;
    g.mode = kModeIdle; /* do not capture further presents */
    set_status_locked("encoding");
  }
  pthread_cond_signal(&g.cv);
  pthread_mutex_unlock(&g.mu);
  (void)nbytes;
}
