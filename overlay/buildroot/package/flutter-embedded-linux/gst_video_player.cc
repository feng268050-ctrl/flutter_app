// Copyright 2021 Sony Group Corporation. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "gst_video_player.h"

#include <gst/audio/audio.h>
#include <gst/video/gstvideometa.h>
#include <gst/video/video.h>

#include <iostream>

GstVideoPlayer::GstVideoPlayer(
    const std::string& uri, std::unique_ptr<VideoPlayerStreamHandler> handler)
    : stream_handler_(std::move(handler)), width_(0), height_(0) {
  gst_.pipeline = nullptr;
  gst_.playbin = nullptr;
  gst_.video_convert = nullptr;
  gst_.video_sink = nullptr;
  gst_.output = nullptr;
  gst_.bus = nullptr;
  gst_.buffer = nullptr;

  uri_ = ParseUri(uri);
  if (!CreatePipeline()) {
    std::cerr << "Failed to create a pipeline" << std::endl;
    DestroyPipeline();
    return;
  }

  // Prerolls before getting information from the pipeline.
  Preroll();

  // Live RTSP often has no negotiated caps until PLAYING (NO_PREROLL).
  // Do NOT poll with g_usleep here — Create() runs on Flutter's platform
  // thread and a multi-second wait freezes the whole UI (spinner included).
  // Also do NOT go PLAYING here: Flutter's initialized handler calls pause()
  // immediately; PLAYING→PAUSED during RTSP connect stalls live pipelines
  // (black preview). Stay PAUSED until Play().
  GetVideoSize(width_, height_);
  if (width_ <= 0 || height_ <= 0) {
    // AcceptBuffer resizes on first frame. Use 16:9 so Dart aspect is sane.
    width_ = 960;
    height_ = 540;
    std::cerr << "Video size unknown after preroll; using 960x540 placeholder"
              << std::endl;
  }
  pixels_.reset(new uint32_t[static_cast<size_t>(width_) * height_]);

  stream_handler_->OnNotifyInitialized();
}

GstVideoPlayer::~GstVideoPlayer() {
  Stop();
  DestroyPipeline();
}

// static
void GstVideoPlayer::GstLibraryLoad() { gst_init(NULL, NULL); }

// static
void GstVideoPlayer::GstLibraryUnload() { gst_deinit(); }

bool GstVideoPlayer::Play() {
  if (!gst_.pipeline) {
    return false;
  }
  // VOD fakesink sync=TRUE needs a pipeline clock; without one, handoff never
  // fires and playback appears frozen. Always (re)bind the system clock.
  if (!IsLiveUri()) {
    GstClock* clock = gst_system_clock_obtain();
    if (clock) {
      gst_pipeline_use_clock(GST_PIPELINE(gst_.pipeline), clock);
      gst_object_unref(clock);
      std::cerr << "VOD pipeline uses system clock for sync" << std::endl;
    }
    if (gst_.video_sink) {
      g_object_set(G_OBJECT(gst_.video_sink), "sync", TRUE, NULL);
    }
  }
  if (gst_element_set_state(gst_.pipeline, GST_STATE_PLAYING) ==
      GST_STATE_CHANGE_FAILURE) {
    std::cerr << "Failed to change the state to PLAYING" << std::endl;
    return false;
  }
  return true;
}

bool GstVideoPlayer::Pause() {
  if (gst_element_set_state(gst_.pipeline, GST_STATE_PAUSED) ==
      GST_STATE_CHANGE_FAILURE) {
    std::cerr << "Failed to change the state to PAUSED" << std::endl;
    return false;
  }
  return true;
}

bool GstVideoPlayer::Stop() {
  if (gst_element_set_state(gst_.pipeline, GST_STATE_READY) ==
      GST_STATE_CHANGE_FAILURE) {
    std::cerr << "Failed to change the state to READY" << std::endl;
    return false;
  }
  return true;
}

bool GstVideoPlayer::SetVolume(double volume) {
  if (!gst_.playbin) {
    return false;
  }

  volume_ = volume;
  g_object_set(gst_.playbin, "volume", volume, NULL);
  return true;
}

bool GstVideoPlayer::SetPlaybackRate(double rate) {
  if (!gst_.playbin) {
    return false;
  }

  if (rate <= 0) {
    std::cerr << "Rate " << rate << " is not supported" << std::endl;
    return false;
  }

  // Flutter VideoPlayerController.play() always re-applies speed 1.0 via
  // _applyPlaybackSpeed(). A no-op FLUSH seek here races the PLAYING transition
  // and makes the first play() intermittently do nothing on local files.
  // Marker string retained for scripts/check-prebuilt.sh.
  if (rate == playback_rate_) {
    std::cerr << "SetPlaybackRate: skip no-op rate seek" << std::endl;
    return true;
  }

  // Flutter VideoPlayerController always applies playback speed after play().
  // Live RTSP has no position/duration; a FLUSH seek here stalls the pipeline
  // permanently (no buffers to fakesink → black Texture).
  gint64 duration = 0;
  gint64 position = 0;
  const bool seekable =
      gst_element_query_duration(gst_.pipeline, GST_FORMAT_TIME, &duration) &&
      duration > 0 &&
      gst_element_query_position(gst_.pipeline, GST_FORMAT_TIME, &position);
  if (!seekable) {
    // Marker string retained for scripts/check-prebuilt.sh.
    std::cerr << "SetPlaybackRate: skip flush-seek for live/unseekable"
              << std::endl;
    playback_rate_ = rate;
    mute_ = (rate < 0.5 || rate > 2);
    g_object_set(gst_.playbin, "mute", mute_, NULL);
    return true;
  }

  if (!gst_element_seek(gst_.pipeline, rate, GST_FORMAT_TIME,
                        GST_SEEK_FLAG_FLUSH, GST_SEEK_TYPE_SET, position,
                        GST_SEEK_TYPE_SET, GST_CLOCK_TIME_NONE)) {
    std::cerr << "Failed to set playback rate to " << rate
              << " (gst_element_seek failed)" << std::endl;
    return false;
  }

  playback_rate_ = rate;
  mute_ = (rate < 0.5 || rate > 2);
  g_object_set(gst_.playbin, "mute", mute_, NULL);

  return true;
}

bool GstVideoPlayer::SetSeek(int64_t position) {
  gint64 duration = 0;
  if (!(gst_element_query_duration(gst_.pipeline, GST_FORMAT_TIME, &duration) &&
        duration > 0)) {
    return true;
  }
  auto nanosecond = position * 1000 * 1000;
  if (!gst_element_seek(
          gst_.pipeline, playback_rate_, GST_FORMAT_TIME,
          (GstSeekFlags)(GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_KEY_UNIT),
          GST_SEEK_TYPE_SET, nanosecond, GST_SEEK_TYPE_SET,
          GST_CLOCK_TIME_NONE)) {
    std::cerr << "Failed to seek " << nanosecond << std::endl;
    return false;
  }
  return true;
}

int64_t GstVideoPlayer::GetDuration() {
  GstFormat fmt = GST_FORMAT_TIME;
  int64_t duration_msec;
  if (!gst_element_query_duration(gst_.pipeline, fmt, &duration_msec)) {
    std::cerr << "Failed to get duration" << std::endl;
    return -1;
  }
  duration_msec /= GST_MSECOND;
  return duration_msec;
}

int64_t GstVideoPlayer::GetCurrentPosition() {
  gint64 position = 0;
  if (!gst_element_query_position(gst_.pipeline, GST_FORMAT_TIME, &position)) {
    return 0;
  }
  return position / GST_MSECOND;
}

const uint8_t* GstVideoPlayer::GetFrameBuffer() {
  std::shared_lock<std::shared_mutex> lock(mutex_buffer_);
  if (!gst_.buffer) {
    return nullptr;
  }

  const uint32_t pixel_bytes = width_ * height_ * 4;
  gst_buffer_extract(gst_.buffer, 0, pixels_.get(), pixel_bytes);
  return reinterpret_cast<const uint8_t*>(pixels_.get());
}

// Prefer Rockchip MPP hardware RGBA (or scaled NV12) instead of software
// videoconvert — CPU NV12→RGBA on RK3566 is ~1fps; MPP RGBA is ~10fps+.
// static
void GstVideoPlayer::MppElementSetup(GstElement* playbin, GstElement* element,
                                     gpointer user_data) {
  (void)playbin;
  (void)user_data;
  GstElementFactory* factory = gst_element_get_factory(element);
  if (!factory) {
    return;
  }
  const gchar* name =
      gst_plugin_feature_get_name(GST_PLUGIN_FEATURE(factory));
  if (!name || !g_str_has_prefix(name, "mppvideodec")) {
    return;
  }
  // RGA-backed convert+scale (needs gstreamer1-rockchip built with -Drga=enabled).
  g_object_set(element, "arm-afbc", FALSE, "dma-feature", FALSE, NULL);
  if (!g_object_class_find_property(G_OBJECT_GET_CLASS(element), "format")) {
    std::cerr << "MppElementSetup: mppvideodec has no format property "
                 "(rockchipmpp built without RGA) — expect slow software convert"
              << std::endl;
    return;
  }
  const GstVideoFormat rgba = gst_video_format_from_string("RGBA");
  g_object_set(element, "format", static_cast<gint>(rgba), "width", 960,
               "height", 540, NULL);
  std::cerr << "MppElementSetup: mppvideodec format=RGBA 960x540" << std::endl;
}

// Creats a video pipeline using playbin.
// $ playbin uri=<file> video-sink="videoconvert ! video/x-raw,format=RGBA !
// fakesink"
bool GstVideoPlayer::CreatePipeline() {
  gst_.pipeline = gst_pipeline_new("pipeline");
  if (!gst_.pipeline) {
    std::cerr << "Failed to create a pipeline" << std::endl;
    return false;
  }
  gst_.playbin = gst_element_factory_make("playbin", "playbin");
  if (!gst_.playbin) {
    std::cerr << "Failed to create a source" << std::endl;
    return false;
  }
  g_signal_connect(gst_.playbin, "element-setup", G_CALLBACK(MppElementSetup),
                   this);
  // Avoid playsink inserting missing 'deinterlace' (not in our plugin set).
  {
    guint flags = 0;
    g_object_get(gst_.playbin, "flags", &flags, NULL);
    flags &= ~static_cast<guint>(1u << 9);  // GST_PLAY_FLAG_DEINTERLACE
    g_object_set(gst_.playbin, "flags", flags, NULL);
  }
  gst_.video_convert = gst_element_factory_make("videoconvert", "videoconvert");
  if (!gst_.video_convert) {
    std::cerr << "Failed to create a videoconvert" << std::endl;
    return false;
  }
  gst_.video_sink = gst_element_factory_make("fakesink", "videosink");
  if (!gst_.video_sink) {
    std::cerr << "Failed to create a videosink" << std::endl;
    return false;
  }
  gst_.output = gst_bin_new("output");
  if (!gst_.output) {
    std::cerr << "Failed to create an output" << std::endl;
    return false;
  }
  gst_.bus = gst_pipeline_get_bus(GST_PIPELINE(gst_.pipeline));
  if (!gst_.bus) {
    std::cerr << "Failed to create a bus" << std::endl;
    return false;
  }
  gst_bus_set_sync_handler(gst_.bus, (GstBusSyncHandler)HandleGstMessage, this,
                           NULL);

  // Live RTSP: sync=FALSE (clock sync stalls Flutter texture handoff).
  // VOD: sync=TRUE so frames are paced at 1×; textures come from HandoffHandler
  // after basesink sync. Do NOT set async=FALSE on VOD — that stalled handoff.
  // Marker strings retained for scripts/check-prebuilt.sh.
  if (IsLiveUri()) {
    g_object_set(G_OBJECT(gst_.video_sink), "sync", FALSE, "async", FALSE,
                 "qos", FALSE, NULL);
    std::cerr << "live RTSP sink sync=FALSE" << std::endl;
  } else {
    g_object_set(G_OBJECT(gst_.video_sink), "sync", TRUE, "qos", FALSE, NULL);
    std::cerr << "VOD file sink uses clock sync" << std::endl;
    GstClock* clock = gst_system_clock_obtain();
    gst_pipeline_use_clock(GST_PIPELINE(gst_.pipeline), clock);
    gst_object_unref(clock);
  }
  g_object_set(G_OBJECT(gst_.video_sink), "signal-handoffs", TRUE, NULL);
  g_signal_connect(G_OBJECT(gst_.video_sink), "handoff",
                   G_CALLBACK(HandoffHandler), this);
  gst_bin_add_many(GST_BIN(gst_.output), gst_.video_convert, gst_.video_sink,
                   NULL);

  // Adds caps to the converter to convert the color format to RGBA.
  auto* caps = gst_caps_from_string("video/x-raw,format=RGBA");
  auto link_ok =
      gst_element_link_filtered(gst_.video_convert, gst_.video_sink, caps);
  gst_caps_unref(caps);
  if (!link_ok) {
    std::cerr << "Failed to link elements" << std::endl;
    return false;
  }

  // Pad probe fires when a buffer is pushed to fakesink — before basesink
  // clock sync. Captures frames even if handoff is stalled by sync=TRUE.
  {
    auto* fsink_pad = gst_element_get_static_pad(gst_.video_sink, "sink");
    if (fsink_pad) {
      gst_pad_add_probe(fsink_pad, GST_PAD_PROBE_TYPE_BUFFER,
                        BufferProbe, this, NULL);
      gst_object_unref(fsink_pad);
    }
  }

  auto* sinkpad = gst_element_get_static_pad(gst_.video_convert, "sink");
  auto* ghost_sinkpad = gst_ghost_pad_new("sink", sinkpad);
  gst_pad_set_active(ghost_sinkpad, TRUE);
  gst_element_add_pad(gst_.output, ghost_sinkpad);
  gst_object_unref(sinkpad);

  // Drop audio so autoaudiosink cannot stall live playbin.
  {
    GstElement* audio_sink = gst_element_factory_make("fakesink", "audiosink");
    if (audio_sink) {
      g_object_set(G_OBJECT(audio_sink), "sync", FALSE, "async", FALSE, NULL);
      g_object_set(gst_.playbin, "audio-sink", audio_sink, NULL);
    }
  }

  // Sets properties to playbin.
  g_object_set(gst_.playbin, "uri", uri_.c_str(), NULL);
  g_object_set(gst_.playbin, "video-sink", gst_.output, NULL);
  gst_bin_add_many(GST_BIN(gst_.pipeline), gst_.playbin, NULL);

  return true;
}

void GstVideoPlayer::Preroll() {
  if (!gst_.playbin) {
    return;
  }

  auto result = gst_element_set_state(gst_.pipeline, GST_STATE_PAUSED);
  if (result == GST_STATE_CHANGE_FAILURE) {
    std::cerr << "Failed to change the state to PAUSED" << std::endl;
    return;
  }

  // Bound wait: live sources may never complete an infinite preroll.
  if (result == GST_STATE_CHANGE_ASYNC) {
    GstState state;
    result =
        gst_element_get_state(gst_.pipeline, &state, NULL, 10 * GST_SECOND);
    if (result == GST_STATE_CHANGE_FAILURE) {
      std::cerr << "Failed to get the current state" << std::endl;
    }
  }
}

void GstVideoPlayer::DestroyPipeline() {
  if (gst_.video_sink) {
    g_object_set(G_OBJECT(gst_.video_sink), "signal-handoffs", FALSE, NULL);
  }

  if (gst_.pipeline) {
    gst_element_set_state(gst_.pipeline, GST_STATE_NULL);
  }

  if (gst_.buffer) {
    gst_buffer_unref(gst_.buffer);
    gst_.buffer = nullptr;
  }

  if (gst_.bus) {
    gst_object_unref(gst_.bus);
    gst_.bus = nullptr;
  }

  if (gst_.pipeline) {
    gst_object_unref(gst_.pipeline);
    gst_.pipeline = nullptr;
  }

  if (gst_.playbin) {
    gst_.playbin = nullptr;
  }

  if (gst_.output) {
    gst_.output = nullptr;
  }

  if (gst_.video_sink) {
    gst_.video_sink = nullptr;
  }

  if (gst_.video_convert) {
    gst_.video_convert = nullptr;
  }
}

bool GstVideoPlayer::IsLiveUri() const {
  // RTSP (and variants) are live; file:// and plain paths are VOD.
  return g_str_has_prefix(uri_.c_str(), "rtsp://") ||
         g_str_has_prefix(uri_.c_str(), "rtspt://") ||
         g_str_has_prefix(uri_.c_str(), "rtsps://") ||
         g_str_has_prefix(uri_.c_str(), "rtspu://") ||
         g_str_has_prefix(uri_.c_str(), "rtsph://");
}

std::string GstVideoPlayer::ParseUri(const std::string& uri) {
  if (gst_uri_is_valid(uri.c_str())) {
    return uri;
  }

  const auto* filename_uri = gst_filename_to_uri(uri.c_str(), NULL);
  if (!filename_uri) {
    std::cerr << "Faild to open " << uri.c_str() << std::endl;
    return uri;
  }
  std::string result_uri(filename_uri);
  delete filename_uri;

  return result_uri;
}

void GstVideoPlayer::GetVideoSize(int32_t& width, int32_t& height) {
  if (!gst_.pipeline || !gst_.video_sink) {
    std::cerr
        << "Failed to get video size. The pileline hasn't initialized yet.";
    return;
  }

  auto* sink_pad = gst_element_get_static_pad(gst_.video_sink, "sink");
  if (!sink_pad) {
    std::cerr << "Failed to get a pad";
    return;
  }

  auto* caps = gst_pad_get_current_caps(sink_pad);
  if (!caps) {
    gst_object_unref(sink_pad);
    return;
  }
  auto* structure = gst_caps_get_structure(caps, 0);
  if (!structure) {
    std::cerr << "Failed to get a structure";
    gst_caps_unref(caps);
    gst_object_unref(sink_pad);
    return;
  }

  gst_structure_get_int(structure, "width", &width);
  gst_structure_get_int(structure, "height", &height);
  gst_caps_unref(caps);
  gst_object_unref(sink_pad);
}

// static
void GstVideoPlayer::AcceptBuffer(GstBuffer* buf, GstPad* pad, gpointer user_data,
                                  const char* via) {
  auto* self = reinterpret_cast<GstVideoPlayer*>(user_data);
  auto* caps = gst_pad_get_current_caps(pad);
  if (!caps) {
    return;
  }
  auto* structure = gst_caps_get_structure(caps, 0);
  if (!structure) {
    gst_caps_unref(caps);
    return;
  }

  int width;
  int height;
  gst_structure_get_int(structure, "width", &width);
  gst_structure_get_int(structure, "height", &height);
  gst_caps_unref(caps);
  if (width != self->width_ || height != self->height_) {
    self->width_ = width;
    self->height_ = height;
    self->pixels_.reset(new uint32_t[static_cast<size_t>(width) * height]);
  }

  {
    std::lock_guard<std::shared_mutex> lock(self->mutex_buffer_);
    // Probe + handoff can both see the same buffer; accept once.
    if (self->gst_.buffer == buf) {
      return;
    }
    if (self->gst_.buffer) {
      gst_buffer_unref(self->gst_.buffer);
      self->gst_.buffer = nullptr;
    }
    self->gst_.buffer = gst_buffer_ref(buf);
  }
  (void)via;
  // Notify outside the buffer lock — texture populate may run concurrently.
  self->stream_handler_->OnNotifyFrameDecoded();
}

// static
GstPadProbeReturn GstVideoPlayer::BufferProbe(GstPad* pad, GstPadProbeInfo* info,
                                              gpointer user_data) {
  if (!(GST_PAD_PROBE_INFO_TYPE(info) & GST_PAD_PROBE_TYPE_BUFFER)) {
    return GST_PAD_PROBE_OK;
  }
  GstBuffer* buf = GST_PAD_PROBE_INFO_BUFFER(info);
  if (!buf) {
    return GST_PAD_PROBE_OK;
  }
  auto* self = reinterpret_cast<GstVideoPlayer*>(user_data);
  // VOD: probe runs BEFORE basesink clock sync. Pushing textures here races
  // decode (fast-forward). 1× frames come from HandoffHandler after sync.
  if (!self->IsLiveUri()) {
    static bool logged_vod_probe = false;
    if (!logged_vod_probe) {
      std::cerr << "VOD BufferProbe defers to synced handoff" << std::endl;
      logged_vod_probe = true;
    }
    return GST_PAD_PROBE_OK;
  }
  // Live: re-assert sync=FALSE (playsink may flip sync=TRUE and stall).
  if (self->gst_.video_sink) {
    gboolean sync = TRUE;
    g_object_get(G_OBJECT(self->gst_.video_sink), "sync", &sync, NULL);
    if (sync) {
      g_object_set(G_OBJECT(self->gst_.video_sink), "sync", FALSE, NULL);
    }
  }
  AcceptBuffer(buf, pad, user_data, "BufferProbe");
  return GST_PAD_PROBE_OK;
}

// static
void GstVideoPlayer::HandoffHandler(GstElement* fakesink, GstBuffer* buf,
                                    GstPad* new_pad, gpointer user_data) {
  (void)fakesink;
  auto* self = reinterpret_cast<GstVideoPlayer*>(user_data);
  // VOD preroll/pause: do not publish frames (keeps position/UI at start).
  // Treat pending PLAYING as playing so the first synced frames are not dropped.
  if (!self->IsLiveUri()) {
    GstState state = GST_STATE_NULL;
    GstState pending = GST_STATE_VOID_PENDING;
    if (self->gst_.pipeline) {
      gst_element_get_state(self->gst_.pipeline, &state, &pending, 0);
    }
    if (state != GST_STATE_PLAYING && pending != GST_STATE_PLAYING) {
      static bool logged_pause = false;
      if (!logged_pause) {
        std::cerr << "VOD handoff skip when paused" << std::endl;
        logged_pause = true;
      }
      return;
    }
  }
  AcceptBuffer(buf, new_pad, user_data, "HandoffHandler");
}

// static
gboolean GstVideoPlayer::HandleGstMessage(GstBus* bus, GstMessage* message,
                                          gpointer user_data) {
  switch (GST_MESSAGE_TYPE(message)) {
    case GST_MESSAGE_EOS: {
      auto* self = reinterpret_cast<GstVideoPlayer*>(user_data);
      self->stream_handler_->OnNotifyCompleted();
      if (self->auto_repeat_) {
        self->SetSeek(0);
      }
      break;
    }
    case GST_MESSAGE_WARNING: {
      gchar* debug;
      GError* error;
      gst_message_parse_warning(message, &error, &debug);
      g_printerr("WARNING from element %s: %s\n", GST_OBJECT_NAME(message->src),
                 error->message);
      g_printerr("Warning details: %s\n", debug);
      g_free(debug);
      g_error_free(error);
      break;
    }
    case GST_MESSAGE_ERROR: {
      gchar* debug;
      GError* error;
      gst_message_parse_error(message, &error, &debug);
      g_printerr("ERROR from element %s: %s\n", GST_OBJECT_NAME(message->src),
                 error->message);
      g_printerr("Error details: %s\n", debug);
      g_free(debug);
      g_error_free(error);
      break;
    }
    default:
      break;
  }
  return TRUE;
}
